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
  }) async {
    final created = await ref.read(addressRepositoryProvider).createAddress(
          alias: alias,
          fullAddress: fullAddress,
          reference: reference,
          district: district,
        );
    final current = state.valueOrNull ?? const [];
    state = AsyncData([...current, created]);
    return created;
  }
}

final addressListProvider =
    AsyncNotifierProvider<AddressListNotifier, List<Address>>(
  AddressListNotifier.new,
);
