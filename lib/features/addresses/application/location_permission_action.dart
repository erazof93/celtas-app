import 'package:geolocator/geolocator.dart';

/// Acción a tomar frente al botón "Usar mi ubicación actual", según el
/// estado real de permiso reportado por el sistema operativo
/// (`Geolocator.checkPermission()`).
///
/// Mismo criterio ya construido para notificaciones
/// (`NotificationPermissionAction`/`actionForAuthorizationStatus`, ver
/// `lib/features/notifications/application/notification_permission_action.dart`):
/// pedir el permiso una sola vez; si ya fue rechazado de forma permanente,
/// `requestPermission()` no vuelve a mostrar el diálogo nativo — hay que
/// redirigir a Configuración del sistema en vez de reintentar a ciegas.
/// Sin dependencia de `Geolocator` (más allá del enum) ni de un
/// `ProviderContainer` — pura y testeable en aislamiento.
enum LocationPermissionAction {
  /// Nunca se le preguntó, o el sistema no pudo determinarlo — dispara el
  /// pedido nativo normal.
  requestPermission,

  /// Ya lo rechazó de forma permanente (Android: "no volver a preguntar";
  /// iOS: rechazo del diálogo) — el pedido nativo ya no muestra nada, hay
  /// que abrir la pantalla de ajustes de la app en el sistema.
  openSystemSettings,

  /// Ya está autorizado (`whileInUse` o `always`) — se puede pedir la
  /// posición directamente.
  none,
}

LocationPermissionAction locationPermissionActionFor(
  LocationPermission permission,
) {
  switch (permission) {
    case LocationPermission.denied:
    case LocationPermission.unableToDetermine:
      return LocationPermissionAction.requestPermission;
    case LocationPermission.deniedForever:
      return LocationPermissionAction.openSystemSettings;
    case LocationPermission.whileInUse:
    case LocationPermission.always:
      return LocationPermissionAction.none;
  }
}
