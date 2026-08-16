import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/presentation/cart_screen.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/coupons/data/coupon_repository.dart';
import 'package:celtas_mobile/features/coupons/data/models/coupon_status.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
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

  final activeCoupon = UserCoupon(
    id: 'uc-1',
    code: 'VIKINGO10',
    discountType: CouponDiscountType.percentage,
    discountValue: 10,
    status: CouponStatus.active,
    expiresAt: DateTime.now().add(const Duration(days: 10)),
  );
  final activeCouponWithHighMin = UserCoupon(
    id: 'uc-2',
    code: 'GRANDE50',
    discountType: CouponDiscountType.fixedAmount,
    discountValue: 15,
    status: CouponStatus.active,
    expiresAt: DateTime.now().add(const Duration(days: 10)),
    minPurchaseAmount: 50,
  );
  final usedCoupon = UserCoupon(
    id: 'uc-3',
    code: 'YAUSADO',
    discountType: CouponDiscountType.percentage,
    discountValue: 20,
    status: CouponStatus.used,
    expiresAt: DateTime.now().add(const Duration(days: 10)),
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

    testWidgets(
        'aplicar cupón válido → muestra descuento y total, enviando el '
        'subtotal actual del carrito', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('VIKINGO10', subtotal: 31))
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
      // El subtotal (31, un double) se manda tal cual, no como string — el
      // DTO del backend rechaza con 400 si no es numérico.
      verify(
        () => repository.validateCoupon('VIKINGO10', subtotal: 31),
      ).called(1);
    });

    testWidgets('cupón inválido → mensaje real del backend', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('NOPE', subtotal: 15.5)).thenThrow(
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

    testWidgets(
        'cupón que no alcanza el pedido mínimo → mensaje real del backend, '
        'no se aplica descuento', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('MINIMO50', subtotal: 15.5))
          .thenThrow(
        const ApiException(
          'Este cupón requiere un pedido mínimo de S/50.00',
          statusCode: 400,
        ),
      );

      await pumpCart(
        tester,
        couponRepository: repository,
        items: [burger],
      );

      await tester.enterText(
        find.byKey(const ValueKey('cart-coupon-input')),
        'MINIMO50',
      );
      await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
      await tester.pumpAndSettle();

      expect(
        find.text('Este cupón requiere un pedido mínimo de S/50.00'),
        findsOneWidget,
      );
      expect(find.text('Cupón MINIMO50 aplicado'), findsNothing);
      // El total sigue sin descuento: línea + subtotal + total (3 widgets).
      expect(find.text('S/ 15.50'), findsNWidgets(3));
    });

    testWidgets(
        'el carrito cambia MIENTRAS se espera la respuesta del backend '
        '(cold start): si el subtotal ya no alcanza el mínimo al resolver, '
        'no aplica el cupón y avisa', (tester) async {
      const withMin = ValidatedCoupon(
        valid: true,
        id: 'c-7',
        code: 'GRANDE50',
        discountType: CouponDiscountType.fixedAmount,
        discountValue: 15,
        description: 'S/15.00 de descuento',
        minPurchaseAmount: 50,
      );
      final completer = Completer<ValidatedCoupon>();
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('GRANDE50', subtotal: 62))
          .thenAnswer((_) => completer.future);

      final container = await pumpCart(
        tester,
        couponRepository: repository,
        items: [burger],
        quantities: {'i-1': 4}, // subtotal 62, alcanza el mínimo al pedir
      );

      await tester.enterText(
        find.byKey(const ValueKey('cart-coupon-input')),
        'GRANDE50',
      );
      await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
      await tester.pump(); // dispara el request, todavía sin resolver

      // El stepper de cantidad NO se bloquea durante la espera de red — el
      // usuario decrementa mientras el backend (cold start) sigue pensando.
      await tester.tap(find.byKey(const ValueKey('cart-minus-i-1')));
      await tester.pump();
      expect(container.read(cartProvider).subtotal, 46.5); // ya no alcanza

      // Recién ahora "responde" el backend con el cupón que sí era válido
      // en el momento en que se pidió.
      completer.complete(withMin);
      await tester.pumpAndSettle();

      expect(find.text('Cupón GRANDE50 aplicado'), findsNothing);
      expect(container.read(cartProvider).coupon, isNull);
      expect(
        find.text('Este cupón requiere un pedido mínimo de S/50.00'),
        findsOneWidget,
      );
    });

    testWidgets('quitar cupón restaura el total sin descuento',
        (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('VIKINGO10', subtotal: 15.5))
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

    testWidgets(
        'decrementar hasta bajar del mínimo del cupón lo quita solo y '
        'avisa con un SnackBar', (tester) async {
      const withMin = ValidatedCoupon(
        valid: true,
        id: 'c-4',
        code: 'GRANDE50',
        discountType: CouponDiscountType.fixedAmount,
        discountValue: 15,
        description: 'S/15.00 de descuento',
        minPurchaseAmount: 50,
      );
      final container = await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger],
        quantities: {'i-1': 4}, // subtotal 62, alcanza el mínimo de 50
      );
      container.read(cartProvider.notifier).applyCoupon(withMin);
      await tester.pumpAndSettle();

      expect(find.text('Cupón GRANDE50 aplicado'), findsOneWidget);

      // 62 → 46.5 tras decrementar: ya no alcanza el mínimo.
      await tester.tap(find.byKey(const ValueKey('cart-minus-i-1')));
      await tester.pump(); // el SnackBar anima con el primer frame
      await tester.pumpAndSettle();

      expect(find.text('Cupón GRANDE50 aplicado'), findsNothing);
      expect(
        find.text(
          'El cupón GRANDE50 se quitó: el pedido ya no alcanza el mínimo '
          'de S/ 50.00',
        ),
        findsOneWidget,
      );
    });
  });

  group('ver mis cupones (bottom sheet)', () {
    testWidgets('cupón ya aplicado → no muestra el link del selector',
        (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.validateCoupon('VIKINGO10', subtotal: 15.5))
          .thenAnswer((_) async => percentageCoupon);

      await pumpCart(tester, couponRepository: repository, items: [burger]);
      await tester.enterText(
        find.byKey(const ValueKey('cart-coupon-input')),
        'VIKINGO10',
      );
      await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
      await tester.pumpAndSettle();

      expect(find.text('Cupón VIKINGO10 aplicado'), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-coupon-picker')), findsNothing);
    });

    testWidgets(
        'abre el sheet y lista solo cupones activos (usados/expirados '
        'quedan afuera)', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.getMyCoupons())
          .thenAnswer((_) async => [activeCoupon, usedCoupon]);

      await pumpCart(tester, couponRepository: repository, items: [burger]);
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();

      expect(find.text('Mis cupones'), findsOneWidget);
      expect(find.byKey(const ValueKey('coupon-picker-uc-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('coupon-picker-uc-3')), findsNothing);
    });

    testWidgets(
        'cupón activo que no alcanza el mínimo → se muestra pero no es '
        'tocable, con el monto exacto que falta', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.getMyCoupons())
          .thenAnswer((_) async => [activeCouponWithHighMin]);

      await pumpCart(tester, couponRepository: repository, items: [burger]);
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();

      // Subtotal 15.50, mínimo 50 → faltan 34.50.
      expect(
        find.text('Te faltan S/34.50 para usar este cupón'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('coupon-picker-uc-2')));
      await tester.pumpAndSettle();

      // El sheet no se cerró (no era tocable) y el cupón no se aplicó.
      expect(find.text('Mis cupones'), findsOneWidget);
      expect(find.text('Cupón GRANDE50 aplicado'), findsNothing);
    });

    testWidgets(
        'elegir un cupón elegible cierra el sheet y lo aplica reusando el '
        'flujo real de validación', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.getMyCoupons())
          .thenAnswer((_) async => [activeCoupon]);
      when(() => repository.validateCoupon('VIKINGO10', subtotal: 15.5))
          .thenAnswer((_) async => percentageCoupon);

      await pumpCart(tester, couponRepository: repository, items: [burger]);
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('coupon-picker-uc-1')));
      await tester.pumpAndSettle();

      expect(find.text('Mis cupones'), findsNothing); // sheet cerrado
      expect(find.text('Cupón VIKINGO10 aplicado'), findsOneWidget);
      verify(() => repository.validateCoupon('VIKINGO10', subtotal: 15.5))
          .called(1);
    });

    testWidgets('sin cupones activos → estado vacío', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.getMyCoupons())
          .thenAnswer((_) async => [usedCoupon]);

      await pumpCart(tester, couponRepository: repository, items: [burger]);
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();

      expect(
        find.text('No tenés cupones activos para aplicar'),
        findsOneWidget,
      );
    });

    testWidgets('error del backend → mensaje real y REINTENTAR',
        (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.getMyCoupons()).thenThrow(
        const ApiException('No se pudo conectar con el servidor.'),
      );

      await pumpCart(tester, couponRepository: repository, items: [burger]);
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo conectar con el servidor.'),
        findsOneWidget,
      );
      expect(find.text('REINTENTAR'), findsOneWidget);
    });

    testWidgets(
        'subtotal EXACTAMENTE igual al mínimo → elegible (no "menor que")',
        (tester) async {
      // burger.price == 15.5 y el carrito tiene 1 unidad → subtotal 15.5.
      final exactMinCoupon = UserCoupon(
        id: 'uc-4',
        code: 'JUSTO15',
        discountType: CouponDiscountType.percentage,
        discountValue: 5,
        status: CouponStatus.active,
        expiresAt: DateTime.now().add(const Duration(days: 10)),
        minPurchaseAmount: 15.5,
      );
      final repository = MockCouponRepository();
      when(() => repository.getMyCoupons())
          .thenAnswer((_) async => [exactMinCoupon]);
      when(() => repository.validateCoupon('JUSTO15', subtotal: 15.5))
          .thenAnswer(
        (_) async => const ValidatedCoupon(
          valid: true,
          id: 'c-4',
          code: 'JUSTO15',
          discountType: CouponDiscountType.percentage,
          discountValue: 5,
          description: '5% de descuento',
        ),
      );

      await pumpCart(tester, couponRepository: repository, items: [burger]);
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();

      // No debe mostrarse el aviso de "te faltan" — el cupón es tocable.
      expect(find.textContaining('Te faltan'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('coupon-picker-uc-4')));
      await tester.pumpAndSettle();

      expect(find.text('Mis cupones'), findsNothing); // sheet cerrado
      expect(find.text('Cupón JUSTO15 aplicado'), findsOneWidget);
      verify(() => repository.validateCoupon('JUSTO15', subtotal: 15.5))
          .called(1);
    });

    testWidgets(
        'cerrar el sheet sin elegir nada y reabrirlo → sigue funcionando '
        '(no deja el picker en un estado roto)', (tester) async {
      final repository = MockCouponRepository();
      when(() => repository.getMyCoupons())
          .thenAnswer((_) async => [activeCoupon]);

      await pumpCart(tester, couponRepository: repository, items: [burger]);

      // Primera apertura: se cierra con el gesto de swipe-down / back, sin
      // tocar ningún cupón.
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Mis cupones'), findsOneWidget);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Mis cupones'), findsNothing);
      // No se aplicó ningún cupón ni quedó ningún residuo de error.
      expect(find.text('Cupón VIKINGO10 aplicado'), findsNothing);
      expect(find.byKey(const ValueKey('cart-coupon-picker')), findsOneWidget);

      // Reapertura: el picker vuelve a listar el mismo cupón con normalidad.
      await tester.tap(find.byKey(const ValueKey('cart-coupon-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Mis cupones'), findsOneWidget);
      expect(find.byKey(const ValueKey('coupon-picker-uc-1')), findsOneWidget);
    });
  });

  group('vaciar carrito', () {
    testWidgets('carrito vacío → sin ícono de vaciar', (tester) async {
      await pumpCart(tester, couponRepository: MockCouponRepository());

      expect(find.byKey(const ValueKey('cart-clear')), findsNothing);
    });

    testWidgets('con ítems → ícono visible, pide confirmación antes de '
        'vaciar', (tester) async {
      await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger],
      );

      expect(find.byKey(const ValueKey('cart-clear')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cart-clear')));
      await tester.pumpAndSettle();

      expect(find.text('¿Vaciar el carrito?'), findsOneWidget);
      expect(find.text('CANCELAR'), findsOneWidget);
      expect(find.text('VACIAR'), findsOneWidget);
      // Todavía no se vació — el diálogo solo pregunta.
      expect(find.text('Berserker Burger'), findsOneWidget);
    });

    testWidgets('CANCELAR en el diálogo no toca el carrito', (tester) async {
      final container = await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger, wings],
      );

      await tester.tap(find.byKey(const ValueKey('cart-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(container.read(cartProvider).items, hasLength(2));
      expect(find.text('Berserker Burger'), findsOneWidget);
    });

    testWidgets(
        'VACIAR confirma → limpia todos los ítems Y el cupón aplicado en '
        'un solo paso', (tester) async {
      final container = await pumpCart(
        tester,
        couponRepository: MockCouponRepository(),
        items: [burger, wings],
      );
      container.read(cartProvider.notifier).applyCoupon(percentageCoupon);
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).coupon, isNotNull);

      await tester.tap(find.byKey(const ValueKey('cart-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VACIAR'));
      await tester.pumpAndSettle();

      final state = container.read(cartProvider);
      expect(state.items, isEmpty);
      expect(state.coupon, isNull);
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      // El ícono desaparece junto con los ítems.
      expect(find.byKey(const ValueKey('cart-clear')), findsNothing);
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

  group('salsas/cremas elegidas', () {
    testWidgets(
      'ítem con salsas seleccionadas → muestra "cremas: ..." debajo del '
      'nombre y arriba del precio',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            couponRepositoryProvider.overrideWithValue(
              MockCouponRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(cartProvider.notifier).addItem(
          burger,
          selectedSauces: const [
            SauceOption(id: 's-1', name: 'Mayonesa'),
            SauceOption(id: 's-2', name: 'Mostaza'),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('cremas: Mayonesa, Mostaza'), findsOneWidget);
      },
    );

    testWidgets(
      'ítem sin salsas seleccionadas → no muestra la línea de "cremas"',
      (tester) async {
        await pumpCart(
          tester,
          couponRepository: MockCouponRepository(),
          items: [burger],
        );

        expect(find.textContaining('cremas:'), findsNothing);
      },
    );
  });
}