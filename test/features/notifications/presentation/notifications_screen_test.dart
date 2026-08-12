import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final orderNotification = NotificationHistoryItem(
    title: 'Pedido confirmado',
    body: 'Tu pedido #A1B2 fue confirmado',
    receivedAt: DateTime.utc(2026, 8, 12, 14, 32),
    data: const {'orderId': 'order-1', 'status': 'confirmado'},
  );
  final couponNotification = NotificationHistoryItem(
    title: 'Tenés un cupón nuevo',
    body: 'Usa VIKINGO10 en tu próximo pedido',
    receivedAt: DateTime.utc(2026, 8, 11, 9, 5),
    data: const {'couponCode': 'VIKINGO10'},
  );

  Widget buildApp(List<NotificationHistoryItem> history) {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) => Scaffold(
            body: Text('Detalle de pedido ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/coupons',
          builder: (context, state) => const Scaffold(
            body: Text('Mis cupones'),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        notificationHistoryProvider.overrideWith(
          () => _FakeNotificationHistoryNotifier(history),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
  }

  testWidgets('sin notificaciones → estado vacío', (tester) async {
    await tester.pumpWidget(buildApp(const []));
    await tester.pumpAndSettle();

    expect(find.text('No tienes notificaciones todavía'), findsOneWidget);
  });

  testWidgets('error al cargar el historial → mensaje y REINTENTAR', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationHistoryProvider.overrideWith(
            () => _FailingNotificationHistoryNotifier(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo cargar tu historial de notificaciones'),
      findsOneWidget,
    );
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('con notificaciones → lista con título, cuerpo y fecha', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp([orderNotification, couponNotification]));
    await tester.pumpAndSettle();

    expect(find.text('Pedido confirmado'), findsOneWidget);
    expect(find.text('Tu pedido #A1B2 fue confirmado'), findsOneWidget);
    expect(find.text('12 ago · 14:32'), findsOneWidget);
    expect(find.text('Tenés un cupón nuevo'), findsOneWidget);
  });

  testWidgets('tocar una notificación de pedido → navega al detalle del '
      'pedido real (mismo target que la notificación en vivo)', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp([orderNotification]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedido confirmado'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de pedido order-1'), findsOneWidget);
  });

  testWidgets('tocar una notificación de cupón → navega a Mis cupones', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp([couponNotification]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tenés un cupón nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Mis cupones'), findsOneWidget);
  });
}

/// Fake sin persistencia real: la lista se fija en el `build()`, sin tocar
/// `shared_preferences` — la pantalla solo lee el provider, no lo muta.
class _FakeNotificationHistoryNotifier extends NotificationHistoryNotifier {
  _FakeNotificationHistoryNotifier(this._items);

  final List<NotificationHistoryItem> _items;

  @override
  Future<List<NotificationHistoryItem>> build() async => _items;
}

/// Fake que fuerza el estado de error de la pantalla.
class _FailingNotificationHistoryNotifier extends NotificationHistoryNotifier {
  @override
  Future<List<NotificationHistoryItem>> build() =>
      Future.error(Exception('shared_preferences no disponible'));
}
