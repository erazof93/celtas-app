import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson(toJson()) preserva título, cuerpo, fecha y payload', () {
    final item = NotificationHistoryItem(
      title: 'Pedido confirmado',
      body: 'Tu pedido #A1B2 fue confirmado',
      receivedAt: DateTime.utc(2026, 8, 12, 14, 32),
      data: const {'orderId': 'order-1', 'status': 'confirmado'},
    );

    final roundTripped = NotificationHistoryItem.fromJson(item.toJson());

    expect(roundTripped, item);
    expect(roundTripped.receivedAt, item.receivedAt);
    expect(roundTripped.data, {'orderId': 'order-1', 'status': 'confirmado'});
  });

  test(
    'fromJson() sobre un JSON persistido ANTES de que existiera el campo '
    '`read` (sin esa key) no explota y cae en `false` por defecto — '
    '@tester, punto 3 del encargo de auditoría',
    () {
      // Forma exacta de lo que había en `shared_preferences` antes de este
      // cambio: sin la key `read` en absoluto (no `null`, AUSENTE).
      final legacyJson = <String, dynamic>{
        'title': 'Pedido confirmado',
        'body': 'Tu pedido #A1B2 fue confirmado',
        'receivedAt': DateTime.utc(2026, 8, 12, 14, 32).toIso8601String(),
        'data': {'orderId': 'order-1', 'status': 'confirmado'},
      };

      final item = NotificationHistoryItem.fromJson(legacyJson);

      expect(item.read, isFalse);
      expect(item.title, 'Pedido confirmado');
    },
  );
}
