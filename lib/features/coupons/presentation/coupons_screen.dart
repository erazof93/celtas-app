import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/coupons/data/models/coupon_status.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart'
    show CouponDiscountType;
import 'package:celtas_mobile/shared/utils/spanish_date.dart';
import 'package:celtas_mobile/shared/widgets/angled_clipper.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mis cupones (mockup 12 · MIS CUPONES).
///
/// `GET /coupons/me` — lista completa, sin paginar (ver `CouponRepository`).
/// Distingue los 3 estados reales del contrato (`CouponStatus`): el mockup
/// original solo mostraba dos cupones "activos" con colores distintos (sin
/// relación con el dato real) y nunca mostraba cómo luce un cupón `used` — se
/// diseñó ese tercer estado desde cero, y se unificó el acento de "activo" a
/// uno solo (dorado) para no repetir la confusión cromática que ya se
/// corrigió en los badges de pedidos.
///
/// El estado que se pinta es `effectiveStatus`
/// (`lib/features/coupons/data/models/user_coupon.dart`), no `status` crudo:
/// el backend solo pasa `active` → `expired` una vez al día (cron), así que
/// un cupón puede seguir marcado `active` hasta 24h después de vencer.
///
/// Orden local (`_sortedByEffectiveStatus`, sin tocar el backend): activos →
/// usados → expirados. Decisión de producto: nunca se ocultan ni se
/// recortan los vencidos/usados — ver un cupón vencido refuerza que hubo
/// beneficios reales y da incentivo a revisar la app seguido.
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(userCouponListProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Text(
                'Mis cupones',
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
                  ref.invalidate(userCouponListProvider);
                  try {
                    await ref.read(userCouponListProvider.future);
                  } catch (_) {
                    // El estado de error ya se muestra en el `.when` de abajo.
                  }
                },
                child: couponsAsync.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [SlowBackendNotice()],
                  ),
                  error: (error, _) => ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _CouponsError(
                        message: error is ApiException
                            ? error.message
                            : 'No se pudieron cargar tus cupones.',
                      ),
                    ],
                  ),
                  data: (coupons) {
                    final sorted = _sortedByEffectiveStatus(coupons);
                    return sorted.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: const [_EmptyCoupons()],
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(24, 14, 24, 16),
                            itemCount: sorted.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) =>
                                _CouponCard(coupon: sorted[index]),
                          );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Orden local por `effectiveStatus` (no `status` crudo, mismo criterio del
/// resto de la pantalla): activos primero, luego usados, luego expirados al
/// final. Decisión de producto: los vencidos/usados se muestran siempre —
/// nunca se ocultan ni se recortan — refuerzan que el cliente recibió
/// beneficios reales con el tiempo. `where` preserva el orden relativo
/// dentro de cada grupo (llega ya así del backend), así que no hace falta
/// un `sort` con comparador (Dart no garantiza que sea estable).
List<UserCoupon> _sortedByEffectiveStatus(List<UserCoupon> coupons) => [
      ...coupons.where((c) => c.effectiveStatus == CouponStatus.active),
      ...coupons.where((c) => c.effectiveStatus == CouponStatus.used),
      ...coupons.where((c) => c.effectiveStatus == CouponStatus.expired),
    ];

class _CouponStyle {
  const _CouponStyle({
    required this.background,
    required this.borderColor,
    required this.accentColor,
    required this.codeColor,
    required this.opacity,
  });

  final Color background;
  final Color borderColor;
  final Color accentColor;
  final Color codeColor;
  final double opacity;
}

/// El mockup usa borde punteado (`dashed`) para `active`/`expired`; Flutter
/// no lo soporta nativamente sin un `CustomPainter` propio (mismo caso ya
/// documentado en `addresses_screen.dart`), así que los 3 estados usan borde
/// sólido y se distinguen por color + opacidad + etiqueta en su lugar.
_CouponStyle _styleFor(CouponStatus status) => switch (status) {
      CouponStatus.active => const _CouponStyle(
          background: CeltasColors.surfaceSelected,
          borderColor: CeltasColors.gold,
          accentColor: CeltasColors.gold,
          codeColor: CeltasColors.cream,
          opacity: 1,
        ),
      // Ni el mockup lo mostraba: tono neutro, "cerrado pero no negativo",
      // distinto del rojo de `expired`.
      CouponStatus.used => const _CouponStyle(
          background: CeltasColors.card,
          borderColor: CeltasColors.border,
          accentColor: CeltasColors.textMuted,
          codeColor: CeltasColors.textMuted,
          opacity: 1,
        ),
      CouponStatus.expired => const _CouponStyle(
          background: CeltasColors.card,
          borderColor: CeltasColors.borderStrong,
          accentColor: CeltasColors.textMuted,
          codeColor: CeltasColors.textSubtle,
          opacity: 0.55,
        ),
    };

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final UserCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = coupon.effectiveStatus;
    final style = _styleFor(status);
    // Porcentaje sin decimales (siempre entero en la práctica); monto fijo
    // con 2 decimales, igual que el resto de la app (checkout, pedidos)
    // formatea soles — nunca el separador de miles del mockup (estilo
    // argentino, "$3.000"), la app ya usa "S/ X.XX" en todos lados.
    final discountLabel = coupon.discountType == CouponDiscountType.percentage
        ? '${coupon.discountValue.toStringAsFixed(0)}% OFF'
        : 'S/ ${coupon.discountValue.toStringAsFixed(2)} OFF';

    return Opacity(
      opacity: style.opacity,
      child: ClipPath(
        clipper: const AngledClipper(14),
        child: Container(
          key: ValueKey('coupon-card-${coupon.id}'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.background,
            border: Border.all(color: style.borderColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discountLabel,
                          style: textTheme.headlineSmall?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: style.accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Código: ${coupon.code}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: style.codeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusTag(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _conditionsLabel(coupon, status),
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  color: status == CouponStatus.expired
                      ? CeltasColors.textSubtle
                      : CeltasColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(UserCoupon coupon, CouponStatus status) => switch (status) {
        CouponStatus.used => coupon.usedAt != null
            ? 'Usado el ${formatLongDate(coupon.usedAt!)}'
            : 'Usado',
        CouponStatus.expired =>
          'Venció el ${formatLongDate(coupon.expiresAt)}',
        CouponStatus.active =>
          'Válido hasta ${formatLongDate(coupon.expiresAt)}',
      };

  /// Mismo patrón del mockup original (`design-reference`, tarjeta "Pedido
  /// mínimo $15.000 · Válido hasta 20 ago 2026"): el mínimo de compra va en
  /// la misma línea secundaria que la fecha, unido con " · ". Formato de
  /// moneda "S/ X.XX" (2 decimales), consistente con el resto de la app —
  /// no el separador de miles del mockup.
  String _conditionsLabel(UserCoupon coupon, CouponStatus status) {
    final dateLabel = _dateLabel(coupon, status);
    if (!coupon.hasMinPurchase) return dateLabel;
    final minAmount = coupon.minPurchaseAmount!.toStringAsFixed(2);
    return 'Pedido mínimo: S/ $minAmount · $dateLabel';
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final CouponStatus status;

  @override
  Widget build(BuildContext context) {
    // El cupón activo no lleva etiqueta (el mockup tampoco la usa: el acento
    // dorado + borde punteado ya lo comunican). `used`/`expired` sí, porque
    // son los dos estados que el mockup nunca distinguió con claridad.
    if (status == CouponStatus.active) return const SizedBox.shrink();

    final (label, color) = switch (status) {
      CouponStatus.used => ('USADO', CeltasColors.textMuted),
      CouponStatus.expired => ('EXPIRADO', CeltasColors.redLight),
      CouponStatus.active => ('', CeltasColors.cream),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(CeltasRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _CouponsError extends ConsumerWidget {
  const _CouponsError({required this.message});

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
            onPressed: () => ref.invalidate(userCouponListProvider),
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCoupons extends StatelessWidget {
  const _EmptyCoupons();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.local_offer_outlined,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía no tienes cupones',
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
