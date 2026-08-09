import 'package:celtas_mobile/core/theme/app_theme.dart';
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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool angled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final textTheme = Theme.of(context).textTheme;

    final content = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: CeltasColors.black,
            ),
          )
        : Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.labelLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: enabled ? CeltasColors.black : CeltasColors.textSubtle,
            ),
          );

    final button = Material(
      color: enabled ? CeltasColors.orange : CeltasColors.border,
      borderRadius: angled ? null : BorderRadius.circular(CeltasRadii.input),
      clipBehavior: angled ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: content,
        ),
      ),
    );

    if (!angled) return button;

    return ClipPath(
      clipper: const _AngledClipper(16),
      child: button,
    );
  }
}

/// Recorta las esquinas inferiores-izquierda y superiores-derecha en diagonal,
/// replicando el `clip-path: polygon(16px 0,100% 0,100% calc(100% - 16px),
/// calc(100% - 16px) 100%,0 100%,0 16px)` del CSS real del mockup.
class _AngledClipper extends CustomClipper<Path> {
  const _AngledClipper(this.cut);

  final double cut;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(_AngledClipper oldClipper) => oldClipper.cut != cut;
}