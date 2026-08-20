import 'package:geolocator/geolocator.dart';

/// Wrapper fino sobre `Geolocator` (plugin de canal de método nativo) para
/// el permiso y la posición GPS del dispositivo.
///
/// Existe para poder mockearlo en tests, mismo criterio que
/// `NotificationPermissionRepository` (wrap de `FirebaseMessaging`/
/// `permission_handler`) para el módulo de notificaciones — ninguno de los
/// métodos estáticos de `Geolocator` es testeable en aislamiento sin esta
/// capa intermedia.
class LocationRepository {
  /// Si el servicio de ubicación del dispositivo (GPS/red) está encendido a
  /// nivel sistema operativo — independiente del permiso otorgado a esta
  /// app. Puede estar apagado aunque el permiso esté concedido.
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  /// Estado actual del permiso, tal como lo reporta el sistema operativo —
  /// no cachea nada, cada llamada es una consulta real.
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  /// Dispara el diálogo nativo de permiso. Solo tiene efecto visible si el
  /// estado actual es `denied` — ver `locationPermissionActionFor`, por eso
  /// este método solo debería llamarse desde ese caso.
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Abre la pantalla de ajustes de la app en el sistema (funciona igual en
  /// Android e iOS) — para el caso `deniedForever`, donde `requestPermission`
  /// ya no puede volver a mostrar el diálogo nativo.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Abre los ajustes de ubicación del sistema (para el caso "permiso
  /// concedido pero el GPS del dispositivo está apagado").
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Posición actual del dispositivo. Asume que el permiso ya fue verificado
  /// como concedido — llamarlo sin verificar antes lanza una excepción de
  /// `Geolocator` que el caller debe manejar.
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}
