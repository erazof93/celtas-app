import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/notifications/data/notification_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  NotificationHistoryItem itemAt(int i) => NotificationHistoryItem(
    title: 'Notificación $i',
    body: 'Cuerpo $i',
    receivedAt: DateTime.utc(2026).add(Duration(minutes: i)),
    data: {'orderId': 'order-$i'},
  );

  test('load() sin datos previos devuelve lista vacía', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = NotificationHistoryRepository();

    expect(await repository.load(), isEmpty);
  });

  test('save() y load() hacen roundtrip preservando el orden', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = NotificationHistoryRepository();
    final items = [itemAt(2), itemAt(1), itemAt(0)];

    await repository.save(items);
    final loaded = await repository.load();

    expect(loaded, items);
  });

  test('save() recorta a los 30 ítems más recientes (los primeros de la '
      'lista, que ya vienen más-reciente-primero)', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = NotificationHistoryRepository();
    final items = [for (var i = 0; i < 40; i++) itemAt(i)];

    await repository.save(items);
    final loaded = await repository.load();

    expect(loaded, hasLength(30));
    expect(loaded, items.take(30));
  });
}
