import 'dart:io';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/application/version_gate_diagnostics.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_screen.dart';
import 'package:celtas_mobile/qa/version_gate_qa.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../features/settings/presentation/widgets/force_update_screen_test.dart'
    show FakeUrlLauncherPlatform;

void main() {
  const enabled = bool.fromEnvironment('CELTAS_QA');
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(envString: 'API_BASE_URL=https://qa.invalid');
  });

  test(
    'activation rejects production package and requires an explicit flag',
    () {
      expect(
        () => requireQaConfiguration(packageName: 'com.celtas.celtas_mobile'),
        throwsStateError,
      );
      if (!enabled) {
        expect(
          () => requireQaConfiguration(packageName: qaApplicationId),
          throwsStateError,
        );
      } else {
        requireQaConfiguration(packageName: qaApplicationId);
      }
    },
  );
  if (!enabled) return;

  late VersionGateQa runtime;
  late List<VersionGateEvent> events;
  void create(QaScenario scenario) {
    events = [];
    runtime = VersionGateQa(
      packageName: qaApplicationId,
      version: '1.0.1+21',
      scenario: scenario,
      onEvent: events.add,
    );
    addTearDown(runtime.dispose);
  }

  Future<void> settle() async {
    runtime.verify();
    try {
      await runtime.container.read(appVersionCheckProvider.future);
    } catch (_) {}
  }

  for (final scenario in QaScenario.values) {
    test('real controller/comparator: ${scenario.name}', () async {
      create(scenario);
      expect(
        runtime.container.read(appVersionGateProvider).status,
        AppVersionGateStatus.loading,
      );
      await settle();
      final expected = switch (scenario) {
        QaScenario.compatible => AppVersionGateStatus.allowed,
        QaScenario.initialError => AppVersionGateStatus.error,
        _ => AppVersionGateStatus.updateRequired,
      };
      expect(runtime.container.read(appVersionGateProvider).status, expected);
      expect(runtime.checks, 1);
      if (scenario == QaScenario.blockedError) {
        await settle();
        expect(events, contains(VersionGateEvent.validationError));
        expect(
          runtime.container.read(appVersionGateProvider).status,
          AppVersionGateStatus.updateRequired,
        );
      }
    });
  }

  test('a confirmed compatible version releases a previous block', () async {
    create(QaScenario.required);
    await settle();
    runtime.scenario = QaScenario.compatible;
    await settle();
    expect(
      runtime.container.read(appVersionGateProvider).status,
      AppVersionGateStatus.allowed,
    );
  });

  test('auth and session storage fail before bootstrap or plugin access', () {
    create(QaScenario.required);
    expect(
      () => runtime.container.read(secureStorageProvider),
      throwsA(anything),
    );
    expect(
      () => runtime.container.read(authRepositoryProvider),
      throwsA(anything),
    );
    expect(
      () => runtime.container.read(authControllerProvider),
      throwsA(anything),
    );
    expect(ApiClient.instance.session, isNull);
  });

  test(
    'Dio and dart:io deny requests without including request data in events',
    () async {
      final recorded = <VersionGateEvent>[];
      final block = QaNetworkBlock(recorded.add);
      final dio = Dio()..httpClientAdapter = block;
      for (final path in ['/auth/refresh', '/orders', '/notifications/token']) {
        await expectLater(
          dio.post(
            'https://example.invalid$path',
            data: {'private': 'never-log'},
          ),
          throwsA(isA<DioException>()),
        );
      }
      expect(
        () => block.createHttpClient(null),
        throwsA(isA<SocketException>()),
      );
      expect(recorded, List.filled(4, VersionGateEvent.networkDenied));
    },
  );

  test(
    'installed QA network isolation clears session hooks and blocks singleton',
    () async {
      final originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      final originalUrl = ApiClient.instance.dio.options.baseUrl;
      addTearDown(() {
        HttpOverrides.global = null;
        ApiClient.instance.dio.httpClientAdapter = originalAdapter;
        ApiClient.instance.dio.options.baseUrl = originalUrl;
      });
      // A previously populated environment must not survive QA activation.
      dotenv.loadFromString(
        envString:
            'API_BASE_URL=https://example.invalid\n'
            'GEOAPIFY_API_KEY=synthetic-test-key\n'
            'GOOGLE_SERVER_CLIENT_ID=synthetic-test-client',
      );
      isolateQaNetwork(qaApplicationId, (_) {});
      expect(dotenv.env.keys, unorderedEquals(['API_BASE_URL']));
      expect(dotenv.env['GEOAPIFY_API_KEY'], isNull);
      expect(dotenv.env['GOOGLE_SERVER_CLIENT_ID'], isNull);
      expect(ApiClient.instance.session, isNull);
      expect(ApiClient.instance.onSessionRefreshed, isNull);
      expect(ApiClient.instance.dio.options.baseUrl, 'https://qa.invalid');
      expect(() => HttpClient(), throwsA(isA<SocketException>()));
      await expectLater(
        ApiClient.instance.dio.post('/auth/refresh'),
        throwsA(isA<DioException>()),
      );
    },
  );

  for (final bootstrapFirst in [true, false]) {
    testWidgets(
      'required gate: bootstrapFirst=$bootstrapFirst, go/push/back/rebuild',
      (tester) async {
        create(QaScenario.required);
        await tester.pumpWidget(VersionGateQaApp(runtime: runtime));
        if (bootstrapFirst) runtime.completeBootstrap();
        await settle();
        await tester.pumpAndSettle();
        if (!bootstrapFirst) runtime.completeBootstrap();
        runtime.goHome();
        runtime.pushProbe();
        await tester.pumpAndSettle();
        expect(find.byType(ForceUpdateScreen), findsOneWidget);
        expect(runtime.homeMounts, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpWidget(
          VersionGateQaApp(key: UniqueKey(), runtime: runtime),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ForceUpdateScreen), findsOneWidget);
        expect(runtime.homeMounts, 0);
        expect(
          events,
          containsAll([
            VersionGateEvent.navigationGo,
            VersionGateEvent.navigationPush,
            VersionGateEvent.backBlocked,
          ]),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final scenario in [QaScenario.compatible, QaScenario.initialError]) {
    testWidgets('${scenario.name} allows simulated Home after bootstrap', (
      tester,
    ) async {
      create(scenario);
      await tester.pumpWidget(VersionGateQaApp(runtime: runtime));
      runtime.completeBootstrap();
      await settle();
      await tester.pumpAndSettle();
      expect(runtime.homeMounts, 1);
      expect(find.text('Home QA · sin datos ni sesión real'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'store return/resumed keeps confirmed block after simulated error',
    (tester) async {
      create(QaScenario.blockedError);
      final originalLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = FakeUrlLauncherPlatform();
      addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);
      await tester.pumpWidget(VersionGateQaApp(runtime: runtime));
      await settle();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Play Store'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        events,
        containsAll([
          VersionGateEvent.storeOpening,
          VersionGateEvent.storeOpened,
          VersionGateEvent.resumed,
          VersionGateEvent.validationError,
        ]),
      );
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
      expect(runtime.homeMounts, 0);
      expect(runtime.checks, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
