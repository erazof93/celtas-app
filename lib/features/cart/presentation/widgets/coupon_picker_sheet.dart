import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/coupons/data/models/coupon_status.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart'
    show CouponDiscountType;
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet para elegir un cupón propio y aplicarlo al carrito
/// (`GET /coupons/me`, mismo provider que "Mis cupones"). No hay mockup para
/// este selector — se diseñó desde cero, mismo caso que el ícono de vaciar
/// carrito.
///
/// Solo lista cupones con `effectiveStatus == active`: los usados/expirados
/// no tienen cabida en un selector de "aplicar" (la vista completa con los
/// 3 estados ya vive en `/coupons`). Los activos que no alcanzan el
/// `minPurchaseAmount` contra el subtotal actual del carrito se muestran
/// pero no son tocables, con el monto exacto que falta — mismo criterio de
/// "nunca un mensaje genérico" ya aplicado en el resto del flujo de cupones
/// (ver `CartNotifier.applyCoupon`).
///
/// Devuelve el `code` elegido vía `Navigator.pop`; quien abre el sheet debe
/// reutilizar el mismo flujo de `POST /coupons/validate` que ya existe para
/// el campo de texto manual, en vez de duplicar esa validación acá.
class CouponPickerSheet extends ConsumerWidget {
  const CouponPickerSheet({required this.subtotal, super.key});

  final double subtotal;

  static Future<String?> show(
    BuildContext context, {
    required double subtotal,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CeltasColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CeltasRadii.card),
        ),
      ),
      builder: (_) => CouponPickerSheet(subtotal: subtotal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(userCouponListProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CeltasColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mis cupones',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CeltasColors.cream,
                  ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: couponsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: SlowBackendNotice(),
                ),
                error: (error, _) => _PickerError(
                  message: error is ApiException
                      ? error.message
                      : 'No se pudieron cargar tus cupones.',
                  onRetry: () => ref.invalidate(userCouponListProvider),
                ),
                data: (coupons) {
                  final active = coupons
                      .where((c) => c.effectiveStatus == CouponStatus.active)
                      .toList();
                  if (active.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: _PickerEmpty(),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: active.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final coupon = active[index];
                      final eligible = !coupon.hasMinPurchase ||
                          subtotal >= coupon.minPurchaseAmount!;
                      return _PickerCouponTile(
                        coupon: coupon,
                        subtotal: subtotal,
                        eligible: eligible,
                        onTap: eligible
                            ? () => Navigator.of(context).pop(coupon.code)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerCouponTile extends StatelessWidget {
  const _PickerCouponTile({
    required this.coupon,
    required this.subtotal,
    required this.eligible,
    required this.onTap,
  });

  final UserCoupon coupon;
  final double subtotal;
  final bool eligible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Mismo formato que `CouponsScreen`: porcentaje entero, monto fijo con
    // 2 decimales ("S/ X.XX"), nunca el separador de miles del mockup.
    final discountLabel = coupon.discountType == CouponDiscountType.percentage
        ? '${coupon.discountValue.toStringAsFixed(0)}% OFF'
        : 'S/ ${coupon.discountValue.toStringAsFixed(2)} OFF';

    return Opacity(
      opacity: eligible ? 1 : 0.55,
      child: GestureDetector(
        key: ValueKey('coupon-picker-${coupon.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: CeltasColors.surface,
            border: Border.all(
              color: eligible ? CeltasColors.gold : CeltasColors.border,
            ),
            borderRadius: BorderRadius.circular(CeltasRadii.input),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      discountLabel,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color:
                            eligible ? CeltasColors.gold : CeltasColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código: ${coupon.code}',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: CeltasColors.textMuted,
                      ),
                    ),
                    if (!eligible) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Te faltan S/'
                        '${(coupon.minPurchaseAmount! - subtotal).toStringAsFixed(2)}'
                        ' para usar este cupón',
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: CeltasColors.redLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (eligible)
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: CeltasColors.textSubtle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerError extends StatelessWidget {
  const _PickerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CeltasColors.redLight,
              ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
          child: const Text('REINTENTAR'),
        ),
      ],
    );
  }
}

class _PickerEmpty extends StatelessWidget {
  const _PickerEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_offer_outlined,
          size: 32,
          color: CeltasColors.textSubtle,
        ),
        const SizedBox(height: 10),
        Text(
          'No tienes cupones activos para aplicar',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CeltasColors.textMuted,
              ),
        ),
      ],
    );
  }
}
