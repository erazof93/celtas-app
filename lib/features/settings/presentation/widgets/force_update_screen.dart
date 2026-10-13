import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/settings/application/version_gate_diagnostics.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL de la ficha de Celtas en Play Store — mismo `applicationId` que
/// `android/app/build.gradle.kts` (`com.celtas.celtas_mobile`).
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.celtas.celtas_mobile';

/// Pantalla declarativa de actualización; el gate la mantiene fuera del router.
class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({
    super.key,
    required this.minVersion,
    this.onStoreEvent,
  });

  /// `min_app_version` tal como la devolvió el backend (`X.Y.Z+BB`). Solo se
  /// muestra la parte `X.Y.Z` al usuario.
  final String? minVersion;
  final void Function(VersionGateEvent)? onStoreEvent;

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _opening = false;
  bool _openFailed = false;

  /// Mismo criterio que `_openWhatsapp` en `CheckoutScreen`: `launchUrl`
  /// dispara el intent real y `false`/`PlatformException` son la señal
  /// confiable de fallo — no se usa `canLaunchUrl` antes.
  Future<void> _openPlayStore() async {
    widget.onStoreEvent?.call(VersionGateEvent.storeOpening);
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(_playStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      opened = false;
    }
    widget.onStoreEvent?.call(
      opened ? VersionGateEvent.storeOpened : VersionGateEvent.storeFailed,
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      _openFailed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final displayVersion = widget.minVersion?.split('+').first;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomCenter,
              radius: 1.2,
              colors: [
                CeltasColors.orange.withValues(alpha: 0.25),
                CeltasColors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(CeltasSpacing.page),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('CELTAS', style: textTheme.displaySmall),
                          const SizedBox(height: 40),
                          const Icon(
                            Icons.system_update_rounded,
                            color: CeltasColors.gold,
                            size: 72,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Tu app está desactualizada',
                            style: textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Necesitas actualizar Celtas para seguir usando la app.',
                            style: textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          if (displayVersion != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Versión requerida: $displayVersion',
                              style: textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 32),
                          CeltasButton(
                            label: 'Abrir Play Store',
                            angled: true,
                            loading: _opening,
                            onPressed: _opening ? null : _openPlayStore,
                          ),
                          if (_openFailed) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                'No se pudo abrir Play Store. Actualiza la app manualmente '
                                'desde la tienda de aplicaciones.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: CeltasColors.redLight,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
