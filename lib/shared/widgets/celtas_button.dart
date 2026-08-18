import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/angled_clipper.dart';
import 'package:flutter/material.dart';

/// Botón principal de Celtas con las dos variantes del mockup:
///   - `angled`: esquinas cortadas en diagonal (`clip-path: polygon(16px 0, ...)`
///     del CSS real) — usado en Splash (COMENZAR), detalle de producto, carrito
///     y checkout.
///   - `rounded`: radio 12px — usado en Login (INICIAR SESIÓN) y Registro.
class CeltasButton extends StatelessWidget {
  const CeltasButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.angled = false,
    this.loading = false,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool angled;
  final bool loading;

  /// Controla SOLO el estilo visual (naranja vs. gris) — no si el botón
  /// responde al toque. Existe para poder mostrar feedback (ej. un
  /// SnackBar) cuando el usuario toca un botón que se ve deshabilitado por
  /// una validación pendiente, en vez de que el toque no haga nada: con
  /// `onPressed: null` el `InkWell` ni siquiera recibe el gesto. El toque
  /// real siempre depende solo de `onPressed != null && !loading` (ver
  /// `InkWell.onTap` abajo), nunca de este flag.
  final bool enabled;

  /// Ícono opcional a la izquierda del label (ej. WhatsApp en checkout,
  /// `gap: 10` como en el CSS real del mockup).
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final canTap = onPressed != null && !loading;
    final looksEnabled = enabled && canTap;
    final textTheme = Theme.of(context).textTheme;

    // Botones con ícono (ej. CTA de WhatsApp) usan 14px — el CSS real del
    // mockup pide 15px, pero con el label completo ("CONFIRMAR PEDIDO POR
    // WHATSAPP") + ícono + gap, 15px se corta con ellipsis en dispositivos
    // reales de 1080px de ancho físico (bug encontrado en la auditoría del
    // módulo 10, dispositivo real Xiaomi) — el resto (COMENZAR, CONTINUAR,
    // etc.) sigue en 16px.
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: textTheme.labelLarge?.copyWith(
        fontSize: icon == null ? 16 : 14,
        fontWeight: FontWeight.w800,
        color: looksEnabled ? CeltasColors.black : CeltasColors.textSubtle,
      ),
    );

    final content = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: CeltasColors.black,
            ),
          )
        : icon == null
            ? labelText
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon!,
                  const SizedBox(width: 10),
                  Flexible(child: labelText),
                ],
              );

    final button = Material(
      color: looksEnabled ? CeltasColors.orange : CeltasColors.border,
      borderRadius: angled ? null : BorderRadius.circular(CeltasRadii.input),
      clipBehavior: angled ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: canTap ? onPressed : null,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: icon == null ? 24 : 16),
          child: content,
        ),
      ),
    );

    if (!angled) return button;

    return ClipPath(
      clipper: const AngledClipper(16),
      child: button,
    );
  }
}