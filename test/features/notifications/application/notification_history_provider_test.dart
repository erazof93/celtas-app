import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/notifications/data/notification_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  NotificationHistoryItem itemAt(int i) => NotificationHistoryItem(
        title: 'Notificación $i',
        body: 'Cuerpo $i',
        receivedAt: DateTime.utc(2026).add(Duration(minutes: i)),
        data: {'orderId': 'order-$i'},
      );

  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('build() carga el historial ya persistido en shared_preferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    // Precarga vía el repositorio real (mismo mecanismo que usaría una
    // sesión previa de la app).
    await NotificationHistoryRepository().save([itemAt(0)]);

    final container = createContainer();
    final items = await container.read(notificationHistoryProvider.future);

    expect(items, [itemAt(0)]);
  });

  test('add() agrega al principio de la lista (más reciente primero) y '
      'persiste', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    await container.read(notificationHistoryProvider.future);

    await container
        .read(notificationHistoryProvider.notifier)
        .add(itemAt(0));
    await container
        .read(notificationHistoryProvider.notifier)
        .add(itemAt(1));

    final state = container.read(notificationHistoryProvider).requireValue;
    expect(state, [itemAt(1), itemAt(0)]);

    // Persistido de verdad, no solo en memoria: un container nuevo lee lo
    // mismo desde `shared_preferences`.
    final freshContainer = createContainer();
    final reloaded =
        await freshContainer.read(notificationHistoryProvider.future);
    expect(reloaded, [itemAt(1), itemAt(0)]);
  });

  test('add() llamado antes de que build() termine no pierde el ítem nuevo '
      '(evita la condición de carrera del arranque desde terminada)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();

    // Sin `await` al `.future` primero — simula a `NotificationService`
    // llamando `add()` apenas se lee el provider por primera vez.
    final addFuture =
        container.read(notificationHistoryProvider.notifier).add(itemAt(0));
    await addFuture;

    final state = container.read(notificationHistoryProvider).requireValue;
    expect(state, [itemAt(0)]);
  });

  test(
      'dos add() concurrentes (sin await entre medio) no se pisan — ambos '
      'ítems sobreviven (hallazgo real de @tester: dos pushes casi '
      'simultáneos perdían uno)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    await container.read(notificationHistoryProvider.future);

    final notifier = container.read(notificationHistoryProvider.notifier);
    // Sin `await` entre las dos llamadas: ambas arrancan antes de que
    // cualquiera termine de mutar `state`.
    final first = notifier.add(itemAt(0));
    final second = notifier.add(itemAt(1));
    await Future.wait([first, second]);

    final state = container.read(notificationHistoryProvider).requireValue;
    expect(state, hasLength(2));
    expect(state, containsAll([itemAt(0), itemAt(1)]));

    // También persistido correctamente, no solo en memoria.
    final freshContainer = createContainer();
    final reloaded =
        await freshContainer.read(notificationHistoryProvider.future);
    expect(reloaded, hasLength(2));
  });

  test('add() recorta la lista en memoria al mismo tope que lo persistido '
      '(NotificationHistoryRepository.maxItems)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    final notifier = container.read(notificationHistoryProvider.notifier);
    await container.read(notificationHistoryProvider.future);

    for (var i = 0; i < NotificationHistoryRepository.maxItems + 5; i++) {
      await notifier.add(itemAt(i));
    }

    final state = container.read(notificationHistoryProvider).requireValue;
    expect(state, hasLength(NotificationHistoryRepository.maxItems));
    // El más reciente agregado (último `i`) sigue primero.
    expect(
      state.first,
      itemAt(NotificationHistoryRepository.maxItems + 4),
    );
  });
}
