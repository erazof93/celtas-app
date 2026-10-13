import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/notifications/application/notification_service.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/version_gate_diagnostics.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raíz de la app: tema + router con guard de sesión.
class CeltasApp extends ConsumerWidget {
  const CeltasApp({super.key, this.notifications});
  final NotificationService? notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Celtas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      // El Router solo se monta después de la verificación inicial y mientras
      // no haya bloqueo. Su instancia y la sesión permanecen en Riverpod.
      builder: (context, child) =>
          _AppVersionGate(notifications: notifications, child: child),
    );
  }
}

/// Gate declarativo fuera de las rutas de go_router.
class _AppVersionGate extends ConsumerStatefulWidget {
  const _AppVersionGate({required this.child, this.notifications});

  final Widget? child;
  final NotificationService? notifications;

  @override
  ConsumerState<_AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends ConsumerState<_AppVersionGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.notifications?.setRouterReady(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(versionGateDiagnosticsProvider)(VersionGateEvent.resumed);
      ref.read(appVersionGateProvider.notifier).recheck();
    }
  }

  // El Router no está montado durante el bloqueo: consume también el back
  // del binding, que de otro modo podría cerrar la app al no tener dispatcher.
  @override
  Future<bool> didPopRoute() async {
    final blocked = ref.read(appVersionGateProvider).blocksNavigation;
    if (blocked) {
      ref.read(versionGateDiagnosticsProvider)(VersionGateEvent.backBlocked);
    }
    return blocked;
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) =>
      ref.read(appVersionGateProvider).blocksNavigation;

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(appVersionGateProvider);
    widget.notifications?.setRouterReady(false);
    if (!gate.blocksNavigation) {
      if (widget.notifications != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !ref.read(appVersionGateProvider).blocksNavigation) {
            widget.notifications?.setRouterReady(true);
          }
        });
      }
      return widget.child ?? const SizedBox.shrink();
    }
    // Navigator independiente: PopScope registra el bloqueo de Atrás y genera
    // NavigationNotification también para el back predictivo de Android.
    return Navigator(
      pages: [
        MaterialPage<void>(
          key: const ValueKey('version-gate'),
          child: PopScope(
            canPop: false,
            child: gate.status == AppVersionGateStatus.updateRequired
                ? ForceUpdateScreen(
                    minVersion: gate.minVersion,
                    onStoreEvent: ref.read(versionGateDiagnosticsProvider),
                  )
                : const Scaffold(
                    body: SafeArea(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('CELTAS'),
                            SizedBox(height: 24),
                            CircularProgressIndicator(),
                            SizedBox(height: 24),
                            Text('Verificando tu versión…'),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}
