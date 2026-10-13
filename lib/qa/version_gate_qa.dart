import 'dart:async';
import 'dart:io';

import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/application/version_gate_diagnostics.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const qaApplicationId = 'com.celtas.celtas_mobile.qa';
const _qaEnabled = bool.fromEnvironment('CELTAS_QA');

enum QaScenario { compatible, required, initialError, blockedError }

/// Fails closed even when the entry point is invoked outside the QA flavor.
void requireQaConfiguration({required String packageName}) {
  if (!kDebugMode || !_qaEnabled || packageName != qaApplicationId) {
    throw StateError('QA requires debug, CELTAS_QA=true and the QA package.');
  }
}

class QaNetworkBlock extends HttpOverrides implements HttpClientAdapter {
  QaNetworkBlock(this.record);
  final void Function(VersionGateEvent) record;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    record(VersionGateEvent.networkDenied);
    throw const SocketException('QA network disabled');
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    record(VersionGateEvent.networkDenied);
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'QA network disabled',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Only main_qa installs global defenses; importing this library has no effects.
void isolateQaNetwork(
  String packageName,
  void Function(VersionGateEvent) record,
) {
  requireQaConfiguration(packageName: packageName);
  dotenv.loadFromString(envString: 'API_BASE_URL=https://qa.invalid');
  GoogleFonts.config.allowRuntimeFetching = false;
  final block = QaNetworkBlock(record);
  HttpOverrides.global = block;
  final api = ApiClient.instance;
  api.session = null;
  api.onSessionRefreshed = null;
  api.dio.options.baseUrl = 'https://qa.invalid';
  api.dio.httpClientAdapter = block;
}

class _QaSettings extends SettingsRepository {
  _QaSettings(this.runtime) : super(Dio());
  final VersionGateQa runtime;

  @override
  Future<Map<String, dynamic>> getPublicSettings({
    CancelToken? cancelToken,
  }) async {
    runtime.record(VersionGateEvent.validationStarted);
    final scenario = runtime.scenario;
    final attempt = ++runtime.checks;
    // Manual completion allows both bootstrap/version ordering cases.
    await runtime.initialVerification.future;
    if (scenario == QaScenario.initialError ||
        (scenario == QaScenario.blockedError && attempt > 1)) {
      throw const ApiException('Error de red simulado QA');
    }
    final build = int.parse(runtime.version.split('+').last);
    return {
      'min_app_version':
          '1.0.1+${scenario == QaScenario.compatible ? build : build + 1}',
    };
  }

  @override
  Future<BusinessHours> getBusinessHours() =>
      Future.error(StateError('QA business services disabled'));
}

/// Uses the production comparator, raw FutureProvider, controller and gate UI.
/// Routes deliberately contain no production Home/auth/notification providers.
class VersionGateQa {
  VersionGateQa({
    required String packageName,
    required this.version,
    required this.scenario,
    this.onEvent,
  }) {
    requireQaConfiguration(packageName: packageName);
    final build = int.tryParse(version.split('+').last);
    if (!version.contains('+') || build == null || build < 0) {
      throw StateError('QA requires a valid installed build number');
    }
    router = GoRouter(
      initialLocation: '/',
      redirect: (_, state) =>
          bootstrapDone && state.uri.path == '/' ? '/home' : null,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('Splash QA · sesión simulada')),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => _QaHome(record: record),
        ),
        GoRoute(
          path: '/probe',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('Ruta QA · sin servicios')),
          ),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        routerProvider.overrideWithValue(router),
        currentAppVersionProvider.overrideWith((ref) async => version),
        settingsRepositoryProvider.overrideWithValue(_QaSettings(this)),
        versionGateDiagnosticsProvider.overrideWithValue(record),
        // Accidental access fails before plugins, storage or auth bootstrap.
        secureStorageProvider.overrideWith(
          (ref) => throw StateError('QA storage disabled'),
        ),
        authRepositoryProvider.overrideWith(
          (ref) => throw StateError('QA auth disabled'),
        ),
        authControllerProvider.overrideWith(
          () => throw StateError('QA session disabled'),
        ),
      ],
    );
    container.listen(appVersionCheckProvider, (_, next) {
      if (next.isLoading) return;
      record(
        next.hasError
            ? VersionGateEvent.validationError
            : next.requireValue.isUpdateRequired
            ? VersionGateEvent.validationRequired
            : VersionGateEvent.validationAllowed,
      );
    });
    container.listen(appVersionGateProvider, (_, next) {
      record(switch (next.status) {
        AppVersionGateStatus.loading => VersionGateEvent.gateLoading,
        AppVersionGateStatus.allowed => VersionGateEvent.gateAllowed,
        AppVersionGateStatus.updateRequired => VersionGateEvent.gateRequired,
        AppVersionGateStatus.error => VersionGateEvent.gateError,
      });
    }, fireImmediately: true);
  }

  final String version;
  QaScenario scenario;
  final void Function(VersionGateEvent)? onEvent;
  final initialVerification = Completer<void>();
  late final GoRouter router;
  late final ProviderContainer container;
  int checks = 0;
  int homeMounts = 0;
  bool bootstrapDone = false;

  void record(VersionGateEvent event) {
    if (event == VersionGateEvent.homeMounted) homeMounts++;
    onEvent?.call(event);
  }

  void verify() {
    if (!initialVerification.isCompleted) {
      initialVerification.complete();
    } else {
      container.read(appVersionGateProvider.notifier).recheck();
    }
  }

  void completeBootstrap() {
    bootstrapDone = true;
    record(VersionGateEvent.bootstrapCompleted);
    router.refresh();
  }

  void goHome() {
    record(VersionGateEvent.navigationGo);
    router.go('/home');
  }

  void pushProbe() {
    record(VersionGateEvent.navigationPush);
    unawaited(router.push<void>('/probe'));
  }

  void dispose() {
    container.dispose();
    router.dispose();
  }
}

class _QaHome extends StatefulWidget {
  const _QaHome({required this.record});
  final void Function(VersionGateEvent) record;
  @override
  State<_QaHome> createState() => _QaHomeState();
}

class _QaHomeState extends State<_QaHome> {
  @override
  void initState() {
    super.initState();
    widget.record(VersionGateEvent.homeMounted);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Home QA · sin datos ni sesión real')),
  );
}

class VersionGateQaApp extends StatelessWidget {
  const VersionGateQaApp({super.key, required this.runtime});
  final VersionGateQa runtime;

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    container: runtime.container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          const Expanded(child: CeltasApp()),
          Material(
            color: Colors.black,
            child: SafeArea(
              top: false,
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: runtime.verify,
                    child: const Text('Verificar'),
                  ),
                  TextButton(
                    onPressed: runtime.completeBootstrap,
                    child: const Text('Bootstrap QA'),
                  ),
                  TextButton(
                    onPressed: runtime.goHome,
                    child: const Text('go Home'),
                  ),
                  TextButton(
                    onPressed: runtime.pushProbe,
                    child: const Text('push ruta'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
