import 'package:celtas_mobile/shared/widgets/tab_placeholder.dart';
import 'package:flutter/material.dart';

/// Placeholder del tab Pedidos — se completa en el módulo 7 (Historial de
/// pedidos: `GET /orders/me` + detalle).
class OrdersPlaceholderScreen extends StatelessWidget {
  const OrdersPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholder(
      title: 'Pedidos',
      description: 'Tu historial de pedidos aparecerá acá (módulo 7).',
    );
  }
}