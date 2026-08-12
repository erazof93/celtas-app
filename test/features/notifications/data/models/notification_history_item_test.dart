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
}
