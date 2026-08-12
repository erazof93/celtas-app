import 'package:cached_network_image/cached_network_image.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Carrito (mockup 06 · CARRITO).
///
/// Estado 100% local (`cartProvider`). Muestra los ítems con stepper de
/// cantidad, subtotal por ítem, total general y el campo de cupón que valida
/// contra `POST /coupons/validate` ANTES de ir al checkout — el descuento se
/// muestra como vista previa, el canje real ocurre al crear el pedido
/// (módulo 5).
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _couponController = TextEditingController();
  bool _validating = false;
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponError = 'Ingresá un código de cupón');
      return;
    }
    setState(() {
      _validating = true;
      _couponError = null;
    });
    try {
      final subtotal = ref.read(cartProvider).subtotal;
      final coupon = await ref
          .read(couponRepositoryProvider)
          .validateCoupon(code, subtotal: subtotal);
      // El carrito puede haber cambiado mientras se esperaba la respuesta
      // (los steppers de cantidad siguen habilitados durante la espera) —
      // `applyCoupon` re-chequea el mínimo contra el subtotal actual antes
      // de aplicarlo.
      final applied = ref.read(cartProvider.notifier).applyCoupon(coupon);
      if (mounted) {
        setState(() {
          _validating = false;
          _couponError = applied
              ? null
              : 'Este cupón requiere un pedido mínimo de S/'
                  '${coupon.minPurchaseAmount!.toStringAsFixed(2)}';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _validating = false;
          _couponError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _validating = false;
          _couponError = 'No se pudo validar el cupón. Inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    ref.listen<CartState>(cartProvider, (previous, next) {
      final notice = next.couponRemovedNotice;
      if (notice == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              notice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CeltasColors.cream,
                  ),
            ),
            backgroundColor: CeltasColors.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      ref.read(cartProvider.notifier).dismissCouponNotice();
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título (mockup: Cinzel 22px, padding 14/24/4).
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Text(
                'Tu carrito',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.cream,
                    ),
              ),
            ),
            Expanded(
              child: cart.items.isEmpty
                  ? const _EmptyCart()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                      children: [
                        for (var i = 0; i < cart.items.length; i++) ...[
                          if (i > 0) const _ItemDivider(),
                          _CartItemRow(item: cart.items[i]),
                        ],
                        const SizedBox(height: 6),
                        _CouponSection(
                          controller: _couponController,
                          validating: _validating,
                          error: _couponError,
                          appliedCoupon: cart.coupon,
                          onApply: _applyCoupon,
                          onRemoveCoupon: () => ref
                              .read(cartProvider.notifier)
                              .removeCoupon(),
                        ),
                      ],
                    ),
            ),
            // Barra de totales + CONTINUAR (mockup: padding 16/24/28).
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              decoration: const BoxDecoration(
                color: CeltasColors.black,
                border: Border(top: BorderSide(color: CeltasColors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TotalRow(
                    label: 'Subtotal',
                    value: 'S/ ${cart.subtotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: CeltasColors.textMuted,
                        ),
                  ),
                  if (cart.coupon != null) ...[
                    const SizedBox(height: 6),
                    _TotalRow(
                      label: 'Cupón ${cart.coupon!.code}',
                      value: '-S/ ${cart.discount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: CeltasColors.gold,
                          ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _TotalRow(
                    label: 'Total',
                    value: 'S/ ${cart.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CeltasColors.cream,
                        ),
                  ),
                  const SizedBox(height: 16),
                  CeltasButton(
                    key: const ValueKey('cart-continue'),
                    angled: true,
                    label: 'CONTINUAR',
                    onPressed: cart.items.isEmpty
                        ? null
                        : () => context.push('/checkout'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fila de ítem del carrito ───────────────────────────────────────────────

class _CartItemRow extends ConsumerWidget {
  const _CartItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _CartItemImage(item: item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CeltasColors.cream,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'S/ ${item.unitPrice.toStringAsFixed(2)} c/u',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: CeltasColors.textMuted,
                      ),
                ),
                const SizedBox(height: 6),
                _CartStepper(item: item),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'S/ ${item.lineTotal.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: CeltasColors.gold,
                ),
          ),
        ],
      ),
    );
  }
}

class _CartItemImage extends StatelessWidget {
  const _CartItemImage({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: CeltasColors.surface,
          borderRadius: BorderRadius.circular(CeltasRadii.control),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          size: 22,
          color: CeltasColors.textSubtle,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(CeltasRadii.control),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 64,
          height: 64,
          color: CeltasColors.surface,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: CeltasColors.orange,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 64,
          height: 64,
          color: CeltasColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant,
            size: 22,
            color: CeltasColors.textSubtle,
          ),
        ),
      ),
    );
  }
}

/// Stepper compacto del carrito (mockup: radio 10, padding 5×12, gap 12).
class _CartStepper extends ConsumerWidget {
  const _CartStepper({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    return Container(
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        border: Border.all(color: CeltasColors.border),
        borderRadius: BorderRadius.circular(CeltasRadii.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: ValueKey('cart-minus-${item.menuItemId}'),
            onTap: () => notifier.decrement(item.menuItemId),
            child: const SvgStrokeIcon(
              path: 'M5 12h14',
              size: 12,
              color: CeltasColors.cream,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${item.quantity}',
            key: ValueKey('cart-qty-${item.menuItemId}'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            key: ValueKey('cart-plus-${item.menuItemId}'),
            onTap: () => notifier.increment(item.menuItemId),
            child: const SvgStrokeIcon(
              path: 'M12 5v14M5 12h14',
              size: 12,
              color: CeltasColors.orange,
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  const _ItemDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: CeltasColors.divider);
  }
}

// ─── Sección de cupón ───────────────────────────────────────────────────────

class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.controller,
    required this.validating,
    required this.error,
    required this.appliedCoupon,
    required this.onApply,
    required this.onRemoveCoupon,
  });

  final TextEditingController controller;
  final bool validating;
  final String? error;
  final ValidatedCoupon? appliedCoupon;
  final VoidCallback onApply;
  final VoidCallback onRemoveCoupon;

  @override
  Widget build(BuildContext context) {
    // Cupón ya aplicado: se muestra el código con opción de quitarlo.
    if (appliedCoupon case final ValidatedCoupon coupon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: CeltasColors.surface,
          border: Border.all(color: CeltasColors.gold),
          borderRadius: BorderRadius.circular(CeltasRadii.input),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Cupón ${coupon.code} aplicado',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.gold,
                    ),
              ),
            ),
            GestureDetector(
              key: const ValueKey('cart-coupon-remove'),
              onTap: onRemoveCoupon,
              child: Text(
                'QUITAR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.redLight,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CUPÓN DE DESCUENTO',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: CeltasColors.textLabel,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('cart-coupon-input'),
                controller: controller,
                enabled: !validating,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: CeltasColors.cream,
                    ),
                decoration: InputDecoration(
                  hintText: 'Ingresá tu código',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  errorText: error,
                  errorMaxLines: 2,
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            const SizedBox(width: 10),
            // Botón "Aplicar" del mockup: fondo #221C15, borde dorado.
            GestureDetector(
              key: const ValueKey('cart-coupon-apply'),
              onTap: validating ? null : onApply,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: CeltasColors.buttonSurface,
                  border: Border.all(color: CeltasColors.gold),
                  borderRadius: BorderRadius.circular(CeltasRadii.input),
                ),
                alignment: Alignment.center,
                child: validating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CeltasColors.gold,
                        ),
                      )
                    : Text(
                        'Aplicar',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CeltasColors.gold,
                            ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Totales y estado vacío ─────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.style,
  });

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CeltasSpacing.page),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 40,
              color: CeltasColors.textSubtle,
            ),
            const SizedBox(height: 12),
            Text(
              'Tu carrito está vacío',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Agregá algo rico del menú para empezar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CeltasColors.textMuted,
                  ),
            ),
            const SizedBox(height: 16),
            CeltasButton(
              label: 'VER MENÚ',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}