import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL de la ficha de Celtas en Play Store — mismo `applicationId` que
/// `android/app/build.gradle.kts` (`com.celtas.celtas_mobile`).
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.celtas.celtas_mobile';

/// Overlay obligatorio de actualización: se muestra cuando
/// `appVersionCheckProvider` reporta `isUpdateRequired: true` (ver
/// `CeltasApp`). No se puede cerrar ni con el botón atrás — la única salida
/// es actualizar la app.
class ForceUpdateDialog extends StatefulWidget {
  const ForceUpdateDialog({super.key, required this.minVersion});

  /// `min_app_version` tal como la devolvió el backend (`X.Y.Z+BB`). Solo se
  /// muestra la parte `X.Y.Z` al usuario.
  final String? minVersion;

  @override
  State<ForceUpdateDialog> createState() => _ForceUpdateDialogState();
}

class _ForceUpdateDialogState extends State<ForceUpdateDialog> {
  bool _opening = false;
  bool _openFailed = false;

  /// Mismo criterio que `_openWhatsapp` en `CheckoutScreen`: `launchUrl`
  /// dispara el intent real y `false`/`PlatformException` son la señal
  /// confiable de fallo — no se usa `canLaunchUrl` antes.
  Future<void> _openPlayStore() async {
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
      child: AlertDialog(
        title: Text('Tu app está desactualizada', style: textTheme.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Necesitas actualizar Celtas para seguir usando la app.',
              style: textTheme.bodyMedium,
            ),
            if (displayVersion != null) ...[
              const SizedBox(height: 8),
              Text(
                'Versión requerida: $displayVersion',
                style: textTheme.bodySmall,
              ),
            ],
            if (_openFailed) ...[
              const SizedBox(height: 12),
              Text(
                'No se pudo abrir Play Store. Actualiza la app manualmente '
                'desde la tienda de aplicaciones.',
                style: textTheme.bodySmall?.copyWith(color: CeltasColors.redLight),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: _opening ? null : _openPlayStore,
            child: _opening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CeltasColors.black,
                    ),
                  )
                : const Text('Abrir Play Store'),
          ),
        ],
      ),
    );
  }
}
