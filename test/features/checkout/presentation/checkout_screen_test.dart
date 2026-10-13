import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/data/address_repository.dart';
import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/address_map_picker.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/principal_badge.dart';
import 'package:celtas_mobile/features/auth/application/auth_controller.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/checkout/application/checkout_providers.dart';
import 'package:celtas_mobile/features/checkout/data/models/delivery_estimate.dart';
import 'package:celtas_mobile/features/checkout/data/models/order_result.dart';
import 'package:celtas_mobile/features/checkout/data/order_repository.dart';
import 'package:celtas_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/orders/data/order_history_repository.dart';
import 'package:celtas_mobile/features/profile/application/profile_providers.dart';
import 'package:celtas_mobile/features/profile/data/profile_repository.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockAddressRepository extends Mock implements AddressRepository {}

DeliveryEstimate distanceEstimate(double fee, {bool far = false}) =>
    DeliveryEstimate(
      deliveryFee: fee,
      isFarOrder: far,
      distanceMeters: null,
      isCovered: true,
      deliveryMode: DeliveryMode.distance,
      zone: null,
    );

class MockOrderRepository extends Mock implements OrderRepository {
  MockOrderRepository() {
    when(
      () => estimateDeliveryFee(any()),
    ).thenAnswer((_) async => distanceEstimate(0));
  }
}

class MockOrderHistoryRepository extends Mock
    implements OrderHistoryRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

/// `AddressSelectionStorage` fija, sin tocar `SharedPreferences`.
class _FakeAddressSelectionStorage extends AddressSelectionStorage {
  _FakeAddressSelectionStorage(this._id);

  final String? _id;

  @override
  String? load() => _id;

  @override
  Future<void> save(String id) async {}

  @override
  Future<void> clear() async {}
}

/// Controller de auth "de mentira" para tests: se salta por completo el
/// `build()` real (que se registra como `ApiClient.instance.session` y
/// dispara `bootstrap()` — innecesario y potencialmente ruidoso en un widget
/// test) y arranca directo con el `AuthState` que le pasemos.
class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

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
  const burger = PublicMenuItem(
    id: 'i-1',
    name: 'Berserker Burger',
    price: 15.5,
  );

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

  User userWith({String? phone, UserProvider provider = UserProvider.local}) =>
      User(
        id: 'user-1',
        email: 'ragnar@email.com',
        fullName: 'Ragnar Andersen',
        provider: provider,
        phone: phone,
        totalSpent: 0,
        role: UserRole.cliente,
        createdAt: DateTime.utc(2026, 1, 15),
        updatedAt: DateTime.utc(2026, 1, 15),
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
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
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
    MockSettingsRepository? settingsRepository,
    MockProfileRepository? profileRepository,
    List<PublicMenuItem> items = const [],
    ValidatedCoupon? coupon,
    // Por default el usuario de prueba YA tiene teléfono guardado, para que
    // la mayoría de los tests de este archivo (que no se ocupan del modal de
    // teléfono) no lo vean aparecer sin pedirlo — mismo criterio que
    // `settingsRepository`/local abierto arriba. Pasar `null` para los tests
    // que sí ejercitan el gate.
    String? userPhone = '987654321',
    UserProvider userProvider = UserProvider.local,
    String? selectedAddressId,
    AuthState? initialSession,
  }) async {
    final historyRepo = orderHistoryRepository ?? MockOrderHistoryRepository();
    if (orderHistoryRepository == null) {
      when(() => historyRepo.getMyOrders()).thenAnswer((_) async => []);
    }
    final settingsRepo = settingsRepository ?? MockSettingsRepository();
    if (settingsRepository == null) {
      // Default: local abierto — la mayoría de los tests de este archivo no
      // se ocupan del aviso preventivo, así que no debe aparecer sin pedirlo.
      when(() => settingsRepo.getBusinessHours()).thenAnswer(
        (_) async =>
            const BusinessHours(open: true, message: null, nextChangeAt: null),
      );
    }
    final profileRepo = profileRepository ?? MockProfileRepository();
    if (profileRepository == null) {
      // `ProfileNotifier.build()` corre en cuanto algo lee
      // `profileProvider`/`.notifier` (ej. al abrir el modal de teléfono) —
      // stub por default para que ningún test que no se ocupa de esto tenga
      // que pensar en `GET /users/me`.
      when(() => profileRepo.getProfile()).thenAnswer(
        (_) async => userWith(phone: userPhone, provider: userProvider),
      );
    }
    final container = ProviderContainer(
      overrides: [
        addressRepositoryProvider.overrideWithValue(addressRepository),
        addressSelectionStorageProvider.overrideWithValue(
          _FakeAddressSelectionStorage(selectedAddressId),
        ),
        orderRepositoryProvider.overrideWithValue(orderRepository),
        orderHistoryRepositoryProvider.overrideWithValue(historyRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        profileRepositoryProvider.overrideWithValue(profileRepo),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            initialSession ??
                AuthState.authenticated(
                  user: userWith(phone: userPhone, provider: userProvider),
                  accessToken: 'test-token',
                ),
          ),
        ),
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
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  for (final session in [
    const AuthState.unknown(),
    const AuthState.error(),
    const AuthState.unauthenticated(),
  ]) {
    testWidgets('confirmar sin sesión ${session.status} no envía pedido', (
      tester,
    ) async {
      final addresses = MockAddressRepository();
      when(addresses.getAddresses).thenAnswer((_) async => [home]);
      final orders = MockOrderRepository();
      final container = await pumpCheckout(
        tester,
        addressRepository: addresses,
        orderRepository: orders,
        items: [burger],
        initialSession: session,
      );
      final button = tester.widget<CeltasButton>(
        find.byKey(const ValueKey('checkout-confirm')),
      );
      button.onPressed!();
      await tester.pumpAndSettle();
      verifyNever(
        () => orders.createOrder(
          items: any(named: 'items'),
          addressId: any(named: 'addressId'),
          couponCode: any(named: 'couponCode'),
        ),
      );
      expect(container.read(cartProvider).items, hasLength(1));
      expect(
        find.text('Restaura tu sesión antes de confirmar el pedido.'),
        findsOneWidget,
      );
    });
  }

  /// Simula "tocar el mapa": invoca directamente el callback de
  /// `AddressMapPicker` (mismo patrón que `address_location_picker_test.dart`
  /// / `addresses_screen_test.dart`) en vez de un drag real.
  Future<void> touchMap(WidgetTester tester, [LatLng? point]) async {
    final mapPicker = tester.widget<AddressMapPicker>(
      find.byType(AddressMapPicker),
    );
    mapPicker.onCenterChanged(point ?? const LatLng(-12.1633, -76.9718));
    await tester.pump();
  }

  group('delivery gate', () {
    const coveredZone = DeliveryEstimate(
      deliveryFee: 7,
      isFarOrder: false,
      distanceMeters: 1500,
      isCovered: true,
      deliveryMode: DeliveryMode.zones,
      zone: DeliveryZone(id: 'zone-1', name: 'Zona cercana'),
    );
    const uncovered = DeliveryEstimate(
      deliveryFee: 0,
      isFarOrder: false,
      distanceMeters: 1500,
      isCovered: false,
      deliveryMode: DeliveryMode.zones,
      zone: null,
    );
    final locatedHome = home.copyWith(latitude: -12, longitude: -77);

    CeltasButton confirm(WidgetTester tester) => tester.widget<CeltasButton>(
      find.byKey(const ValueKey('checkout-confirm')),
    );

    for (final estimate in [
      coveredZone,
      coveredZone.copyWith(deliveryFee: 0),
      coveredZone.copyWith(isFarOrder: true),
      distanceEstimate(4, far: true),
    ]) {
      testWidgets(
        'covered ${estimate.deliveryMode} fee ${estimate.deliveryFee} far ${estimate.isFarOrder}',
        (tester) async {
          final addresses = MockAddressRepository();
          when(
            () => addresses.getAddresses(),
          ).thenAnswer((_) async => [locatedHome]);
          final orders = MockOrderRepository();
          when(
            () => orders.estimateDeliveryFee('addr-1'),
          ).thenAnswer((_) async => estimate);
          await pumpCheckout(
            tester,
            addressRepository: addresses,
            orderRepository: orders,
            items: [burger],
          );
          expect(find.text('Envío'), findsOneWidget);
          expect(
            find.text('S/ ${estimate.deliveryFee.toStringAsFixed(2)}'),
            findsOneWidget,
          );
          expect(
            find.text('S/ ${(15.5 + estimate.deliveryFee).toStringAsFixed(2)}'),
            findsWidgets,
          );
          expect(confirm(tester).onPressed, isNotNull);
          expect(
            find.text('Zona de delivery: Zona cercana'),
            estimate.deliveryMode == DeliveryMode.zones
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.text('Tu dirección está más lejos de lo habitual.'),
            estimate.isFarOrder ? findsOneWidget : findsNothing,
          );
        },
      );
    }

    for (final missing in [false, true]) {
      testWidgets(
        'uncovered ${missing ? 'sin coordenadas' : 'fuera de zona'} bloquea sin tarifa cero',
        (tester) async {
          final addresses = MockAddressRepository();
          when(
            () => addresses.getAddresses(),
          ).thenAnswer((_) async => [missing ? home : locatedHome]);
          final orders = MockOrderRepository();
          when(
            () => orders.estimateDeliveryFee('addr-1'),
          ).thenAnswer((_) async => uncovered);
          await pumpCheckout(
            tester,
            addressRepository: addresses,
            orderRepository: orders,
            items: [burger],
          );
          expect(
            find.text(
              missing
                  ? 'Esta dirección necesita una ubicación en el mapa.'
                  : 'Fuera de cobertura',
            ),
            findsOneWidget,
          );
          expect(find.text('S/ 0.00'), findsNothing);
          expect(find.text('Envío'), findsNothing);
          expect(find.text('Total por calcular'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('delivery-change-address')),
            findsOneWidget,
          );
          expect(confirm(tester).onPressed, isNull);
        },
      );
    }

    testWidgets('loading bloquea y guard interno impide callback anterior', (
      tester,
    ) async {
      final addresses = MockAddressRepository();
      when(() => addresses.getAddresses()).thenAnswer((_) async => [home]);
      final orders = MockOrderRepository();
      final container = await pumpCheckout(
        tester,
        addressRepository: addresses,
        orderRepository: orders,
        items: [burger],
      );
      final oldCallback = confirm(tester).onPressed!;
      final pending = Completer<DeliveryEstimate>();
      when(
        () => orders.estimateDeliveryFee('addr-1'),
      ).thenAnswer((_) => pending.future);
      container.invalidate(deliveryFeeEstimateProvider('addr-1'));
      oldCallback();
      await tester.pump();
      expect(find.text('Calculando delivery...'), findsOneWidget);
      expect(find.text('Envío'), findsNothing);
      expect(find.text('Total por calcular'), findsOneWidget);
      expect(confirm(tester).onPressed, isNull);
      verifyNever(
        () => orders.createOrder(
          items: any(named: 'items'),
          addressId: any(named: 'addressId'),
          couponCode: any(named: 'couponCode'),
        ),
      );
      pending.complete(distanceEstimate(4));
      await tester.pumpAndSettle();
    });

    testWidgets('error técnico retry recupera sin asumir uncovered', (
      tester,
    ) async {
      final addresses = MockAddressRepository();
      when(() => addresses.getAddresses()).thenAnswer((_) async => [home]);
      final orders = MockOrderRepository();
      when(
        () => orders.estimateDeliveryFee('addr-1'),
      ).thenAnswer((_) async => throw const ApiException('red'));
      await pumpCheckout(
        tester,
        addressRepository: addresses,
        orderRepository: orders,
        items: [burger],
      );
      expect(find.text('No pudimos calcular el delivery.'), findsOneWidget);
      expect(find.text('Fuera de cobertura'), findsNothing);
      expect(confirm(tester).onPressed, isNull);
      when(
        () => orders.estimateDeliveryFee('addr-1'),
      ).thenAnswer((_) async => coveredZone);
      await tester.ensureVisible(find.byKey(const ValueKey('delivery-retry')));
      await tester.tap(find.byKey(const ValueKey('delivery-retry')));
      await tester.pumpAndSettle();
      expect(confirm(tester).onPressed, isNotNull);
      expect(find.text('S/ 7.00'), findsOneWidget);
    });

    testWidgets('A/B invertidos no reutilizan tarifa ni cobertura', (
      tester,
    ) async {
      final addresses = MockAddressRepository();
      when(
        () => addresses.getAddresses(),
      ).thenAnswer((_) async => [locatedHome, work]);
      final orders = MockOrderRepository();
      final a = Completer<DeliveryEstimate>();
      final b = Completer<DeliveryEstimate>();
      when(
        () => orders.estimateDeliveryFee('addr-1'),
      ).thenAnswer((_) => a.future);
      when(
        () => orders.estimateDeliveryFee('addr-2'),
      ).thenAnswer((_) => b.future);
      await pumpCheckout(
        tester,
        addressRepository: addresses,
        orderRepository: orders,
        items: [burger],
      );
      await tester.tap(find.byKey(const ValueKey('checkout-address-addr-2')));
      await tester.pump();
      b.complete(coveredZone);
      await tester.pumpAndSettle();
      a.complete(uncovered);
      await tester.pumpAndSettle();
      expect(find.text('Fuera de cobertura'), findsNothing);
      expect(find.text('S/ 7.00'), findsOneWidget);
      expect(confirm(tester).onPressed, isNotNull);
    });

    testWidgets('400 conserva carrito cupón y dirección, refresca estimate', (
      tester,
    ) async {
      final addresses = MockAddressRepository();
      when(
        () => addresses.getAddresses(),
      ).thenAnswer((_) async => [locatedHome]);
      final orders = MockOrderRepository();
      var calls = 0;
      when(
        () => orders.estimateDeliveryFee('addr-1'),
      ).thenAnswer((_) async => ++calls == 1 ? coveredZone : uncovered);
      when(
        () => orders.createOrder(
          items: any(named: 'items'),
          addressId: any(named: 'addressId'),
          couponCode: any(named: 'couponCode'),
        ),
      ).thenThrow(
        const ApiException(
          'La dirección no tiene cobertura de delivery',
          statusCode: 400,
        ),
      );
      const coupon = ValidatedCoupon(
        valid: true,
        id: 'coupon-1',
        code: 'TEST',
        discountType: CouponDiscountType.fixedAmount,
        discountValue: 1,
        description: 'Descuento',
      );
      final container = await pumpCheckout(
        tester,
        addressRepository: addresses,
        orderRepository: orders,
        items: [burger],
        coupon: coupon,
      );
      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text('La dirección no tiene cobertura de delivery'),
        findsOneWidget,
      );
      expect(find.text('Fuera de cobertura'), findsOneWidget);
      expect(container.read(cartProvider).items, isNotEmpty);
      expect(container.read(cartProvider).coupon, coupon);
      expect(
        find.byKey(const ValueKey('checkout-address-addr-1')),
        findsOneWidget,
      );
      expect(calls, 2);
    });

    for (final change in ['cart', 'estimate', 'address']) {
      testWidgets('post modal teléfono revalida $change', (tester) async {
        final addresses = MockAddressRepository();
        when(() => addresses.getAddresses()).thenAnswer((_) async => [home]);
        final orders = MockOrderRepository();
        final profile = MockProfileRepository();
        when(() => profile.getProfile()).thenAnswer((_) async => userWith());
        when(
          () => profile.updateProfile(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          ),
        ).thenAnswer((_) async => userWith(phone: '987654321'));
        final container = await pumpCheckout(
          tester,
          addressRepository: addresses,
          orderRepository: orders,
          profileRepository: profile,
          items: [burger],
          userPhone: null,
        );
        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pumpAndSettle();
        if (change == 'cart') {
          container
              .read(cartProvider.notifier)
              .increment(container.read(cartProvider).items.first.lineKey);
        }
        if (change == 'estimate') {
          when(
            () => orders.estimateDeliveryFee('addr-1'),
          ).thenAnswer((_) async => uncovered);
          container.invalidate(deliveryFeeEstimateProvider('addr-1'));
        }
        if (change == 'address') {
          when(() => addresses.getAddresses()).thenAnswer((_) async => [work]);
          container.invalidate(addressListProvider);
        }
        await tester.enterText(
          find.byKey(const ValueKey('checkout-phone-input')),
          '987654321',
        );
        await tester.tap(find.byKey(const ValueKey('checkout-phone-confirm')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('checkout-phone-confirm-final')),
        );
        await tester.pumpAndSettle();
        verifyNever(
          () => orders.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        );
        expect(
          find.text(
            'Tu dirección o pedido cambió. Revisa los datos y confirma nuevamente.',
          ),
          findsOneWidget,
        );
        expect(container.read(cartProvider).items, isNotEmpty);
      });
    }
  });

  group('selector de dirección', () {
    testWidgets('sin direcciones guardadas → muestra el formulario inline', (
      tester,
    ) async {
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

    testWidgets('con direcciones guardadas → selecciona la principal primero', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(
        () => addressRepo.getAddresses(),
      ).thenAnswer((_) async => [home, work]);

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

    testWidgets(
      'con una dirección seleccionada guardada → arranca en ESA, no en la '
      'principal',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(
          () => addressRepo.getAddresses(),
        ).thenAnswer((_) async => [home, work]); // home (addr-1) es isDefault

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.estimateDeliveryFee(any()),
        ).thenAnswer((_) async => distanceEstimate(5.0));

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: orderRepo,
          items: [burger],
          selectedAddressId: 'addr-2', // Trabajo
        );

        // El estimate se pide para la seleccionada (addr-2), no para la
        // principal (addr-1).
        verify(() => orderRepo.estimateDeliveryFee('addr-2')).called(1);
        verifyNever(() => orderRepo.estimateDeliveryFee('addr-1'));
      },
    );

    testWidgets('selección guardada que ya no existe → cae a la principal', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(
        () => addressRepo.getAddresses(),
      ).thenAnswer((_) async => [home, work]);

      final orderRepo = MockOrderRepository();
      when(
        () => orderRepo.estimateDeliveryFee(any()),
      ).thenAnswer((_) async => distanceEstimate(5.0));

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
        selectedAddressId: 'ya-no-existe',
      );

      verify(() => orderRepo.estimateDeliveryFee('addr-1')).called(1);
    });

    testWidgets(
      'selector de direcciones → badge PRINCIPAL solo en la dirección '
      'isDefault',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(
          () => addressRepo.getAddresses(),
        ).thenAnswer((_) async => [home, work]); // solo `home` es isDefault

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          items: [burger],
        );

        // Un único badge, dentro de la tarjeta de "Casa" (la principal).
        expect(find.text('PRINCIPAL'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('checkout-address-addr-1')),
            matching: find.byType(PrincipalBadge),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('checkout-address-addr-2')),
            matching: find.text('PRINCIPAL'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'selector de direcciones → sin ninguna isDefault, ningún badge',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [work]);

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          items: [burger],
        );

        expect(find.text('Trabajo'), findsOneWidget);
        expect(find.text('PRINCIPAL'), findsNothing);
      },
    );

    testWidgets('agregar nueva dirección → POST y queda seleccionada', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);
      const created = Address(
        id: 'addr-new',
        alias: 'Depto',
        fullAddress: 'Jr. Nueva 456',
        district: 'Surco',
        latitude: -12.1633,
        longitude: -76.9718,
      );
      when(
        () => addressRepo.createAddress(
          alias: 'Depto',
          fullAddress: 'Jr. Nueva 456',
          district: 'Surco',
          latitude: -12.1633,
          longitude: -76.9718,
        ),
      ).thenAnswer((_) async => created);

      final orderRepo = MockOrderRepository();
      when(
        () => orderRepo.createOrder(
          items: any(named: 'items'),
          addressId: any(named: 'addressId'),
          couponCode: any(named: 'couponCode'),
        ),
      ).thenAnswer(
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

      await tester.tap(
        find.byKey(const ValueKey('checkout-add-address-toggle')),
      );
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
      await touchMap(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('checkout-address-save')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('checkout-address-save')));
      await tester.pumpAndSettle();

      verify(
        () => addressRepo.createAddress(
          alias: 'Depto',
          fullAddress: 'Jr. Nueva 456',
          district: 'Surco',
          latitude: -12.1633,
          longitude: -76.9718,
        ),
      ).called(1);
      expect(find.text('Nueva dirección'), findsNothing);
      expect(find.text('Depto'), findsOneWidget);

      // La dirección recién creada queda seleccionada y se usa al confirmar.
      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      verify(
        () => orderRepo.createOrder(
          items: any(named: 'items'),
          addressId: 'addr-new',
          couponCode: any(named: 'couponCode'),
        ),
      ).called(1);
    });

    testWidgets(
      'agregar nueva dirección sin tocar el mapa → error claro, no llama '
      'al backend',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          items: [burger],
        );

        await tester.tap(
          find.byKey(const ValueKey('checkout-add-address-toggle')),
        );
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

        expect(
          find.text('Toca el mapa para marcar la ubicación de tu dirección'),
          findsOneWidget,
        );
        verifyNever(
          () => addressRepo.createAddress(
            alias: any(named: 'alias'),
            fullAddress: any(named: 'fullAddress'),
            reference: any(named: 'reference'),
            district: any(named: 'district'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          ),
        );
      },
    );

    testWidgets('error al cargar direcciones → mensaje y REINTENTAR', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(
        () => addressRepo.getAddresses(),
      ).thenThrow(const ApiException('No se pudo conectar'));

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
    testWidgets(
      '10.05 al 50% con envío 2 muestra descuento 5.03 y total 7.02',
      (tester) async {
        final addresses = MockAddressRepository();
        when(() => addresses.getAddresses()).thenAnswer((_) async => [home]);
        final orders = MockOrderRepository();
        when(
          () => orders.estimateDeliveryFee('addr-1'),
        ).thenAnswer((_) async => distanceEstimate(2));
        await pumpCheckout(
          tester,
          addressRepository: addresses,
          orderRepository: orders,
          items: [burger.copyWith(price: 10.05)],
          coupon: const ValidatedCoupon(
            valid: true,
            id: 'c-half',
            code: 'HALF',
            discountType: CouponDiscountType.percentage,
            discountValue: 50,
            description: '50%',
          ),
        );
        expect(find.text('S/ 10.05'), findsNWidgets(2));
        expect(find.text('-S/ 5.03'), findsOneWidget);
        expect(find.text('S/ 2.00'), findsOneWidget);
        expect(find.text('S/ 7.02'), findsOneWidget);
      },
    );

    testWidgets('items, subtotal, cupón y total según el carrito', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

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

  group('preview de envío (POST /orders/estimate-delivery-fee)', () {
    testWidgets('con dirección seleccionada → llama al estimate y suma la fila '
        '"Envío" entre el resumen y el total (nunca toca cart.total)', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();
      when(
        () => orderRepo.estimateDeliveryFee('addr-1'),
      ).thenAnswer((_) async => distanceEstimate(6.5));

      final container = await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
      );

      verify(() => orderRepo.estimateDeliveryFee('addr-1')).called(1);
      expect(find.text('Envío'), findsOneWidget);
      expect(find.text('S/ 6.50'), findsOneWidget);
      // Total mostrado = cart.total + deliveryFee; cart.total en sí no
      // cambia (lo sigue calculando el backend real en POST /orders, esto es
      // puramente de preview).
      expect(find.text('S/ 22.00'), findsOneWidget); // 15.50 + 6.50
      expect(container.read(cartProvider).total, 15.5);
    });

    testWidgets(
      'cambiar de dirección seleccionada → vuelve a pedir el estimate '
      'con el nuevo addressId',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(
          () => addressRepo.getAddresses(),
        ).thenAnswer((_) async => [home, work]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.estimateDeliveryFee('addr-1'),
        ).thenAnswer((_) async => distanceEstimate(5));
        when(
          () => orderRepo.estimateDeliveryFee('addr-2'),
        ).thenAnswer((_) async => distanceEstimate(12));

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: orderRepo,
          items: [burger],
        );

        verify(() => orderRepo.estimateDeliveryFee('addr-1')).called(1);
        expect(find.text('S/ 5.00'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('checkout-address-addr-2')));
        await tester.pumpAndSettle();

        verify(() => orderRepo.estimateDeliveryFee('addr-2')).called(1);
        expect(find.text('S/ 12.00'), findsOneWidget);
      },
    );

    testWidgets(
      'sin dirección seleccionada → no llama al estimate ni muestra la fila',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => []);

        final orderRepo = MockOrderRepository();

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: orderRepo,
          items: [burger],
        );

        verifyNever(() => orderRepo.estimateDeliveryFee(any()));
        expect(find.text('Envío'), findsNothing);
      },
    );

    testWidgets('el estimate falla (red/timeout) → sin tarifa, error visible '
        'y confirmación bloqueada', (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();
      when(
        () => orderRepo.estimateDeliveryFee('addr-1'),
      ).thenThrow(const ApiException('No se pudo conectar'));

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
      );

      expect(find.text('Envío'), findsNothing);
      expect(find.text('No se pudo conectar'), findsNothing);
      // El total mostrado cae de vuelta al de cart.total, sin envío (el
      // ítem, el subtotal y el total coinciden en "S/ 15.50" porque no hay
      // cupón ni envío — 3 apariciones esperadas, no una).
      expect(find.text('Total por calcular'), findsOneWidget);
      final button = tester.widget<CeltasButton>(
        find.byKey(const ValueKey('checkout-confirm')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('confirmar pedido', () {
    testWidgets(
      'payload real: items + addressId + couponCode, limpia el carrito y abre WhatsApp',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenAnswer(
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

        final captured = verify(
          () => orderRepo.createOrder(
            items: captureAny(named: 'items'),
            addressId: 'addr-1',
          ),
        ).captured;
        final items = captured.single as List<CartItem>;
        expect(items, hasLength(1));
        expect(items.first.menuItemId, 'i-1');
        expect(items.first.quantity, 1);

        expect(
          fakeUrlLauncher.lastLaunchedUrl,
          'https://wa.me/51999999999?text=Pedido%20%2342',
        );
        expect(container.read(cartProvider).items, isEmpty);
        expect(find.text('HOME'), findsOneWidget); // navegó tras confirmar
      },
    );

    testWidgets(
      'producto no disponible → mensaje real del backend, no navega',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenThrow(
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
      },
    );

    testWidgets(
      'WhatsApp no instalado → pedido ya registrado, mensaje claro y botón para reintentar',
      (tester) async {
        fakeUrlLauncher.launchResult = false;

        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenAnswer(
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

        expect(
          find.textContaining('Tu pedido #order-99 se registró'),
          findsOneWidget,
        );
        expect(find.text('ABRIR WHATSAPP'), findsOneWidget);
        // El pedido ya existe en el backend: el carrito local igual se limpia.
        expect(container.read(cartProvider).items, isEmpty);
        expect(find.text('HOME'), findsNothing);

        // Reintentar con WhatsApp ahora disponible navega a Home.
        fakeUrlLauncher.launchResult = true;
        await tester.tap(find.text('ABRIR WHATSAPP'));
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
      },
    );

    testWidgets(
      'launchUrl lanza PlatformException → mismo mensaje claro, sin crash',
      (tester) async {
        fakeUrlLauncher.launchThrows = PlatformException(
          code: 'ACTIVITY_NOT_FOUND',
        );

        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenAnswer(
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

        expect(
          find.textContaining('Tu pedido #order-77 se registró'),
          findsOneWidget,
        );
        expect(find.text('ABRIR WHATSAPP'), findsOneWidget);
      },
    );

    testWidgets(
      'pedido confirmado → invalida el historial para que aparezca al volver a Pedidos',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenAnswer(
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
      },
    );

    testWidgets('carrito vacío → botón de confirmar deshabilitado', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

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

  group('gate de teléfono obligatorio al confirmar (no en el registro)', () {
    testWidgets(
      'usuario sin teléfono → confirmar muestra el modal bloqueante, NO '
      'crea el pedido todavía',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: orderRepo,
          items: [burger],
          userPhone: null,
        );

        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('checkout-phone-required-dialog')),
          findsOneWidget,
        );
        expect(find.text('Falta tu teléfono'), findsOneWidget);
        verifyNever(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        );
      },
    );

    testWidgets(
      'teléfono vacío ("") cuenta como sin teléfono, igual que null',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          items: [burger],
          userPhone: '',
        );

        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('checkout-phone-required-dialog')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'formato inválido (no 9 dígitos empezando en 9) → error inline, no '
      'guarda ni confirma',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final profileRepo = MockProfileRepository();
        when(
          () => profileRepo.getProfile(),
        ).thenAnswer((_) async => userWith());

        final orderRepo = MockOrderRepository();

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: orderRepo,
          profileRepository: profileRepo,
          items: [burger],
          userPhone: null,
        );

        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('checkout-phone-input')),
          '123456789', // no empieza en 9
        );
        await tester.tap(find.byKey(const ValueKey('checkout-phone-confirm')));
        await tester.pump();

        expect(
          find.text('Ingresa un teléfono válido: 9 dígitos, empieza en 9'),
          findsOneWidget,
        );
        verifyNever(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          ),
        );
        verifyNever(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        );
      },
    );

    testWidgets(
      'teléfono válido → PATCH /users/me vía profileProvider y sigue con '
      'la creación normal del pedido',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final profileRepo = MockProfileRepository();
        when(
          () => profileRepo.getProfile(),
        ).thenAnswer((_) async => userWith());
        when(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: '987654321',
          ),
        ).thenAnswer((_) async => userWith(phone: '987654321'));

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenAnswer(
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
          profileRepository: profileRepo,
          items: [burger],
          userPhone: null,
        );

        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('checkout-phone-input')),
          '987654321',
        );
        // Primer "CONFIRMAR": solo valida el formato y pasa al paso de
        // revisión — todavía NO guarda nada.
        await tester.tap(find.byKey(const ValueKey('checkout-phone-confirm')));
        await tester.pumpAndSettle();
        verifyNever(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          ),
        );
        expect(
          find.text('¿Confirmas que tu número es 987 654 321?'),
          findsOneWidget,
        );

        // Recién "SÍ, CONFIRMAR" en el paso de revisión guarda de verdad.
        await tester.tap(
          find.byKey(const ValueKey('checkout-phone-confirm-final')),
        );
        await tester.pumpAndSettle();

        verify(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: '987654321',
          ),
        ).called(1);
        // El modal se cerró y el flujo normal de creación del pedido siguió.
        expect(
          find.byKey(const ValueKey('checkout-phone-required-dialog')),
          findsNothing,
        );
        verify(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: 'addr-1',
            couponCode: any(named: 'couponCode'),
          ),
        ).called(1);
        expect(find.text('HOME'), findsOneWidget);
      },
    );

    testWidgets(
      'paso de revisión: número válido → muestra la confirmación con el '
      'número formateado; EDITAR vuelve al campo con el valor conservado; '
      'SÍ, CONFIRMAR recién ahí llama a updateProfile (no antes)',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final profileRepo = MockProfileRepository();
        when(
          () => profileRepo.getProfile(),
        ).thenAnswer((_) async => userWith());
        when(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: '987654321',
          ),
        ).thenAnswer((_) async => userWith(phone: '987654321'));

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          profileRepository: profileRepo,
          items: [burger],
          userPhone: null,
        );

        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('checkout-phone-input')),
          '987654321',
        );
        await tester.tap(find.byKey(const ValueKey('checkout-phone-confirm')));
        await tester.pumpAndSettle();

        // Paso de revisión visible, con el número formateado, y NADA guardado
        // todavía.
        expect(find.text('Confirma tu teléfono'), findsOneWidget);
        expect(
          find.text('¿Confirmas que tu número es 987 654 321?'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('checkout-phone-input')),
          findsNothing,
        );
        verifyNever(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          ),
        );

        // "EDITAR" vuelve al campo, con el valor ya tipeado conservado (no se
        // limpia el controller entre pasos).
        await tester.tap(find.byKey(const ValueKey('checkout-phone-edit')));
        await tester.pumpAndSettle();
        expect(find.text('Falta tu teléfono'), findsOneWidget);
        final field = tester.widget<TextFormField>(
          find.descendant(
            of: find.byKey(const ValueKey('checkout-phone-input')),
            matching: find.byType(TextFormField),
          ),
        );
        expect(field.controller!.text, '987654321');
        verifyNever(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
          ),
        );

        // Vuelve a "CONFIRMAR" → mismo paso de revisión de nuevo → "SÍ,
        // CONFIRMAR" recién ahí guarda.
        await tester.tap(find.byKey(const ValueKey('checkout-phone-confirm')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('checkout-phone-confirm-final')),
        );
        await tester.pumpAndSettle();

        verify(
          () => profileRepo.updateProfile(
            fullName: any(named: 'fullName'),
            phone: '987654321',
          ),
        ).called(1);
      },
    );

    testWidgets('cancelar el modal → no crea el pedido, se queda en checkout', (
      tester,
    ) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

      final orderRepo = MockOrderRepository();

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        items: [burger],
        userPhone: null,
      );

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('checkout-phone-required-dialog')),
        findsNothing,
      );
      expect(find.text('HOME'), findsNothing);
      verifyNever(
        () => orderRepo.createOrder(
          items: any(named: 'items'),
          addressId: any(named: 'addressId'),
          couponCode: any(named: 'couponCode'),
        ),
      );
    });

    testWidgets('falla el guardado del teléfono → error real del backend en el '
        'modal, no crea el pedido', (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

      final profileRepo = MockProfileRepository();
      when(() => profileRepo.getProfile()).thenAnswer((_) async => userWith());
      when(
        () => profileRepo.updateProfile(
          fullName: any(named: 'fullName'),
          phone: '987654321',
        ),
      ).thenThrow(const ApiException('No se pudo conectar'));

      final orderRepo = MockOrderRepository();

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: orderRepo,
        profileRepository: profileRepo,
        items: [burger],
        userPhone: null,
      );

      await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('checkout-phone-input')),
        '987654321',
      );
      await tester.tap(find.byKey(const ValueKey('checkout-phone-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('checkout-phone-confirm-final')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se pudo conectar'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('checkout-phone-required-dialog')),
        findsOneWidget,
      );
      verifyNever(
        () => orderRepo.createOrder(
          items: any(named: 'items'),
          addressId: any(named: 'addressId'),
          couponCode: any(named: 'couponCode'),
        ),
      );
    });

    testWidgets(
      'aplica igual para cuentas de Google — sin distinguir por provider, '
      'solo mira si phone está vacío',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          items: [burger],
          userPhone: null,
          userProvider: UserProvider.google,
        );

        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('checkout-phone-required-dialog')),
          findsOneWidget,
        );
      },
    );
  });

  group('aviso de dirección faltante', () {
    testWidgets(
      'sin dirección seleccionada → aviso visible y botón deshabilitado; '
      'al agregar una dirección, el aviso desaparece y el botón se habilita',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => []);
        const created = Address(
          id: 'addr-new',
          alias: 'Depto',
          fullAddress: 'Jr. Nueva 456',
          district: 'Surco',
          latitude: -12.1633,
          longitude: -76.9718,
        );
        when(
          () => addressRepo.createAddress(
            alias: 'Depto',
            fullAddress: 'Jr. Nueva 456',
            district: 'Surco',
            latitude: -12.1633,
            longitude: -76.9718,
          ),
        ).thenAnswer((_) async => created);

        final orderRepo = MockOrderRepository();

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: orderRepo,
          items: [burger],
        );

        // Sin direcciones: el aviso está visible y el botón, deshabilitado.
        expect(
          find.byKey(const ValueKey('checkout-missing-address-notice')),
          findsOneWidget,
        );
        expect(
          find.text('Elige o agrega una dirección de entrega para continuar'),
          findsOneWidget,
        );
        var button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('checkout-confirm')),
        );
        expect(button.onPressed, isNull);

        // Tocar el botón deshabilitado no dispara ninguna llamada al backend.
        await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
        await tester.pump();
        verifyNever(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        );

        // Se completa y guarda el formulario de nueva dirección.
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
        await touchMap(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('checkout-address-save')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('checkout-address-save')));
        await tester.pumpAndSettle();

        // Con dirección seleccionada: el aviso desaparece y el botón se habilita.
        expect(
          find.byKey(const ValueKey('checkout-missing-address-notice')),
          findsNothing,
        );
        button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('checkout-confirm')),
        );
        expect(button.onPressed, isNotNull);
      },
    );
  });

  group('bloqueo por local cerrado (409 de POST /orders)', () {
    testWidgets(
      'confirmar con el local cerrado → diálogo bloqueante con el mensaje '
      'real del backend, carrito intacto, sigue en checkout tras cerrarlo',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenThrow(
          const ApiException(
            'El local está cerrado en este momento. Hoy atendemos de 11:00 a '
            '23:00',
            statusCode: 409,
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

        // Diálogo bloqueante, no el texto inline que usan otros errores (ej.
        // producto no disponible) — regresión: si esto vuelve a mostrarse como
        // el resto de errores genéricos (`_orderError`), el diálogo no aparece.
        expect(
          find.byKey(const ValueKey('checkout-closed-dialog')),
          findsOneWidget,
        );
        expect(find.text('Local cerrado'), findsOneWidget);
        expect(
          find.text(
            'El local está cerrado en este momento. Hoy atendemos de 11:00 a '
            '23:00',
          ),
          findsOneWidget,
        );
        // El pedido no se creó (409, antes de tocar la base): el carrito se
        // conserva intacto, sin navegar a ninguna pantalla de éxito.
        expect(container.read(cartProvider).items, isNotEmpty);
        expect(find.text('HOME'), findsNothing);

        // "ENTENDIDO" solo cierra el diálogo — el cliente se queda en el
        // checkout con su carrito, puede reintentar más tarde.
        await tester.tap(find.text('ENTENDIDO'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('checkout-closed-dialog')),
          findsNothing,
        );
        expect(find.text('HOME'), findsNothing);
        expect(find.byKey(const ValueKey('checkout-confirm')), findsOneWidget);
        expect(container.read(cartProvider).items, isNotEmpty);
      },
    );

    testWidgets(
      'cierre manual con motivo → el diálogo muestra ese mensaje tal cual',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final orderRepo = MockOrderRepository();
        when(
          () => orderRepo.createOrder(
            items: any(named: 'items'),
            addressId: any(named: 'addressId'),
            couponCode: any(named: 'couponCode'),
          ),
        ).thenThrow(
          const ApiException(
            'El local está cerrado temporalmente: Cerrado por mantenimiento',
            statusCode: 409,
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

        expect(
          find.text(
            'El local está cerrado temporalmente: Cerrado por mantenimiento',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('aviso preventivo de local cerrado (GET /settings/business-hours)', () {
    testWidgets(
      'open: false al entrar al checkout → aviso visible de inmediato, '
      'sin deshabilitar el botón de confirmar',
      (tester) async {
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final settingsRepo = MockSettingsRepository();
        when(() => settingsRepo.getBusinessHours()).thenAnswer(
          (_) async => const BusinessHours(
            open: false,
            message: 'Hoy no atendemos',
            nextChangeAt: null,
          ),
        );

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          settingsRepository: settingsRepo,
          items: [burger],
        );

        expect(
          find.byKey(const ValueKey('checkout-closed-notice')),
          findsOneWidget,
        );
        expect(find.text('Hoy no atendemos'), findsOneWidget);
        // Puramente informativo: el bloqueo real es el 409 al confirmar, no
        // este aviso — el botón sigue habilitado (hay dirección seleccionada).
        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('checkout-confirm')),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets('open: true → sin aviso', (tester) async {
      final addressRepo = MockAddressRepository();
      when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

      await pumpCheckout(
        tester,
        addressRepository: addressRepo,
        orderRepository: MockOrderRepository(),
        items: [burger],
      );

      expect(
        find.byKey(const ValueKey('checkout-closed-notice')),
        findsNothing,
      );
    });

    testWidgets(
      'GET /settings/business-hours falla (ej. backend dormido) → sin '
      'aviso, sin crash, checkout sigue usable',
      (tester) async {
        // `businessHoursProvider` es puramente informativo — si falla, el
        // checkout no debe bloquearse ni mostrar ningún error de esto: la
        // pantalla solo lee `.valueOrNull`, que es `null` en estado de error,
        // así que el `if (businessHoursAsync.valueOrNull?.open == false)` no
        // se cumple y simplemente no hay aviso. El 409 real de `POST /orders`
        // sigue siendo la única fuente de verdad del bloqueo.
        final addressRepo = MockAddressRepository();
        when(() => addressRepo.getAddresses()).thenAnswer((_) async => [home]);

        final settingsRepo = MockSettingsRepository();
        when(
          () => settingsRepo.getBusinessHours(),
        ).thenThrow(const ApiException('No se pudo conectar con el servidor'));

        await pumpCheckout(
          tester,
          addressRepository: addressRepo,
          orderRepository: MockOrderRepository(),
          settingsRepository: settingsRepo,
          items: [burger],
        );

        expect(
          find.byKey(const ValueKey('checkout-closed-notice')),
          findsNothing,
        );
        // No se filtra ningún mensaje de error de esto a la UI del checkout.
        expect(find.text('No se pudo conectar con el servidor'), findsNothing);
        // El resto de la pantalla sigue funcionando con normalidad.
        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('checkout-confirm')),
        );
        expect(button.onPressed, isNotNull);
      },
    );
  });
}
