import 'package:firebase_messaging/firebase_messaging.dart';

/// Acción a tomar al tocar el renglón "Notificaciones" en Perfil, según el
/// estado real de permiso reportado por el sistema operativo
/// (`FirebaseMessaging.instance.getNotificationSettings()`).
///
/// Confirmado contra la doc oficial de FlutterFire: una vez que el usuario
/// rechaza el permiso, `requestPermission()` YA NO puede volver a mostrar el
/// diálogo nativo — devuelve `denied` de nuevo sin ninguna interacción
/// visible. Por eso `denied` redirige a Configuración del sistema
/// (`openAppSettings()`, paquete `permission_handler`) en vez de reintentar
/// un pedido que no haría nada. Sin dependencia de `FirebaseMessaging`
/// ni de un `ProviderContainer` — igual que `NotificationTarget.fromPayload`,
/// esta clasificación es pura y testeable en aislamiento.
enum NotificationPermissionAction {
  /// Nunca se le preguntó — dispara el pedido nativo normal.
  requestPermission,

  /// Ya lo rechazó una vez (el pedido nativo ya no muestra nada) — abre la
  /// pantalla de ajustes de la app en el sistema.
  openSystemSettings,

  /// Ya está autorizado, o autorización provisional (solo iOS, notificaciones
  /// silenciosas) — tocar el renglón no hace nada.
  none,
}

NotificationPermissionAction actionForAuthorizationStatus(
  AuthorizationStatus status,
) {
  switch (status) {
    case AuthorizationStatus.notDetermined:
      return NotificationPermissionAction.requestPermission;
    case AuthorizationStatus.denied:
      return NotificationPermissionAction.openSystemSettings;
    case AuthorizationStatus.authorized:
    case AuthorizationStatus.provisional:
      return NotificationPermissionAction.none;
  }
}
