import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/addresses/data/address_repository.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de direcciones contra el backend real.
final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ApiClient.instance.dio),
);

/// Direcciones guardadas del usuario autenticado (`GET /users/me/addresses`).
///
/// `AsyncNotifier` en vez de `FutureProvider` porque el checkout necesita
/// refrescar la lista tras crear una dirección nueva (`addAddress`) y
/// seleccionarla automáticamente, sin perder el resto del estado de la
/// pantalla.
class AddressListNotifier extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() {
    return ref.read(addressRepositoryProvider).getAddresses();
  }

  /// Crea una dirección y la agrega al estado local (evita un round-trip
  /// extra de `GET` tras el `POST`). Devuelve la dirección creada para que el
  /// checkout la seleccione de inmediato.
  Future<Address> addAddress({
    required String alias,
    required String fullAddress,
    String? reference,
    required String district,
    double? latitude,
    double? longitude,
  }) async {
    final created = await ref.read(addressRepositoryProvider).createAddress(
          alias: alias,
          fullAddress: fullAddress,
          reference: reference,
          district: district,
          latitude: latitude,
          longitude: longitude,
        );
    final current = state.valueOrNull ?? const [];
    state = AsyncData([...current, created]);
    return created;
  }

  /// Edita una dirección existente. Refresca la lista completa desde el
  /// backend en vez de parchear el estado local a mano: el orden ("principal
  /// primero") y el flag `isDefault` de las demás direcciones pueden cambiar
  /// server-side (`unsetDefault` en `addresses.service.ts`), y replicar esa
  /// lógica en el cliente sería duplicar una regla que el backend ya aplica.
  Future<void> updateAddress(
    String id, {
    String? alias,
    String? fullAddress,
    String? reference,
    String? district,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) async {
    final repository = ref.read(addressRepositoryProvider);
    await repository.updateAddress(
      id,
      alias: alias,
      fullAddress: fullAddress,
      reference: reference,
      district: district,
      isDefault: isDefault,
      latitude: latitude,
      longitude: longitude,
    );
    state = AsyncData(await repository.getAddresses());
  }

  /// Elimina una dirección.
  ///
  /// El backend NO reasigna una nueva principal automáticamente (verificado:
  /// `AddressesService.remove()` no toca `isDefault` de las demás). Si la
  /// dirección eliminada era la principal y quedan otras, promovemos acá la
  /// primera del listado restante (ya viene ordenado `isDefault DESC,
  /// createdAt ASC`, o sea la más antigua) para que siempre haya una
  /// dirección principal clara — el checkout y el home dependen de eso.
  Future<void> removeAddress(String id) async {
    final repository = ref.read(addressRepositoryProvider);
    final current = state.valueOrNull ?? const [];
    Address? removed;
    for (final address in current) {
      if (address.id == id) {
        removed = address;
        break;
      }
    }
    await repository.deleteAddress(id);
    var remaining = await repository.getAddresses();
    if (removed?.isDefault == true &&
        remaining.isNotEmpty &&
        !remaining.first.isDefault) {
      await repository.updateAddress(remaining.first.id, isDefault: true);
      remaining = await repository.getAddresses();
    }
    state = AsyncData(remaining);
  }
}

final addressListProvider =
    AsyncNotifierProvider<AddressListNotifier, List<Address>>(
  AddressListNotifier.new,
);
