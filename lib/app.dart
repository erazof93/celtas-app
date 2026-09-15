import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raíz de la app: tema + router con guard de sesión.
class CeltasApp extends ConsumerWidget {
  const CeltasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Celtas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      // `builder` envuelve el contenido ya ruteado (el `Navigator` de
      // `go_router` ya existe acá) — es el punto seguro para montar el
      // overlay obligatorio de versión mínima sin pelear con el
      // `navigatorKey` interno de `GoRouter`.
      builder: (context, child) => _AppVersionGate(child: child),
    );
  }
}

/// Muestra `ForceUpdateDialog` (no descartable) apenas
/// `appVersionCheckProvider` resuelve `isUpdateRequired: true`. Fail-open por
/// diseño: mientras carga, si falla, o si el backend no bloquea, no hace
/// nada — ver doc de `appVersionCheckProvider`.
class _AppVersionGate extends ConsumerStatefulWidget {
  const _AppVersionGate({required this.child});

  final Widget? child;

  @override
  ConsumerState<_AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends ConsumerState<_AppVersionGate> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppVersionCheck>>(appVersionCheckProvider, (
      previous,
      next,
    ) {
      final check = next.valueOrNull;
      if (_dialogShown || check == null || !check.isUpdateRequired) return;
      _dialogShown = true;
      // Post-frame: `showDialog` no puede llamarse durante el `build` que
      // este mismo `ref.listen` dispara.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // El `context` de este widget NO sirve: `_AppVersionGate` envuelve a
        // `child` (que contiene el `Navigator` de `go_router`), así que el
        // `Navigator` es descendiente, no ancestro, de este `context` —
        // `showDialog(context: context)` fallaba con "context that does not
        // include a Navigator". Se usa el `context` del `Navigator` raíz vía
        // `rootNavigatorKey` en su lugar (ver doc en `app_router.dart`).
        final navigatorContext = rootNavigatorKey.currentContext;
        if (navigatorContext == null) return;
        showDialog<void>(
          context: navigatorContext,
          barrierDismissible: false,
          builder: (_) => ForceUpdateDialog(minVersion: check.minVersion),
        );
      });
    });

    return widget.child ?? const SizedBox.shrink();
  }
}