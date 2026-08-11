import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/data/address_repository.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/checkout/application/checkout_providers.dart';
import 'package:celtas_mobile/features/checkout/data/models/order_result.dart';
import 'package:celtas_mobile/features/checkout/data/order_repository.dart';
import 'package:celtas_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/orders/data/order_history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockAddressRepository extends Mock implements AddressRepository {}

class MockOrderRepository extends Mock implements OrderRepository {}

class MockOrderHistoryRepository extends Mock
    implements OrderHistoryRepository {}

/// Fake del canal de plataforma de `url_launcher` — sin esto, `launchUrl`
/// lanza `MissingPluginException` en widget tests (no hay un dispositivo real
/// detrás del MethodChannel).
///
/// Solo implementa `launchUrl`: el checkout NO usa `canLaunchUrl` como gate
/// (verificado en dispositivo real que devuelve `false` para `wa.me` aunque
/// WhatsApp esté instalado — ver `_openWhatsapp` en `checkout_screen.dart`).
class FakeUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  bool launchResult = true;
  Object? launchThrows;
  String? lastLaunchedUrl;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    final error = launchThrows;
    if (error != null) throw error;
    return launchResult;
  }
}

void main() {
  const burger = PublicMenuItem(id: 'i-1', name: 'Berserker Burger', price: 15.5);

  const home = Address(
    id: 'addr-1',
    alias: 'Casa',
    fullAddress: 'Av. Los Álamos 123',
    district: 'San Juan de Miraflores',
    isDefault: true,
  );
  const work = Address(
    id: 'addr-2',
    alias: 'Trabajo',
    fullAddress: 'Av. Callao 850',
    district: 'Surco',
  );

  late FakeUrlLauncherPlatform fakeUrlLauncher;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
    registerFallbackValue(<CartItem>[]);
  });

  setUp(() {
    fakeUrlLauncher = FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  GoRouter router() => GoRouter(
        initialLocation: '/checkout',
        routes: [
          GoRoute(
            path: '/checkout',
            builder: (_, _) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('HOME')),
          ),
        ],
      );

  Future<ProviderContainer> pumpCheckout(
    WidgetTester tester, {
    required MockAddressRepository addressRepository,
    required MockOrderRepository orderRepository,
    MockOrderHistoryRepository? orderHistoryRepository,
    List<PublicMenuItem> items = const [],
    ValidatedCoupon? coupon,
  }) async {
    final historyRepo = orderHistoryRepository ?? MockOrderHistoryRepository();
    if (orderHistoryRepository == null) {
      when(() => historyRepo.getMyOrders()).thenAnswer((_) async => []);
    }
    final container = ProviderContainer(
      overrides: [
        addressRepositoryProvider.overrideWithValue(addressRepository),
        orderRepositoryProvider.overrideWithValue(orderRepository),
        orderHistoryRepositoryProvider.overrideWithValue(historyRepo),
      ],
    );
    addTearDown(container.dispose);

    final cart = container.read(cartProvider.notifier);
    for (final item in items) {
      cart.addItem(item);
    }
    if (coupon != null) cart.applyCoupon(coupon);

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

  group('selector de dirección', () {
    testWidgets('sin direcciones guardadas → muestra el formulario inline',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => []);

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: MockOrderRepository(),
        items: [burger],
      );

      expect(find.text('Nueva dirección'), findsOneWidget);
      expect(find.text('+ Agregar nueva dirección'), findsNothing);
      // Sin direcciones existentes no hay nada que cancelar.
      expect(find.text('CANCELAR'), findsNothing);
    });

    testWidgets('con direcciones guardadas → selecciona la principal primero',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home, work]);

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: MockOrderRepository(),
        items: [burger],
      );

      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
      expect(find.text('+ Agregar nueva dirección'), findsOneWidget);
      expect(find.text('Nueva dirección'), findsNothing);
    });

    testWidgets('agregar nueva dirección → POST y queda seleccionada',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);
      const created = Address(
        id: 'addr-new',
        alias: 'Depto',
        fullAddress: 'Jr. Nueva 456',
        district: 'Surco',
      );
      when(() => addressRepo.createAddress(
            alias: 'Depto',
            fullAddress: 'Jr. Nueva 456',
            district: 'Surco',
          )).thenAnswer((_) async => created);

      final orderRepo = MockOrderRepository();
      when(() => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          )).thenAnswer(
        (_) async => const OrderResult(
          id: 'order-1',
          total: 15.5,
          whatsappUrl: 'https://wa.me/51999999999?text=hola',
        ),
      );

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
      );

      await tester.tap(find.byKey(const ValueKey('checkout-add-address-toggle')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('checkout-address-alias')),
        'Depto',
      );
      await tester.enterText(
        find.byKey(const ValueKey('checkout-address-full')),
        'Jr. Nueva 456',
      );
      await tester.enterText(
        find.byKey(const ValueKey('checkout-address-district')),
        'Surco',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('checkout-address-save')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-address-save')));
      await tester.pumpAndSettle();

      verify(() => addressRepo.createAddress(
            alias: 'Depto',
            fullAddress: 'Jr. Nueva 456',
            district: 'Surco',
          )).called(1);
      expect(find.text('Nueva dirección'), findsNothing);
      expect(find.text('Depto'), findsOneWidget);

      // La dirección recién creada queda seleccionada y se usa al confirmar.
      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      verify(() => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: 'addr-new',
            couponCode: any(named: 'couponCode'),
          )).called(1);
    });

    testWidgets('error al cargar direcciones → mensaje y REINTENTAR',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenThrow(const ApiException('No se pudo conectar'));

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: MockOrderRepository(),
        items: [burger],
      );

      expect(find.text('No se pudo conectar'), findsOneWidget);
      expect(find.text('REINTENTAR'), findsOneWidget);
    });
  });

  group('resumen del pedido', () {
    testWidgets('items, subtotal, cupón y total según el carrito',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: MockOrderRepository(),
        items: [burger],
        coupon: const ValidatedCoupon(
          valid: true,
          id: 'c-1',
          code: 'VIKINGO10',
          discountType: CouponDiscountType.percentage,
          discountValue: 10,
          description: '10% off',
        ),
      );

      expect(find.text('1x Berserker Burger'), findsOneWidget);
      expect(find.text('Cupón VIKINGO10'), findsOneWidget);
      expect(find.text('-S/ 1.55'), findsOneWidget);
      expect(find.text('S/ 13.95'), findsOneWidget); // total con descuento
    });
  });

  group('confirmar pedido', () {
    testWidgets(
        'payload real: items + addressId + couponCode, limpia el carrito y abre WhatsApp',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();
      when(() => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          )).thenAnswer(
        (_) async => const OrderResult(
          id: 'order-42',
          total: 15.5,
          whatsappUrl: 'https://wa.me/51999999999?text=Pedido%20%2342',
        ),
      );

      final container = await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
      );

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      final captured = verify(() => orderRepo.createOrder(
            items: captureAny(named: 'items'),
            addressId: 'addr-1',
          )).captured;
      final items = captured.single as List<CartItem>;
      expect(items, hasLength(1));
      expect(items.first.menuItemId, 'i-1');
      expect(items.first.quantity, 1);

      expect(fakeUrlLauncher.lastLaunchedUrl,
          'https://wa.me/51999999999?text=Pedido%20%2342');
      expect(container.read(cartProvider).items, isEmpty);
      expect(find.text('HOME'), findsOneWidget); // navegó tras confirmar
    });

    testWidgets('producto no disponible → mensaje real del backend, no navega',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();
      when(() => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          )).thenThrow(
        const ApiException(
          'El producto "Berserker Burger" no está disponible',
          statusCode: 400,
        ),
      );

      final container = await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
      );

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text('El producto "Berserker Burger" no está disponible'),
        findsOneWidget,
      );
      // El pedido no se creó: el carrito se conserva.
      expect(container.read(cartProvider).items, isNotEmpty);
      expect(find.text('HOME'), findsNothing);
    });

    testWidgets(
        'WhatsApp no instalado → pedido ya registrado, mensaje claro y botón para reintentar',
        (tester) async {
      fakeUrlLauncher.launchResult = false;

      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();
      when(() => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          )).thenAnswer(
        (_) async => const OrderResult(
          id: 'order-99',
          total: 15.5,
          whatsappUrl: 'https://wa.me/51999999999?text=hola',
        ),
      );

      final container = await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
      );

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu pedido #order-99 se registró'),
          findsOneWidget);
      expect(find.text('ABRIR WHATSAPP'), findsOneWidget);
      // El pedido ya existe en el backend: el carrito local igual se limpia.
      expect(container.read(cartProvider).items, isEmpty);
      expect(find.text('HOME'), findsNothing);

      // Reintentar con WhatsApp ahora disponible navega a Home.
      fakeUrlLauncher.launchResult = true;
      await tester.tap(find.text('ABRIR WHATSAPP'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets(
        'launchUrl lanza PlatformException → mismo mensaje claro, sin crash',
        (tester) async {
      fakeUrlLauncher.launchThrows =
          PlatformException(code: 'ACTIVITY_NOT_FOUND');

      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();
      when(() => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          )).thenAnswer(
        (_) async => const OrderResult(
          id: 'order-77',
          total: 15.5,
          whatsappUrl: 'https://wa.me/51999999999?text=hola',
        ),
      );

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
      );

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu pedido #order-77 se registró'),
          findsOneWidget);
      expect(find.text('ABRIR WHATSAPP'), findsOneWidget);
    });

    testWidgets(
        'pedido confirmado → invalida el historial para que aparezca al volver a Pedidos',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();
      when(() => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          )).thenAnswer(
        (_) async => const OrderResult(
          id: 'order-nuevo',
          total: 15.5,
          whatsappUrl: 'https://wa.me/51999999999?text=hola',
        ),
      );

      final historyRepo = MockOrderHistoryRepository();
      when(() => historyRepo.getMyOrders()).thenAnswer((_) async => []);

      final container = await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        orderHistoryRepository: historyRepo,
        items: [burger],
      );

      // Se lee una vez antes de confirmar (ej. si el usuario ya visitó el
      // tab Pedidos), simulando que el provider tiene un valor cacheado.
      await container.read(orderListProvider.future);
      verify(() => historyRepo.getMyOrders()).called(1);

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      // Tras confirmar, el provider fue invalidado: leerlo de nuevo dispara
      // un nuevo `GET /orders/me` en vez de devolver el valor cacheado.
      await container.read(orderListProvider.future);
      verify(() => historyRepo.getMyOrders()).called(1);
    });

    testWidgets('carrito vacío → botón de confirmar deshabilitado',
        (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses())
          .thenAnswer((_) async => [home]);

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: MockOrderRepository(),
      );

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pump();
      // Sin onPressed no dispara nada: sigue en /checkout.
      expect(find.text('HOME'), findsNothing);
    });
  });
}
