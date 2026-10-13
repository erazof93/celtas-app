import 'dart:async';

import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/presentation/home_screen.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'widgets/force_update_screen_test.dart' show FakeUrlLauncherPlatform;

class _AuthRepository extends Mock implements AuthRepository {}

void main() {
  const requiredUpdate = AppVersionCheck(
    isUpdateRequired: true,
    minVersion: '1.2.0+30',
  );
  final compatible = evaluateAppVersion(
    currentVersion: '1.2.0+30',
    minVersion: '1.2.0+30',
  );
  late ProviderContainer container;
  late GoRouter router;
  late int homeBuilds;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(envString: 'API_BASE_URL=https://example.invalid');
  });

  setUp(() => homeBuilds = 0);

  tearDown(() {
    container.dispose();
    router.dispose();
  });

  Future<void> mount(
    WidgetTester tester,
    Future<AppVersionCheck> Function() check,
  ) async {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('SPLASH')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) {
            homeBuilds++;
            return const Scaffold(body: Text('HOME FUNCIONAL'));
          },
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (_, _) => const Scaffold(body: Text('PEDIDO')),
        ),
        GoRoute(
          path: '/coupons',
          builder: (_, _) => const Scaffold(body: Text('CUPONES')),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        routerProvider.overrideWithValue(router),
        appVersionCheckProvider.overrideWith((ref) => check()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CeltasApp()),
    );
    await tester.pump();
  }

  testWidgets(
    'Loading no monta Splash ni Home; compatible permite navegación',
    (tester) async {
      final pending = Completer<AppVersionCheck>();
      var checks = 0;
      await mount(tester, () {
        checks++;
        return pending.future;
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      container.read(appVersionGateProvider.notifier).recheck();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CeltasApp(key: UniqueKey()),
        ),
      );
      await tester.pump();
      expect(checks, 1);
      expect(container.read(routerProvider), same(router));
      expect(find.text('Verificando tu versión…'), findsOneWidget);
      expect(find.text('SPLASH'), findsNothing);
      router.go('/home');
      await tester.pump();
      expect(homeBuilds, 0);
      pending.complete(compatible);
      await tester.pumpAndSettle();
      expect(find.text('HOME FUNCIONAL'), findsOneWidget);
      expect(
        container.read(appVersionGateProvider).status,
        AppVersionGateStatus.allowed,
      );
      expect(container.read(routerProvider), same(router));
      expect(checks, 1);
    },
  );

  testWidgets('error inicial permite continuar sin excepción de UI', (
    tester,
  ) async {
    await mount(tester, () async => throw Exception('sin conexión'));
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('HOME FUNCIONAL'), findsOneWidget);
    expect(
      container.read(appVersionGateProvider).status,
      AppVersionGateStatus.error,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bloqueo persiste con go, push, Atrás y reconstrucciones', (
    tester,
  ) async {
    await mount(tester, () async => requiredUpdate);
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();
    // Mismas operaciones que usan las notificaciones de pedidos/cupones.
    unawaited(router.push<void>('/orders/123'));
    await tester.pumpAndSettle();
    router.go('/coupons');
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CeltasApp()),
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(ForceUpdateScreen), findsOneWidget);
    expect(homeBuilds, 0);
    expect(find.text('PEDIDO'), findsNothing);
    expect(find.text('CUPONES'), findsNothing);
    expect(container.read(routerProvider), same(router));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'regreso de Play Store reevalúa, conserva bloqueo ante error y permite versión compatible',
    (tester) async {
      final previousLauncher = UrlLauncherPlatform.instance;
      final launcher = FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);
      var calls = 0;
      var response = Future<AppVersionCheck>.value(requiredUpdate);
      await mount(tester, () {
        calls++;
        return response;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Play Store'));
      await tester.pumpAndSettle();
      expect(launcher.lastLaunchedUrl, contains('com.celtas.celtas_mobile'));

      final pending = Completer<AppVersionCheck>();
      response = pending.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
      pending.completeError(Exception('timeout'));
      await tester.pumpAndSettle();
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
      expect(homeBuilds, 0);

      response = Future.value(compatible);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.byType(ForceUpdateScreen), findsNothing);
      expect(find.text('SPLASH'), findsOneWidget);
      expect(container.read(routerProvider), same(router));
    },
  );

  testWidgets(
    'bloqueo confirmado después de Splash impide Home y permite continuar al verificar compatibilidad',
    (tester) async {
      var response = Future<AppVersionCheck>.value(compatible);
      await mount(tester, () => response);
      await tester.pumpAndSettle();
      expect(find.text('SPLASH'), findsOneWidget);

      final pending = Completer<AppVersionCheck>();
      response = pending.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('SPLASH'), findsOneWidget);
      pending.complete(requiredUpdate);
      await tester.pumpAndSettle();
      router.go('/home');
      await tester.pumpAndSettle();
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
      expect(homeBuilds, 0);

      response = Future.value(compatible);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('HOME FUNCIONAL'), findsOneWidget);
      expect(homeBuilds, 1);
      expect(container.read(routerProvider), same(router));
    },
  );

  for (final versionFirst in [true, false]) {
    testWidgets(
      'router y bootstrap reales: ${versionFirst ? "versión antes de sesión" : "sesión antes de versión"}, Home no inicia',
      (tester) async {
        final repository = _AuthRepository();
        final session = Completer<AuthTokens>();
        final version = Completer<AppVersionCheck>();
        final user = User(
          id: 'user-test',
          email: 'test@example.invalid',
          fullName: 'Cliente',
          provider: UserProvider.local,
          totalSpent: 0,
          role: UserRole.cliente,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        when(
          repository.readRefreshToken,
        ).thenAnswer((_) async => 'refresh-test');
        when(
          () => repository.refresh(
            'refresh-test',
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) => session.future);
        when(
          () => repository.saveRefreshToken(
            'refresh-new',
            isCurrent: any(named: 'isCurrent'),
          ),
        ).thenAnswer((_) async {});
        var homeRequests = 0;
        container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            appVersionCheckProvider.overrideWith((ref) => version.future),
            activeBannersProvider.overrideWith((ref) async {
              homeRequests++;
              return [];
            }),
            publicMenuProvider.overrideWith((ref) async {
              homeRequests++;
              return [];
            }),
          ],
        );
        router = container.read(routerProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const CeltasApp(),
          ),
        );
        await tester.pump();
        if (versionFirst) {
          version.complete(requiredUpdate);
          await tester.pumpAndSettle();
          expect(
            container.read(authControllerProvider).status,
            AuthStatus.unknown,
          );
          expect(find.byType(ForceUpdateScreen), findsOneWidget);
        }
        session.complete(
          AuthTokens(
            accessToken: 'access-test',
            refreshToken: 'refresh-new',
            user: user,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.authenticated,
        );
        if (!versionFirst) version.complete(requiredUpdate);
        await tester.pumpAndSettle();
        // El Router no está montado: el guard queda pendiente hasta Allowed.
        router.go('/');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
        router.go('/home');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/home');
        unawaited(router.push<void>('/orders/123'));
        await tester.pumpAndSettle();
        router.go('/coupons');
        await tester.pumpAndSettle();
        expect(find.byType(ForceUpdateScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
        expect(homeRequests, 0);
        expect(container.read(authControllerProvider).user, user);
        expect(
          container.read(authControllerProvider).accessToken,
          'access-test',
        );
        expect(container.read(routerProvider), same(router));
        verifyNever(repository.clearRefreshToken);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
