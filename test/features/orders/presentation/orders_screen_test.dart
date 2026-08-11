import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:celtas_mobile/features/orders/data/models/order_item.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:celtas_mobile/features/orders/data/order_history_repository.dart';
import 'package:celtas_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:celtas_mobile/features/orders/presentation/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderHistoryRepository extends Mock
    implements OrderHistoryRepository {}

void main() {
  const addressSnapshot = '{"alias":"Casa","fullAddress":"Av. Los Álamos 123",'
      '"reference":null,"district":"San Juan de Miraflores"}';

  Order buildOrder({
    required String id,
    required OrderStatus status,
    DateTime? createdAt,
  }) =>
      Order(
        id: id,
        status: status,
        addressSnapshot: addressSnapshot,
        total: 28.5,
        whatsappUrl: 'https://wa.me/51999999999',
        items: const [
          OrderItem(
            id: 'item-1',
            menuItemId: 'menu-1',
            name: 'Berserker Burger',
            unitPrice: 14.25,
            quantity: 2,
            subtotal: 28.5,
          ),
        ],
        createdAt: createdAt ?? DateTime(2026, 8, 6),
      );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  GoRouter router() => GoRouter(
        initialLocation: '/orders',
        routes: [
          GoRoute(
            path: '/orders',
            builder: (_, _) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (_, state) => OrderDetailScreen(
              orderId: state.pathParameters['id']!,
            ),
          ),
        ],
      );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required MockOrderHistoryRepository repository,
  }) async {
    final container = ProviderContainer(
      overrides: [
        orderHistoryRepositoryProvider.overrideWithValue(repository),
      ],
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

  testWidgets('sin pedidos → estado vacío', (tester) async {
    final repository = MockOrderHistoryRepository();
    when(() => repository.getMyOrders()).thenAnswer((_) async => []);

    await pumpScreen(tester, repository: repository);

    expect(find.text('Todavía no hiciste ningún pedido'), findsOneWidget);
  });

  testWidgets(
      'con pedidos → id corto, fecha, cantidad de items, total y badge de estado',
      (tester) async {
    final repository = MockOrderHistoryRepository();
    when(() => repository.getMyOrders()).thenAnswer(
      (_) async => [
        buildOrder(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          status: OrderStatus.pendiente,
        ),
      ],
    );

    await pumpScreen(tester, repository: repository);

    expect(find.text('Pedido #A1B2C3D4'), findsOneWidget);
    expect(find.text('6 ago · 2 items'), findsOneWidget);
    expect(find.text('S/ 28.50'), findsOneWidget);
    expect(find.text('PENDIENTE'), findsOneWidget);
  });

  testWidgets('los 5 estados muestran badges con etiquetas distintas',
      (tester) async {
    // Superficie más alta que el default de test: las 5 tarjetas deben caber
    // sin scroll para que `find.text` las encuentre (ListView.separated es
    // perezoso, solo construye lo visible).
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockOrderHistoryRepository();
    when(() => repository.getMyOrders()).thenAnswer(
      (_) async => [
        buildOrder(
          id: '11111111-e5f6-7890-abcd-ef1234567890',
          status: OrderStatus.pendiente,
        ),
        buildOrder(
          id: '22222222-e5f6-7890-abcd-ef1234567890',
          status: OrderStatus.confirmado,
        ),
        buildOrder(
          id: '33333333-e5f6-7890-abcd-ef1234567890',
          status: OrderStatus.enCamino,
        ),
        buildOrder(
          id: '44444444-e5f6-7890-abcd-ef1234567890',
          status: OrderStatus.entregado,
        ),
        buildOrder(
          id: '55555555-e5f6-7890-abcd-ef1234567890',
          status: OrderStatus.cancelado,
        ),
      ],
    );

    await pumpScreen(tester, repository: repository);

    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('CONFIRMADO'), findsOneWidget);
    expect(find.text('EN CAMINO'), findsOneWidget);
    expect(find.text('ENTREGADO'), findsOneWidget);
    expect(find.text('CANCELADO'), findsOneWidget);
  });

  testWidgets('error al cargar → mensaje real y REINTENTAR', (tester) async {
    final repository = MockOrderHistoryRepository();
    when(() => repository.getMyOrders())
        .thenThrow(const ApiException('No se pudo conectar'));

    await pumpScreen(tester, repository: repository);

    expect(find.text('No se pudo conectar'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('tocar una tarjeta navega al detalle del pedido', (tester) async {
    final repository = MockOrderHistoryRepository();
    when(() => repository.getMyOrders()).thenAnswer(
      (_) async => [
        buildOrder(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          status: OrderStatus.pendiente,
        ),
      ],
    );
    when(() => repository.getOrder('a1b2c3d4-e5f6-7890-abcd-ef1234567890'))
        .thenAnswer(
      (_) async => buildOrder(
        id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        status: OrderStatus.pendiente,
      ),
    );

    await pumpScreen(tester, repository: repository);

    await tester.tap(find.byKey(
      const ValueKey('order-card-a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pedido #A1B2C3D4'), findsOneWidget);
    expect(find.text('2x Berserker Burger'), findsOneWidget);
  });

  testWidgets('pull-to-refresh vuelve a pedir la lista', (tester) async {
    var callCount = 0;
    final repository = MockOrderHistoryRepository();
    when(() => repository.getMyOrders()).thenAnswer((_) async {
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
