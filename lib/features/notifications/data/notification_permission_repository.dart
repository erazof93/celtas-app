import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Wrapper fino sobre `FirebaseMessaging`/`permission_handler` para el estado
/// del permiso de notificaciones.
///
/// Existe para poder mockearlo en tests: `FirebaseMessaging` es un plugin
/// (canal de método nativo) y `openAppSettings()` es una función top-level
/// del paquete `permission_handler` — ninguno de los dos es testeable en
/// aislamiento sin esta capa intermedia, mismo criterio que
/// `NotificationRepository` (wrap de `dio`) para el resto del módulo.
class NotificationPermissionRepository {
  NotificationPermissionRepository({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// Estado actual del permiso, tal como lo reporta el sistema operativo —
  /// no cachea nada, cada llamada es una consulta real.
  Future<AuthorizationStatus> getStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Dispara el diálogo nativo de permiso. Solo tiene efecto visible si el
  /// estado actual es `notDetermined` — ver `actionForAuthorizationStatus`,
  /// por eso este método solo debería llamarse desde ese caso.
  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus;
  }

  /// Abre la pantalla de ajustes de la app en el sistema (funciona igual en
  /// Android e iOS).
  Future<bool> openSystemSettings() => ph.openAppSettings();
}
