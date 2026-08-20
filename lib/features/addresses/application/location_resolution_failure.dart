/// Por qué no se pudo resolver la posición GPS actual — para que la UI
/// muestre un mensaje específico en vez de un error genérico.
enum LocationResolutionReason {
  /// El usuario rechazó el permiso (recién, en el diálogo nativo que se le
  /// mostró una única vez esta vez).
  permissionDenied,

  /// El usuario ya lo había rechazado de forma permanente antes de tocar el
  /// botón — se lo redirigió a Configuración del sistema en vez de mostrar
  /// el diálogo nativo (que ya no aparece).
  permissionDeniedForever,

  /// El permiso está concedido pero el GPS del dispositivo está apagado.
  serviceDisabled,

  /// Cualquier otro fallo (timeout de `Geolocator`, error de plataforma).
  unknown,
}

/// Excepción de dominio para el flujo "Usar mi ubicación actual" —
/// `CurrentLocationController` la lanza dentro de `AsyncValue.guard`, nunca
/// deja escapar la excepción nativa de `Geolocator` sin clasificar.
class LocationResolutionFailure implements Exception {
  const LocationResolutionFailure(this.reason);

  final LocationResolutionReason reason;

  @override
  String toString() => 'LocationResolutionFailure($reason)';
}
