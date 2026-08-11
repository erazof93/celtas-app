import 'package:flutter/material.dart';

/// Recorta las esquinas inferior-izquierda y superior-derecha en diagonal,
/// replicando el `clip-path: polygon(Npx 0,100% 0,100% calc(100% - Npx),
/// calc(100% - Npx) 100%,0 100%,0 Npx)` que reaparece en el CSS real del
/// mockup — botones (`CeltasButton`, cut 16px) y tarjetas de cupón (mockup 12,
/// cut 14px).
class AngledClipper extends CustomClipper<Path> {
  const AngledClipper(this.cut);

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
  bool shouldReclip(AngledClipper oldClipper) => oldClipper.cut != cut;
}
