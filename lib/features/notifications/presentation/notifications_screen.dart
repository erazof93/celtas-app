import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/application/notification_target.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/shared/utils/spanish_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Historial local de notificaciones push recibidas.
///
/// Sin pantalla en `design-reference/` (no es uno de los 12 mockups) — diseño
/// nuevo, consistente con el resto de la app (mismo patrón de tarjeta que
/// `orders_screen.dart`, mismo patrón de estado vacío que `cart_screen.dart`/
/// `home_screen.dart`). `NotificationService` (módulo 9) guarda cada
/// notificación acá desde los mismos 3 puntos donde ya intercepta
/// foreground/background/terminated; esta pantalla solo lee
/// `notificationHistoryProvider`. Tocar un ítem navega exactamente igual que
/// la notificación real, vía `NotificationTarget.fromPayload` sobre el
/// payload guardado (misma clasificación que usa `NotificationService`, sin
/// duplicar esa lógica).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Entrar a la pantalla marca todo como leído (el badge de la campana
    // vuelve a 0) — no hace falta marcar ítem por ítem.
    ref.read(notificationHistoryProvider.notifier).markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(notificationHistoryProvider);
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
                    key: const ValueKey('notifications-back'),
                    onTap: () => context.pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: CeltasColors.cream,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Notificaciones',
                    style: textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.cream,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CeltasColors.orange,
                  ),
                ),
                error: (error, _) => _NotificationsError(
                  onRetry: () => ref.invalidate(notificationHistoryProvider),
                ),
                data: (items) => items.isEmpty
                    ? const _EmptyNotifications()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _NotificationCard(item: items[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final NotificationHistoryItem item;

  void _handleTap(BuildContext context) {
    switch (NotificationTarget.fromPayload(item.data)) {
      case OrderNotificationTarget(:final orderId):
        context.push('/orders/$orderId');
      case CouponNotificationTarget():
        context.go('/coupons');
      case BusinessHoursNotificationTarget():
        // Sin pantalla propia — no debería dispararse nunca (ver `tappable`
        // abajo, que ya excluye este caso), pero queda acá por la
        // exhaustividad del switch.
        break;
      case NoneNotificationTarget():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Sin pantalla a la que navegar para `BusinessHoursNotificationTarget`
    // (igual que `NoneNotificationTarget`) — no tappable, para no dejar un
    // toque sin ningún efecto visible.
    final target = NotificationTarget.fromPayload(item.data);
    final tappable =
        target is! NoneNotificationTarget &&
        target is! BusinessHoursNotificationTarget;

    return GestureDetector(
      onTap: tappable ? () => _handleTap(context) : null,
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
            Text(
              item.title,
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CeltasColors.cream,
              ),
            ),
            if (item.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.body,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: CeltasColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              formatShortDateTime(item.receivedAt),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: CeltasColors.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'No se pudo cargar tu historial de notificaciones',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: CeltasColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CeltasSpacing.page),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: CeltasColors.textSubtle,
            ),
            const SizedBox(height: 12),
            Text(
              'No tienes notificaciones todavía',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Acá vas a ver los cupones y cambios de estado de tus pedidos.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: CeltasColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
