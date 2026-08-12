import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/coupons/data/coupon_repository.dart';
import 'package:celtas_mobile/features/coupons/data/models/coupon_status.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/features/coupons/presentation/coupons_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockCouponRepository extends Mock implements CouponRepository {}

void main() {
  final active = UserCoupon(
    id: 'c-1',
    code: 'VIKINGO10',
    discountType: CouponDiscountType.percentage,
    discountValue: 10,
    status: CouponStatus.active,
    expiresAt: DateTime(2026, 8, 31),
  );
  final used = UserCoupon(
    id: 'c-2',
    code: 'FUEGO3000',
    discountType: CouponDiscountType.fixedAmount,
    discountValue: 3000,
    status: CouponStatus.used,
    expiresAt: DateTime(2026, 8, 20),
    usedAt: DateTime(2026, 8, 5),
  );
  final expired = UserCoupon(
    id: 'c-3',
    code: 'ODIN15',
    discountType: CouponDiscountType.percentage,
    discountValue: 15,
    status: CouponStatus.expired,
    expiresAt: DateTime(2026, 8),
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  GoRouter router() => GoRouter(
        initialLocation: '/coupons',
        routes: [
          GoRoute(
            path: '/coupons',
            builder: (_, _) => const CouponsScreen(),
          ),
        ],
      );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required MockCouponRepository repository,
  }) async {
    final container = ProviderContainer(
      overrides: [couponRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

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

  testWidgets('sin cupones → estado vacío', (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => []);

    await pumpScreen(tester, repository: repository);

    expect(find.text('Todavía no tenés cupones'), findsOneWidget);
  });

  testWidgets(
      'cupón activo → código, descuento porcentual y fecha de vencimiento, '
      'sin etiqueta de estado', (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => [active]);

    await pumpScreen(tester, repository: repository);

    expect(find.text('10% OFF'), findsOneWidget);
    expect(find.text('Código: VIKINGO10'), findsOneWidget);
    expect(find.text('Válido hasta 31 ago 2026'), findsOneWidget);
    expect(find.text('USADO'), findsNothing);
    expect(find.text('EXPIRADO'), findsNothing);
  });

  testWidgets(
      'cupón sin minPurchaseAmount (null) → no muestra nada de pedido '
      'mínimo en la tarjeta', (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => [active]);

    await pumpScreen(tester, repository: repository);

    expect(find.textContaining('Pedido mínimo'), findsNothing);
  });

  testWidgets(
      'cupón con minPurchaseAmount 0 → se trata igual que sin mínimo, no '
      'muestra nada raro en la tarjeta', (tester) async {
    final zeroMin = UserCoupon(
      id: 'c-5',
      code: 'SINMINIMO',
      discountType: CouponDiscountType.percentage,
      discountValue: 10,
      status: CouponStatus.active,
      expiresAt: DateTime(2026, 8, 31),
      minPurchaseAmount: 0,
    );
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => [zeroMin]);

    await pumpScreen(tester, repository: repository);

    expect(find.textContaining('Pedido mínimo'), findsNothing);
    expect(find.text('Válido hasta 31 ago 2026'), findsOneWidget);
  });

  testWidgets(
      'cupón con minPurchaseAmount > 0 → muestra "Pedido mínimo: S/X.XX" '
      'junto con la fecha, mismo patrón del mockup original', (tester) async {
    final withMin = UserCoupon(
      id: 'c-6',
      code: 'GRANDE50',
      discountType: CouponDiscountType.fixedAmount,
      discountValue: 15,
      status: CouponStatus.active,
      expiresAt: DateTime(2026, 8, 20),
      minPurchaseAmount: 50,
    );
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => [withMin]);

    await pumpScreen(tester, repository: repository);

    expect(
      find.text('Pedido mínimo: S/ 50.00 · Válido hasta 20 ago 2026'),
      findsOneWidget,
    );
  });

  testWidgets(
      'cupón de monto fijo → descuento en soles, no porcentaje',
      (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => [used]);

    await pumpScreen(tester, repository: repository);

    expect(find.text('S/ 3000.00 OFF'), findsOneWidget);
  });

  testWidgets('cupón usado → etiqueta USADO y fecha de uso, no de vencimiento',
      (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => [used]);

    await pumpScreen(tester, repository: repository);

    expect(find.text('USADO'), findsOneWidget);
    expect(find.text('Usado el 5 ago 2026'), findsOneWidget);
  });

  testWidgets(
      'cupón expirado (status real) → etiqueta EXPIRADO y fecha de '
      'vencimiento', (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async => [expired]);

    await pumpScreen(tester, repository: repository);

    expect(find.text('EXPIRADO'), findsOneWidget);
    expect(find.text('Venció el 1 ago 2026'), findsOneWidget);
  });

  testWidgets(
      'cupón con status "active" pero expiresAt ya pasado → se muestra como '
      'EXPIRADO (el cron del backend puede tardar hasta 24h en actualizar '
      'el status real)', (tester) async {
    final staleActive = UserCoupon(
      id: 'c-4',
      code: 'VIEJO5',
      discountType: CouponDiscountType.percentage,
      discountValue: 5,
      status: CouponStatus.active, // el backend todavía no corrió el cron
      expiresAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons())
        .thenAnswer((_) async => [staleActive]);

    await pumpScreen(tester, repository: repository);

    expect(find.text('EXPIRADO'), findsOneWidget);
  });

  testWidgets('los 3 estados efectivos se distinguen entre sí en una lista',
      (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons())
        .thenAnswer((_) async => [active, used, expired]);

    await pumpScreen(tester, repository: repository);

    expect(find.text('10% OFF'), findsOneWidget);
    expect(find.text('USADO'), findsOneWidget);
    expect(find.text('EXPIRADO'), findsOneWidget);
  });

  testWidgets('error al cargar → mensaje real y REINTENTAR', (tester) async {
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons())
        .thenThrow(const ApiException('No se pudo conectar'));

    await pumpScreen(tester, repository: repository);

    expect(find.text('No se pudo conectar'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('pull-to-refresh vuelve a pedir la lista', (tester) async {
    var callCount = 0;
    final repository = MockCouponRepository();
    when(() => repository.getMyCoupons()).thenAnswer((_) async {
      callCount++;
      return [];
    });

    await pumpScreen(tester, repository: repository);
    expect(callCount, 1);

    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(callCount, 2);
  });
}
