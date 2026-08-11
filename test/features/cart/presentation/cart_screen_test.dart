import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/presentation/cart_screen.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/coupons/data/coupon_repository.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockCouponRepository extends Mock implements CouponRepository {}

void main() {
  const burger = PublicMenuItem(
    id: 'i-1',
    name: 'Berserker Burger',
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

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  /// Router mínimo: /cart y rutas de destino para push/go.
  GoRouter router() => GoRouter(
        initialLocation: '/cart',
        routes: [
          GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
          GoRoute(
            path: '/checkout',
            builder: (_, _) => const Scaffold(body: Text('CHECKOUT')),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('HOME')),
          ),
        ],
      );

  Future<ProviderContainer> pumpCart(
    WidgetTester tester, {
    required MockCouponRepository couponRepository,
    List<PublicMenuItem> items = const [],
    Map<String, int> quantities = const {},
  }) async {
    final container = ProviderContainer(
      overrides: [
        couponRepositoryProvider.overrideWithValue(couponRepository),
      ],
    );
    addTearDown(container.dispose);

    final cart = container.read(cartProvider.notifier);
    for (final item in items) {
      cart.addItem(item, quantity: quantities[item.id] ?? 1);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('estado del carrito', () {
    testWidgets('vacío → mensaje y botón a ver el menú', (tester) async {
      await pumpCart(tester, couponRepository: MockCouponRepository());

      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.text('VER MENÚ'), findsOneWidget);
      // Sin cupón ni totales con items vacíos.
      expect(find.text('CUPÓN DE DESCUENTO'), findsNothing);
    });

    testWidgets('lista items con nombre, precio unitario y subtotal por ítem',
        (tester) async {
      await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger, wings],
        quantities: {'i-1': 1, 'i-2': 2},
      );

      expect(find.text('Berserker Burger'), findsOneWidget);
      expect(find.text('S/ 15.50 c/u'), findsOneWidget);
      expect(find.text('S/ 15.50'), findsWidgets); // subtotal del ítem
      expect(find.text("Odin's Wings x8"), findsOneWidget);
      expect(find.text('S/ 7.20 c/u'), findsOneWidget);
      expect(find.text('S/ 14.40'), findsOneWidget); // 7.2 × 2
    });

    testWidgets('subtotal y total general correctos', (tester) async {
      await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger, wings],
        quantities: {'i-1': 2, 'i-2': 1},
      );

      // 15.5×2 + 7.2 = 38.2
      expect(find.text('S/ 38.20'), findsNWidgets(2)); // subtotal y total
      expect(find.text('CONTINUAR'), findsOneWidget);
    });

    testWidgets('stepper +/− edita cantidades y actualiza totales',
        (tester) async {
      await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger],
        quantities: {'i-1': 1},
      );

      // 1 ítem × 1 → "S/ 15.50" en línea, subtotal y total (3 widgets).
      expect(find.text('S/ 15.50'), findsNWidgets(3));

      await tester.tap(find.byKey(const ValueKey('cart-plus-i-1')));
      await tester.pumpAndSettle();
      expect(find.text('S/ 31.00'), findsNWidgets(3));

      await tester.tap(find.byKey(const ValueKey('cart-plus-i-1')));
      await tester.pumpAndSettle();
      expect(find.text('S/ 46.50'), findsNWidgets(3));

      await tester.tap(find.byKey(const ValueKey('cart-minus-i-1')));
      await tester.pumpAndSettle();
      expect(find.text('S/ 31.00'), findsNWidgets(3));
    });

    testWidgets('decrementar hasta 0 elimina el ítem del carrito',
        (tester) async {
      await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger, wings],
        quantities: {'i-1': 1, 'i-2': 1},
      );

      await tester.tap(find.byKey(const ValueKey('cart-minus-i-1')));
      await tester.pumpAndSettle();

      expect(find.text('Berserker Burger'), findsNothing);
      expect(find.text("Odin's Wings x8"), findsOneWidget);
    });
  });

  group('cupón', () {
    testWidgets('código vacío → mensaje de error local', (tester) async {
      await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger],
      );

      await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
      await tester.pumpAndSettle();

      expect(find.text('Ingresá un código de cupón'), findsOneWidget);
    });

    testWidgets('aplicar cupón válido → muestra descuento y total',
        (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('VIKINGO10'))
          .thenAnswer((_) async => percentageCoupon);

      await pumpCart(
        tester,
        couponRepository: repository,
        items: [burger],
        quantities: {'i-1': 2}, // subtotal 31
      );

      await tester.enterText(
        find.byKey(const ValueKey('cart-coupon-input')),
        'VIKINGO10',
      );
      await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
      await tester.pumpAndSettle();

      // Descuento 10% de 31 = 3.10; total 27.90.
      expect(find.text('Cupón VIKINGO10 aplicado'), findsOneWidget);
      expect(find.text('Cupón VIKINGO10'), findsOneWidget);
      expect(find.text('-S/ 3.10'), findsOneWidget);
      expect(find.text('S/ 27.90'), findsOneWidget);
      verify(() => repository.validateCoupon('VIKINGO10')).called(1);
    });

    testWidgets('cupón inválido → mensaje real del backend', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('NOPE')).thenThrow(
        const ApiException('El cupón no existe', statusCode: 400),
      );

      await pumpCart(
        tester,
        couponRepository: repository,
        items: [burger],
      );

      await tester.enterText(
        find.byKey(const ValueKey('cart-coupon-input')),
        'NOPE',
      );
      await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
      await tester.pumpAndSettle();

      expect(find.text('El cupón no existe'), findsOneWidget);
      // El cupón NO queda aplicado: línea + subtotal + total (3 widgets).
      expect(find.text('Cupón NOPE aplicado'), findsNothing);
      expect(find.text('S/ 15.50'), findsNWidgets(3));
    });

    testWidgets('quitar cupón restaura el total sin descuento',
        (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('VIKINGO10'))
          .thenAnswer((_) async => percentageCoupon);

      final container = await pumpCart(
        tester,
        couponRepository: repository,
        items: [burger],
      );
      container.read(cartProvider.notifier).applyCoupon(percentageCoupon);
      await tester.pumpAndSettle();

      expect(find.text('Cupón VIKINGO10 aplicado'), findsOneWidget);
      // 15.5 − 10% = 13.95 de total; línea y subtotal siguen en 15.50.
      expect(find.text('S/ 13.95'), findsOneWidget);
      expect(find.text('S/ 15.50'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('cart-coupon-remove')));
      await tester.pumpAndSettle();

      expect(find.text('Cupón VIKINGO10 aplicado'), findsNothing);
      expect(find.text('S/ 15.50'), findsNWidgets(3));
    });
  });

  testWidgets('CONTINUAR navega al checkout', (tester) async {
    await pumpCart(
      tester,
      couponRepository: MockCouponRepository(),
      items: [burger],
    );

    await tester.tap(find.byKey(const ValueKey('cart-continue')));
    await tester.pumpAndSettle();

    expect(find.text('CHECKOUT'), findsOneWidget);
  });
}