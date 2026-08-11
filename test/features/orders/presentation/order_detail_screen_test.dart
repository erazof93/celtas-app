import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:celtas_mobile/features/orders/data/models/order_item.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:celtas_mobile/features/orders/data/order_history_repository.dart';
import 'package:celtas_mobile/features/orders/presentation/order_detail_screen.dart';
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
  const orderId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  final order = Order(
    id: orderId,
    status: OrderStatus.enCamino,
    addressSnapshot: '{"alias":"Casa","fullAddress":"Av. Los Álamos 123",'
        '"reference":"Portón azul","district":"San Juan de Miraflores"}',
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
    createdAt: DateTime(2026, 8, 6),
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  GoRouter router() => GoRouter(
        initialLocation: '/orders/$orderId',
        routes: [
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

  testWidgets(
      'muestra items del snapshot, addressSnapshot decodificado, estado y total',
      (tester) async {
    final repository = MockOrderHistoryRepository();
    when(() => repository.getOrder(orderId)).thenAnswer((_) async => order);

    await pumpScreen(tester, repository: repository);

    expect(find.text('Pedido #A1B2C3D4'), findsOneWidget);
    expect(find.text('2x Berserker Burger'), findsOneWidget);
    expect(find.text('S/ 28.50'), findsWidgets); // item + total
    expect(
      find.text('🏠 Casa — Av. Los Álamos 123'),
      findsOneWidget,
    );
    expect(find.text('Portón azul'), findsOneWidget);
    expect(find.text('EN CAMINO'), findsOneWidget);
    expect(find.text('Tu pedido está en camino'), findsOneWidget);
  });

  testWidgets('error al cargar → mensaje real y REINTENTAR', (tester) async {
    final repository = MockOrderHistoryRepository();
    when(() => repository.getOrder(orderId))
        .thenThrow(const ApiException('Pedido no encontrado', statusCode: 404));

    await pumpScreen(tester, repository: repository);

    expect(find.text('Pedido no encontrado'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });
}
