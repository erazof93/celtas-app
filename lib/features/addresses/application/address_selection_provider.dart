import 'dart:async';

import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `id` de la dirección seleccionada actual (persistida en
/// `AddressSelectionStorage`). `null` = sin selección explícita → el resolver
/// cae a la principal.
class SelectedAddressNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(addressSelectionStorageProvider).load();

  /// El tap en una tarjeta de `AddressesScreen` llama acá. No toca
  /// `isDefault` — eso es el botón ⭐.
  void select(String id) {
    if (state == id) return;
    state = id;
    unawaited(ref.read(addressSelectionStorageProvider).save(id));
  }

  Future<void> clear() async {
    state = null;
    await ref.read(addressSelectionStorageProvider).clear();
  }
}

final selectedAddressIdProvider =
    NotifierProvider<SelectedAddressNotifier, String?>(
  SelectedAddressNotifier.new,
);

/// Resuelve la dirección "activa" a partir de la lista y la selección
/// persistida: `selectedId` si sigue existiendo → si no, la `isDefault` → si
/// no, la primera. `null` si la lista está vacía o es `null`.
///
/// Una sola definición para que Home y checkout apliquen exactamente la misma
/// regla de fallback.
Address? resolveActiveAddress(List<Address>? addresses, String? selectedId) {
  if (addresses == null || addresses.isEmpty) return null;

  if (selectedId != null) {
    for (final a in addresses) {
      if (a.id == selectedId) return a;
    }
  }
  for (final a in addresses) {
    if (a.isDefault) return a;
  }
  return addresses.first;
}
