import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:celtas_mobile/features/orders/presentation/widgets/order_status_badge.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Detalle de pedido (mockup 11 · DETALLE DE PEDIDO).
///
/// `GET /orders/:id`. Los items muestran el SNAPSHOT del pedido (`name`,
/// `unitPrice` copiados al crear el pedido, nunca el producto actual del
/// menú) y la dirección de entrega es el `addressSnapshot` decodificado
/// (`order.address`) — tampoco depende de que la dirección guardada siga
/// existiendo.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const SvgStrokeIcon(
                      path: 'M15 18l-6-6 6-6',
                      size: 18,
                      color: CeltasColors.cream,
                      strokeWidth: 2.2,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: orderAsync.maybeWhen(
                      data: (order) => Text(
                        'Pedido #${order.shortId}',
                        style: textTheme.headlineSmall?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: CeltasColors.cream,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      orElse: () => Text(
                        'Pedido',
                        style: textTheme.headlineSmall?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: CeltasColors.cream,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orderAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: SlowBackendNotice(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: _OrderDetailError(
                    orderId: orderId,
                    message: error is ApiException
                        ? error.message
                        : 'No se pudo cargar el detalle del pedido.',
                  ),
                ),
                data: (order) => ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    _StatusBanner(order: order),
                    const SizedBox(height: 20),
                    Text('ITEMS', style: textTheme.labelSmall),
                    const SizedBox(height: 10),
                    for (final item in order.items) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.name}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                color: CeltasColors.cream,
                              ),
                            ),
                          ),
                          Text(
                            'S/ ${item.subtotal.toStringAsFixed(2)}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: CeltasColors.cream,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 10),
                    Container(height: 1, color: CeltasColors.divider),
                    const SizedBox(height: 18),
                    Text('DIRECCIÓN DE ENTREGA', style: textTheme.labelSmall),
                    const SizedBox(height: 10),
                    Text(
                      '🏠 ${order.address.alias} — ${order.address.fullAddress}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: CeltasColors.cream,
                      ),
                    ),
                    if (order.address.reference != null &&
                        order.address.reference!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        order.address.reference!,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: CeltasColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(height: 1, color: CeltasColors.divider),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: textTheme.bodyLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CeltasColors.cream,
                          ),
                        ),
                        Text(
                          'S/ ${order.total.toStringAsFixed(2)}',
                          style: textTheme.bodyLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CeltasColors.cream,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = order.status.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CeltasColors.surfaceSelected,
        border: Border.all(color: accent, width: 1.5),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 20, color: accent),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.status.label.toUpperCase(),
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              Text(
                order.status.detailDescription,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: CeltasColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderDetailError extends ConsumerWidget {
  const _OrderDetailError({required this.orderId, required this.message});

  final String orderId;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        border: Border.all(color: CeltasColors.border),
        borderRadius: BorderRadius.circular(CeltasRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CeltasColors.redLight,
                ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(orderDetailProvider(orderId)),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}
