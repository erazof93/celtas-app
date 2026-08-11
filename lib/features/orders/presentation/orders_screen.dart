import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:celtas_mobile/features/orders/presentation/widgets/order_status_badge.dart';
import 'package:celtas_mobile/shared/utils/spanish_date.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Historial de pedidos (mockup 10 · HISTORIAL DE PEDIDOS).
///
/// `GET /orders/me` — lista completa, sin paginar (el backend no pagina ni
/// filtra ese endpoint para el cliente, ver `OrderHistoryRepository`). El
/// checkout invalida `orderListProvider` tras confirmar un pedido nuevo.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderListProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Text(
                'Tus pedidos',
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: CeltasColors.orange,
                backgroundColor: CeltasColors.surface,
                onRefresh: () async {
                  ref.invalidate(orderListProvider);
                  try {
                    await ref.read(orderListProvider.future);
                  } catch (_) {
                    // El estado de error ya se muestra en el `.when` de abajo.
                  }
                },
                child: ordersAsync.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [SlowBackendNotice()],
                  ),
                  error: (error, _) => ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _OrdersError(
                        message: error is ApiException
                            ? error.message
                            : 'No se pudo cargar tu historial de pedidos.',
                      ),
                    ],
                  ),
                  data: (orders) => orders.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: const [_EmptyOrders()],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _OrderCard(order: orders[index]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dimmed = order.status == OrderStatus.cancelado;
    return Opacity(
      opacity: dimmed ? 0.7 : 1,
      child: GestureDetector(
        key: ValueKey('order-card-${order.id}'),
        onTap: () => context.push('/orders/${order.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: CeltasColors.card,
            border: Border.all(color: CeltasColors.border),
            borderRadius: BorderRadius.circular(CeltasRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #${order.shortId}',
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CeltasColors.cream,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${formatShortDate(order.createdAt)} · ${order.itemsCount} '
                '${order.itemsCount == 1 ? 'item' : 'items'}',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: CeltasColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.cream,
                    ),
                  ),
                  Text(
                    'S/ ${order.total.toStringAsFixed(2)}',
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.cream,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersError extends ConsumerWidget {
  const _OrdersError({required this.message});

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
            onPressed: () => ref.invalidate(orderListProvider),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no hiciste ningún pedido',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CeltasColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}
