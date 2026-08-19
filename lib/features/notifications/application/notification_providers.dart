import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/notifications/application/notification_permission_action.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/notifications/data/notification_history_repository.dart';
import 'package:celtas_mobile/features/notifications/data/notification_permission_repository.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de notificaciones push contra el backend real.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ApiClient.instance.dio),
);

/// Historial local de notificaciones recibidas (`shared_preferences`).
final notificationHistoryRepositoryProvider =
    Provider<NotificationHistoryRepository>(
      (ref) => NotificationHistoryRepository(),
    );

/// Lista de notificaciones recibidas, más reciente primero. `NotificationService`
/// (fuera del árbol de widgets) llama a `add()` desde los mismos 3 puntos donde
/// ya intercepta foreground/background/terminated (módulo 9); la pantalla
/// `/notifications` solo lee este provider.
class NotificationHistoryNotifier
    extends AsyncNotifier<List<NotificationHistoryItem>> {
  // Serializa las mutaciones de `add()`. Sin esto, dos llamadas concurrentes
  // (dos pushes casi simultáneos, sin `await` entre medio) leen el mismo
  // `current` antes de que cualquiera de las dos mute `state`, y la segunda
  // en resolver pisa a la primera — se pierde una notificación. Hallazgo
  // real de `@tester`, reproducido con un test que fuerza la carrera
  // (`notification_history_provider_test.dart`). Solo esperar `future` (el
  // fix anterior) cerraba el caso "`add()` vs `build()` en curso", no
  // "`add()` vs `add()` en curso".
  Future<void> _mutationQueue = Future.value();

  @override
  Future<List<NotificationHistoryItem>> build() =>
      ref.read(notificationHistoryRepositoryProvider).load();

  Future<void> add(NotificationHistoryItem item) {
    final scheduled = _mutationQueue.then((_) => _addLocked(item));
    // Sigue encadenando aunque esta mutación falle (ej. `save()` sin
    // espacio/permiso): una notificación que no se pudo persistir no debe
    // trabar las que lleguen después.
    _mutationQueue = scheduled.catchError((_) {});
    return scheduled;
  }

  Future<void> _addLocked(NotificationHistoryItem item) async {
    // Espera a que `build()` termine antes de mutar (evita perder el ítem
    // nuevo si `add()` se llama mientras la carga inicial todavía está en
    // curso — puede pasar en el arranque desde terminada, donde
    // `NotificationService` procesa `getInitialMessage()` apenas se lee este
    // provider por primera vez).
    final current = await future;
    // Mismo tope que lo persistido (`NotificationHistoryRepository.save`):
    // sin esto, la lista en memoria de una sesión larga podía crecer sin
    // límite aunque lo guardado sí estuviera acotado.
    final updated = [
      item,
      ...current,
    ].take(NotificationHistoryRepository.maxItems).toList();
    state = AsyncData(updated);
    await ref.read(notificationHistoryRepositoryProvider).save(updated);
  }

  /// Marca todo el historial como leído (contador de la campana → 0). Usa la
  /// misma cola de mutaciones que `add()`: si llega un push mientras se abre
  /// la pantalla de notificaciones, las dos mutaciones se serializan en vez
  /// de pisarse.
  Future<void> markAllRead() {
    final scheduled = _mutationQueue.then((_) => _markAllReadLocked());
    _mutationQueue = scheduled.catchError((_) {});
    return scheduled;
  }

  Future<void> _markAllReadLocked() async {
    final current = await future;
    if (current.every((item) => item.read)) return;
    final updated = [for (final item in current) item.copyWith(read: true)];
    state = AsyncData(updated);
    await ref.read(notificationHistoryRepositoryProvider).save(updated);
  }
}

final notificationHistoryProvider =
    AsyncNotifierProvider<
      NotificationHistoryNotifier,
      List<NotificationHistoryItem>
    >(NotificationHistoryNotifier.new);

/// Cantidad de notificaciones no leídas, para el badge de la campana del
/// Home (mismo patrón que el badge de unidades del carrito). `0` mientras
/// carga o si falla — el badge simplemente no se muestra, no hay un estado
/// de error visible para esto.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final history = ref.watch(notificationHistoryProvider).valueOrNull;
  if (history == null) return 0;
  return history.where((item) => !item.read).length;
});

/// Repositorio del permiso de notificaciones (wrap de `FirebaseMessaging`/
/// `permission_handler`, ver el docstring de la clase).
final notificationPermissionRepositoryProvider =
    Provider<NotificationPermissionRepository>(
      (ref) => NotificationPermissionRepository(),
    );

/// Estado del permiso de notificaciones (renglón "Notificaciones" en
/// Perfil). `ProfileScreen` lo invalida al volver a foreground
/// (`didChangeAppLifecycleState`), por si el usuario lo cambió desde
/// Configuración sin reiniciar la app.
class NotificationPermissionNotifier extends AsyncNotifier<AuthorizationStatus> {
  @override
  Future<AuthorizationStatus> build() =>
      ref.read(notificationPermissionRepositoryProvider).getStatus();

  /// Reconsulta el estado real del sistema operativo. Usa
  /// `copyWithPrevious`/`AsyncValue.guard` (en vez de un `ref.invalidate`
  /// externo) para mantener el valor anterior visible mientras carga —
  /// mismo criterio de no dejar la UI en blanco durante un refresh que ya
  /// se sigue en el resto de la app (ver `businessHoursProvider`/Home,
  /// aunque ahí el `copyWithPrevious` lo aplica Riverpod internamente sobre
  /// un `FutureProvider`, no un método manual como este).
  Future<void> refresh() async {
    state = const AsyncLoading<AuthorizationStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(notificationPermissionRepositoryProvider).getStatus(),
    );
  }

  /// Acción al tocar el renglón: decide qué hacer según el estado actual
  /// (`actionForAuthorizationStatus`) y refresca el estado real al terminar
  /// — nunca asume el resultado, siempre vuelve a preguntarle al sistema
  /// operativo (`requestPermission()` puede quedar en `denied` igual que
  /// antes si el usuario lo rechaza en el diálogo).
  Future<void> handleTap() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final repo = ref.read(notificationPermissionRepositoryProvider);
    switch (actionForAuthorizationStatus(current)) {
      case NotificationPermissionAction.requestPermission:
        await repo.requestPermission();
      case NotificationPermissionAction.openSystemSettings:
        await repo.openSystemSettings();
      case NotificationPermissionAction.none:
        return;
    }
    await refresh();
  }
}

final notificationPermissionProvider =
    AsyncNotifierProvider<NotificationPermissionNotifier, AuthorizationStatus>(
      NotificationPermissionNotifier.new,
    );
