import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const burger = PublicMenuItem(
    id: 'i-1',
    name: 'Berserker Burger',
    description: 'Doble carne, cheddar, bacon',
    price: 15.5,
  );
  const wings = PublicMenuItem(
    id: 'i-2',
    name: "Odin's Wings x8",
    price: 7.2,
  );

  const percentageCoupon = ValidatedCoupon(
    valid: true,
    id: 'c-1',
    code: 'VIKINGO10',
    discountType: CouponDiscountType.percentage,
    discountValue: 10,
    description: '10% de descuento',
  );
  const fixedCoupon = ValidatedCoupon(
    valid: true,
    id: 'c-2',
    code: 'FIJO5',
    discountType: CouponDiscountType.fixedAmount,
    discountValue: 5,
    description: 'S/5.00 de descuento',
  );

  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('addItem', () {
    test('agrega un ítem nuevo con snapshot de precio y cantidad 1',
        () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);

      final state = container.read(cartProvider);
      expect(state.items, hasLength(1));
      final item = state.items.single;
      expect(item.menuItemId, 'i-1');
      expect(item.name, 'Berserker Burger');
      expect(item.unitPrice, 15.5);
      expect(item.quantity, 1);
    });

    test('agregar el mismo ítem suma cantidad en lugar de duplicar la fila',
        () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).addItem(burger);

      final state = container.read(cartProvider);
      expect(state.items, hasLength(1));
      expect(state.items.single.quantity, 2);
      expect(state.totalCount, 2);
    });

    test('agregar con quantity > 1 (detalle de producto)', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger, quantity: 3);

      expect(container.read(cartProvider).items.single.quantity, 3);
      expect(container.read(cartProvider).totalCount, 3);
    });

    test('quantity <= 0 no agrega nada', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger, quantity: 0);

      expect(container.read(cartProvider).items, isEmpty);
    });

    test('ítems distintos conviven en filas separadas', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).addItem(wings);

      final state = container.read(cartProvider);
      expect(state.items, hasLength(2));
      expect(state.totalCount, 2);
    });
  });

  group('increment / decrement', () {
    test('increment suma 1 a la cantidad del ítem', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).increment('i-1');

      expect(container.read(cartProvider).items.single.quantity, 2);
    });

    test('decrement resta 1 y con cantidad 1 el ítem desaparece', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).decrement('i-1');

      expect(container.read(cartProvider).items, isEmpty);
    });

    test('decrement no baja de 0 ni resucita ítems inexistentes', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).increment('i-1');
      container.read(cartProvider.notifier).decrement('i-1');
      container.read(cartProvider.notifier).decrement('i-1');

      // 2 - 1 - 1 = 0 → se elimina.
      expect(container.read(cartProvider).items, isEmpty);

      container.read(cartProvider.notifier).decrement('i-999');
      expect(container.read(cartProvider).items, isEmpty);
    });
  });

  group('removeItem / clear', () {
    test('removeItem elimina solo el ítem indicado', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).addItem(wings);
      container.read(cartProvider.notifier).removeItem('i-1');

      final state = container.read(cartProvider);
      expect(state.items, hasLength(1));
      expect(state.items.single.menuItemId, 'i-2');
    });

    test('clear vacía el carrito por completo', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).addItem(wings);
      container.read(cartProvider.notifier).clear();

      expect(container.read(cartProvider).items, isEmpty);
    });
  });

  group('totales', () {
    test('subtotal = suma de precio × cantidad por ítem', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger, quantity: 2);
      container.read(cartProvider.notifier).addItem(wings, quantity: 3);

      // 15.5×2 + 7.2×3 = 31 + 21.6 = 52.6
      expect(container.read(cartProvider).subtotal, 52.6);
      expect(container.read(cartProvider).totalCount, 5);
    });
  });

  group('cupón', () {
    test('applyCoupon guarda el cupón y total = subtotal − descuento',
        () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger, quantity: 2);
      container.read(cartProvider.notifier).applyCoupon(percentageCoupon);

      final state = container.read(cartProvider);
      expect(state.coupon?.code, 'VIKINGO10');
      // 10% de 31 = 3.1 → total 27.9
      expect(state.discount, closeTo(3.1, 0.001));
      expect(state.total, closeTo(27.9, 0.001));
    });

    test('cupón de monto fijo resta el valor al subtotal', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(wings, quantity: 3);
      container.read(cartProvider.notifier).applyCoupon(fixedCoupon);

      final state = container.read(cartProvider);
      // Subtotal 21.6 − 5 = 16.6
      expect(state.discount, 5);
      expect(state.total, closeTo(16.6, 0.001));
    });

    test('descuento fijo mayor al subtotal → total nunca baja de 0', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(wings);
      const bigFixed = ValidatedCoupon(
        valid: true,
        id: 'c-3',
        code: 'GRANDE',
        discountType: CouponDiscountType.fixedAmount,
        discountValue: 100,
        description: 'S/100.00 de descuento',
      );
      container.read(cartProvider.notifier).applyCoupon(bigFixed);

      final state = container.read(cartProvider);
      expect(state.discount, 7.2); // clamp a subtotal
      expect(state.total, 0);
    });

    test('removeCoupon quita el descuento', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).applyCoupon(percentageCoupon);
      container.read(cartProvider.notifier).removeCoupon();

      final state = container.read(cartProvider);
      expect(state.coupon, isNull);
      expect(state.discount, 0);
      expect(state.total, 15.5);
    });

    test('vaciar el carrito limpia el cupón aplicado', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).applyCoupon(percentageCoupon);
      container.read(cartProvider.notifier).decrement('i-1'); // único ítem → se elimina

      final state = container.read(cartProvider);
      expect(state.items, isEmpty);
      expect(state.coupon, isNull);
    });

    test('un ítem nuevo no invalida el cupón ya aplicado', () {
      final container = createContainer();
      container.read(cartProvider.notifier).addItem(burger);
      container.read(cartProvider.notifier).applyCoupon(percentageCoupon);
      container.read(cartProvider.notifier).addItem(wings);

      final state = container.read(cartProvider);
      expect(state.coupon?.code, 'VIKINGO10');
      // 10% de (15.5+7.2) = 2.27
      expect(state.discount, closeTo(2.27, 0.001));
    });
  });
}