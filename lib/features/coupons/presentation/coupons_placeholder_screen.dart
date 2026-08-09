import 'package:celtas_mobile/shared/widgets/tab_placeholder.dart';
import 'package:flutter/material.dart';

/// Placeholder del tab Cupones — se completa en el módulo 8 (Mis cupones:
/// `GET /coupons/me` con distinción activo/usado/expirado).
class CouponsPlaceholderScreen extends StatelessWidget {
  const CouponsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholder(
      title: 'Cupones',
      description: 'Tus cupones aparecerán acá (módulo 8).',
    );
  }
}