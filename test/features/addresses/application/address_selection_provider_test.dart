import 'package:celtas_mobile/features/addresses/application/address_selection_provider.dart';
import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const a1 = Address(
    id: 'a1',
    alias: 'Casa',
    fullAddress: 'Av. Uno 1',
    district: 'SJM',
  );
  const a2 = Address(
    id: 'a2',
    alias: 'Trabajo',
    fullAddress: 'Av. Dos 2',
    district: 'Surco',
    isDefault: true,
  );

  group('resolveActiveAddress', () {
    test('lista vacía o null → null', () {
      expect(resolveActiveAddress(const [], null), isNull);
      expect(resolveActiveAddress(null, 'a1'), isNull);
    });

    test('selectedId presente en la lista → esa', () {
      expect(resolveActiveAddress(const [a1, a2], 'a1'), a1);
    });

    test('selectedId null → la isDefault', () {
      expect(resolveActiveAddress(const [a1, a2], null), a2);
    });

    test('selectedId que ya no existe → cae a la isDefault', () {
      expect(resolveActiveAddress(const [a1, a2], 'borrada'), a2);
    });

    test('sin selectedId y sin isDefault → la primera', () {
      const a2NoDefault = Address(
        id: 'a2',
        alias: 'Trabajo',
        fullAddress: 'Av. Dos 2',
        district: 'Surco',
      );
      expect(resolveActiveAddress(const [a1, a2NoDefault], null), a1);
    });
  });

  group('AddressSelectionStorage', () {
    test('load() → null sin prefs inyectado', () {
      expect(AddressSelectionStorage().load(), isNull);
    });

    test('load() lee lo que se guardó (prefs inyectado)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = AddressSelectionStorage(prefs);

      expect(storage.load(), isNull);
      await storage.save('a1');
      expect(storage.load(), 'a1');
      await storage.clear();
      expect(storage.load(), isNull);
    });
  });

  group('SelectedAddressNotifier', () {
    test('build() hidrata desde el storage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await AddressSelectionStorage(prefs).save('a2');

      final container = ProviderContainer(
        overrides: [
          addressSelectionStorageProvider
              .overrideWithValue(AddressSelectionStorage(prefs)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedAddressIdProvider), 'a2');
    });

    test('select(id) actualiza el estado y persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = AddressSelectionStorage(prefs);

      final container = ProviderContainer(
        overrides: [
          addressSelectionStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedAddressIdProvider), isNull);
      container.read(selectedAddressIdProvider.notifier).select('a1');
      expect(container.read(selectedAddressIdProvider), 'a1');
      // Espera al `save` fire-and-forget.
      await Future<void>.delayed(Duration.zero);
      expect(storage.load(), 'a1');
    });

    test('clear() vuelve a null y borra del storage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = AddressSelectionStorage(prefs);
      await storage.save('a1');

      final container = ProviderContainer(
        overrides: [
          addressSelectionStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedAddressIdProvider), 'a1');
      await container.read(selectedAddressIdProvider.notifier).clear();
      expect(container.read(selectedAddressIdProvider), isNull);
      expect(storage.load(), isNull);
    });
  });
}
