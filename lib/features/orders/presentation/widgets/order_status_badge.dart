import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:flutter/material.dart';

/// Badge de estado de pedido, con la paleta corregida del mockup (ver nota en
/// `CeltasColors.statusEnCamino`): `pendiente`/`confirmado`/`entregado`
/// mantienen los colores originales del mockup (ya eran distinguibles entre
/// sí), `en_camino` pasa de naranja-contorno a azul-relleno (color fuera de
/// la paleta cálida, para no compartir hue con `confirmado` ni con
/// `cancelado`), y `cancelado` queda como el único estado que usa rojo.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  static const _labels = {
    OrderStatus.pendiente: 'PENDIENTE',
    OrderStatus.confirmado: 'CONFIRMADO',
    OrderStatus.enCamino: 'EN CAMINO',
    OrderStatus.entregado: 'ENTREGADO',
    OrderStatus.cancelado: 'CANCELADO',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[status]!;
    final (background, border, textColor) = switch (status) {
      OrderStatus.pendiente => (CeltasColors.gold, null, CeltasColors.black),
      OrderStatus.confirmado => (
          CeltasColors.orange,
          null,
          CeltasColors.cream
        ),
      OrderStatus.enCamino => (
          CeltasColors.statusEnCamino,
          null,
          CeltasColors.cream
        ),
      OrderStatus.entregado => (
          CeltasColors.cream,
          null,
          CeltasColors.black
        ),
      // Único estado con relleno transparente + borde: refuerza que es el
      // único que usa rojo, y que es un estado "negativo" a diferencia de
      // los otros cuatro (todos con relleno sólido).
      OrderStatus.cancelado => (null, CeltasColors.redLight, CeltasColors.redLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: border != null ? Border.all(color: border, width: 1.5) : null,
        borderRadius: BorderRadius.circular(CeltasRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

extension OrderStatusLabel on OrderStatus {
  /// Texto humano corto para usar fuera del badge (ej. banner del detalle).
  String get label => switch (this) {
        OrderStatus.pendiente => 'Pendiente',
        OrderStatus.confirmado => 'Confirmado',
        OrderStatus.enCamino => 'En camino',
        OrderStatus.entregado => 'Entregado',
        OrderStatus.cancelado => 'Cancelado',
      };

  /// Frase del banner de estado en el detalle (mockup 11).
  String get detailDescription => switch (this) {
        OrderStatus.pendiente => 'Tu pedido está pendiente de confirmación',
        OrderStatus.confirmado => 'Tu pedido fue confirmado',
        OrderStatus.enCamino => 'Tu pedido está en camino',
        OrderStatus.entregado => 'Tu pedido fue entregado',
        OrderStatus.cancelado => 'Tu pedido fue cancelado',
      };

  Color get accentColor => switch (this) {
        OrderStatus.pendiente => CeltasColors.gold,
        OrderStatus.confirmado => CeltasColors.orange,
        OrderStatus.enCamino => CeltasColors.statusEnCamino,
        OrderStatus.entregado => CeltasColors.cream,
        OrderStatus.cancelado => CeltasColors.redLight,
      };
}
