import 'package:celtas_mobile/features/addresses/application/location_permission_action.dart';
import 'package:celtas_mobile/features/addresses/application/location_resolution_failure.dart';
import 'package:celtas_mobile/features/addresses/data/location_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Wrapper del repositorio de ubicación, para poder overridearlo desde tests.
final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(),
);

/// Estado del botón "Usar mi ubicación actual" del formulario de
/// direcciones.
///
/// Estado inicial `null` (nadie tocó el botón todavía) — a diferencia de
/// `NotificationPermissionNotifier`, este `build()` NUNCA dispara el diálogo
/// de permiso ni consulta el GPS al construirse: el permiso de ubicación
/// solo debe pedirse ante una acción explícita del usuario (tocar el botón),
/// nunca al simplemente abrir el formulario de direcciones.
class CurrentLocationController extends AsyncNotifier<Position?> {
  @override
  Future<Position?> build() async => null;

  /// Resuelve la posición actual, pidiendo permiso una sola vez si hace
  /// falta (mismo criterio que `NotificationPermissionNotifier.handleTap`):
  ///   - `denied`/`unableToDetermine` → pide el permiso nativo una vez.
  ///   - `deniedForever` → abre Configuración del sistema directamente, NUNCA
  ///     vuelve a llamar `requestPermission()` (el diálogo nativo ya no
  ///     aparece — confirmado en el patrón ya construido para notificaciones).
  ///   - Servicio de ubicación apagado a nivel sistema (con permiso ya
  ///     concedido) → falla con `serviceDisabled`, sin intentar
  ///     `getCurrentPosition()` (lanzaría una excepción nativa menos clara).
  Future<void> requestCurrentPosition() async {
    state = const AsyncLoading<Position?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_resolve);
  }

  Future<Position> _resolve() async {
    final repo = ref.read(locationRepositoryProvider);

    var permission = await repo.checkPermission();
    switch (locationPermissionActionFor(permission)) {
      case LocationPermissionAction.requestPermission:
        permission = await repo.requestPermission();
      case LocationPermissionAction.openSystemSettings:
        await repo.openAppSettings();
        throw const LocationResolutionFailure(
          LocationResolutionReason.permissionDeniedForever,
        );
      case LocationPermissionAction.none:
        break;
    }

    // Re-evalúa: si el diálogo nativo (recién disparado arriba) también fue
    // rechazado, no hay nada más que hacer acá — nunca se reintenta a ciegas.
    if (locationPermissionActionFor(permission) !=
        LocationPermissionAction.none) {
      throw const LocationResolutionFailure(
        LocationResolutionReason.permissionDenied,
      );
    }

    if (!await repo.isLocationServiceEnabled()) {
      throw const LocationResolutionFailure(
        LocationResolutionReason.serviceDisabled,
      );
    }

    try {
      return await repo.getCurrentPosition();
    } catch (_) {
      throw const LocationResolutionFailure(LocationResolutionReason.unknown);
    }
  }

  /// Limpia el estado (ej. al cerrar/reiniciar el formulario) sin dejar un
  /// error o una posición vieja visible la próxima vez que se abra.
  void reset() {
    state = const AsyncData(null);
  }
}

final currentLocationControllerProvider =
    AsyncNotifierProvider<CurrentLocationController, Position?>(
      CurrentLocationController.new,
    );
