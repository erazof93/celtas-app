import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/svg_path.dart';
import 'package:flutter/material.dart';

/// Ícono de trazo (stroke) a partir de un path SVG del mockup.
///
/// Replica el estilo de los SVG del design reference: `fill="none"`,
/// `stroke-linecap="round"`, `stroke-linejoin="round"`. Se usa en el bottom
/// nav (íconos de 21px) y sirve para los menús de Perfil y demás íconos de
/// línea del mockup.
class SvgStrokeIcon extends StatelessWidget {
  const SvgStrokeIcon({
    super.key,
    required this.path,
    this.size = 21,
    this.color = CeltasColors.textSubtle,
    this.strokeWidth = 2,
  });

  /// `d` del path SVG (viewBox 24×24), tal cual está en el mockup.
  final String path;

  /// Tamaño del ícono en píxeles lógicos (el path se escala desde 24×24).
  final double size;

  final Color color;

  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SvgStrokePainter(path, color, strokeWidth),
    );
  }
}

class _SvgStrokePainter extends CustomPainter {
  const _SvgStrokePainter(this.path, this.color, this.strokeWidth);

  final String path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final scaled = parseSvgPath(path)
        .transform(Matrix4.diagonal3Values(scale, scale, 1).storage);
    canvas.drawPath(scaled, paint);
  }

  @override
  bool shouldRepaint(_SvgStrokePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}