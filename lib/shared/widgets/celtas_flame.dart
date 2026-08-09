import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/svg_path.dart';
import 'package:flutter/material.dart';

/// Logo de la llama de Celtas, replicando el SVG del mockup
/// (`M4 20 L11 4 M11 4 C11 4 9 8 13 10 M20 20 L13 4 M13 4 C13 4 15 8 11 10`,
/// stroke-linecap round). Se usa en el Splash (88px, dorado) y en el header
/// del Login (24px, naranja).
class CeltasFlame extends StatelessWidget {
  const CeltasFlame({
    super.key,
    this.size = 24,
    this.color = CeltasColors.orange,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FlamePainter(color),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = parseSvgPath(
      'M4 20 L11 4 M11 4 C11 4 9 8 13 10 M20 20 L13 4 M13 4 C13 4 15 8 11 10',
    ).transform(Matrix4.diagonal3Values(scale, scale, 1).storage);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => oldDelegate.color != color;
}