import 'package:celtas_mobile/shared/widgets/svg_path.dart';
import 'package:flutter/material.dart';

/// Logo "G" de Google (los 4 colores), replicando el SVG del mockup
/// (viewBox 18x18). Se usa en el botón "Continuar con Google" del Login.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    final paint = Paint()..style = PaintingStyle.fill;

    void drawPath(String d, Color color) {
      paint.color = color;
      canvas.drawPath(
        parseSvgPath(d).transform(Matrix4.diagonal3Values(scale, scale, 1).storage),
        paint,
      );
    }

    drawPath(
      'M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.9c1.7-1.56 2.7-3.86 2.7-6.62z',
      const Color(0xFF4285F4),
    );
    drawPath(
      'M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.26c-.8.54-1.84.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.98v2.33A9 9 0 0 0 9 18z',
      const Color(0xFF34A853),
    );
    drawPath(
      'M3.95 10.7A5.4 5.4 0 0 1 3.67 9c0-.59.1-1.16.28-1.7V4.97H.98A9 9 0 0 0 0 9c0 1.45.35 2.83.98 4.03l2.97-2.33z',
      const Color(0xFFFBBC05),
    );
    drawPath(
      'M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58C13.46.89 11.42 0 9 0A9 9 0 0 0 .98 4.97l2.97 2.33C4.66 5.17 6.65 3.58 9 3.58z',
      const Color(0xFFEA4335),
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}