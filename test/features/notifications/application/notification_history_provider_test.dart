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

  test(
    'build() carga el historial ya persistido en shared_preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      // Precarga vía el repositorio real (mismo mecanismo que usaría una
      // sesión previa de la app).
      await NotificationHistoryRepository().save([itemAt(0)]);

      final container = createContainer();
      final items = await container.read(notificationHistoryProvider.future);

      expect(items, [itemAt(0)]);
    },
  );

  test('add() agrega al principio de la lista (más reciente primero) y '
      'persiste', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    await container.read(notificationHistoryProvider.future);

    await container.read(notificationHistoryProvider.notifier).add(itemAt(0));
    await container.read(notificationHistoryProvider.notifier).add(itemAt(1));

    final state = container.read(notificationHistoryProvider).requireValue;
    expect(state, [itemAt(1), itemAt(0)]);

    // Persistido de verdad, no solo en memoria: un container nuevo lee lo
    // mismo desde `shared_preferences`.
    final freshContainer = createContainer();
    final reloaded = await freshContainer.read(
      notificationHistoryProvider.future,
    );
    expect(reloaded, [itemAt(1), itemAt(0)]);
  });

  test('add() llamado antes de que build() termine no pierde el ítem nuevo '
      '(evita la condición de carrera del arranque desde terminada)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();

    // Sin `await` al `.future` primero — simula a `NotificationService`
    // llamando `add()` apenas se lee el provider por primera vez.
    final addFuture = container
        .read(notificationHistoryProvider.notifier)
        .add(itemAt(0));
    await addFuture;

    final state = container.read(notificationHistoryProvider).requireValue;
    expect(state, [itemAt(0)]);
  });

  test('dos add() concurrentes (sin await entre medio) no se pisan — ambos '
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
    final reloaded = await freshContainer.read(
      notificationHistoryProvider.future,
    );
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
    expect(state.first, itemAt(NotificationHistoryRepository.maxItems + 4));
  });

  test('add() y markAllRead() concurrentes (sin await entre medio) comparten '
      '_mutationQueue: ninguna notificación se pierde, y el orden de '
      'ejecución respeta el orden de llamada (FIFO), no una carrera real '
      '— @tester, punto 4 del encargo de auditoría', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    final notifier = container.read(notificationHistoryProvider.notifier);
    await container.read(notificationHistoryProvider.future);
    await notifier.add(itemAt(0));
    await notifier.add(itemAt(1));

    // markAllRead() encolado ANTES que el add() del ítem 2, sin await entre
    // medio (mismo patrón que "push llega justo cuando se abre la pantalla
    // de Notificaciones y dispara `markAllRead()` en `initState`").
    final markRead = notifier.markAllRead();
    final addNew = notifier.add(itemAt(2));
    await Future.wait([markRead, addNew]);

    final state = container.read(notificationHistoryProvider).requireValue;
    // Ningún ítem se pierde: los 3 siguen presentes (comparación por
    // `orderId`, no por igualdad completa — `markAllRead()` cambia `read`
    // en los ítems 0 y 1, así que ya no son iguales a `itemAt(0)`/`itemAt(1)`
    // por valor).
    expect(state, hasLength(3));
    expect(
      state.map((i) => i.data['orderId']),
      containsAll(['order-0', 'order-1', 'order-2']),
    );
    // markAllRead() corrió antes que add(itemAt(2)) (orden de llamada, la
    // cola es FIFO): los ítems 0 y 1 quedan leídos, pero el 2 —agregado
    // DESPUÉS de marcar todo como leído— entra con su default `read: false`,
    // tal como llegaría un push nuevo real después de haber abierto la
    // pantalla de notificaciones.
    expect(state.firstWhere((i) => i.data['orderId'] == 'order-0').read, true);
    expect(state.firstWhere((i) => i.data['orderId'] == 'order-1').read, true);
    expect(
      state.firstWhere((i) => i.data['orderId'] == 'order-2').read,
      false,
    );

    // También persistido correctamente, no solo en memoria.
    final freshContainer = createContainer();
    final reloaded = await freshContainer.read(
      notificationHistoryProvider.future,
    );
    expect(reloaded, hasLength(3));
    expect(
      reloaded.firstWhere((i) => i.data['orderId'] == 'order-2').read,
      false,
    );
  });

  test('markAllRead() no reescribe innecesariamente si ya todo está leído '
      '(evita un save() de más cada vez que se reabre la pantalla de '
      'notificaciones sin novedades)', () async {
    SharedPreferences.setMockInitialValues({});
    final container = createContainer();
    final notifier = container.read(notificationHistoryProvider.notifier);
    await container.read(notificationHistoryProvider.future);
    await notifier.add(itemAt(0));
    await notifier.markAllRead();

    final beforeSecondCall = container
        .read(notificationHistoryProvider)
        .requireValue;
    await notifier.markAllRead();
    final afterSecondCall = container
        .read(notificationHistoryProvider)
        .requireValue;

    // Mismo `List` en memoria (no solo "igual"): `_markAllReadLocked` hace
    // return temprano sin reasignar `state` ni volver a llamar `save()`.
    expect(identical(afterSecondCall, beforeSecondCall), isTrue);
    expect(afterSecondCall.single.read, true);
  });
}
