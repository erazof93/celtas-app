import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/data/address_repository.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/addresses/presentation/addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockAddressRepository extends Mock implements AddressRepository {}

void main() {
  const home = Address(
    id: 'addr-1',
    alias: 'Casa',
    fullAddress: 'Av. Los Álamos 123',
    district: 'San Juan de Miraflores',
    isDefault: true,
  );
  const work = Address(
    id: 'addr-2',
    alias: 'Trabajo',
    fullAddress: 'Av. Callao 850',
    district: 'Surco',
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  GoRouter router() => GoRouter(
        initialLocation: '/addresses',
        routes: [
          GoRoute(
            path: '/addresses',
            builder: (_, _) => const AddressesScreen(),
          ),
        ],
      );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required MockAddressRepository repository,
  }) async {
    final container = ProviderContainer(
      overrides: [addressRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('sin direcciones → estado vacío', (tester) async {
    final repository = MockAddressRepository();
    when(() => repository.getAddresses()).thenAnswer((_) async => []);

    await pumpScreen(tester, repository: repository);

    expect(find.text('Todavía no tenés direcciones guardadas'), findsOneWidget);
  });

  testWidgets('con direcciones → lista con badge PRINCIPAL en la default',
      (tester) async {
    final repository = MockAddressRepository();
    when(() => repository.getAddresses())
        .thenAnswer((_) async => [home, work]);

    await pumpScreen(tester, repository: repository);

    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Trabajo'), findsOneWidget);
    expect(find.text('PRINCIPAL'), findsOneWidget);
  });

  testWidgets('error al cargar → mensaje real y REINTENTAR', (tester) async {
    final repository = MockAddressRepository();
    when(() => repository.getAddresses())
        .thenThrow(const ApiException('No se pudo conectar'));

    await pumpScreen(tester, repository: repository);

    expect(find.text('No se pudo conectar'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('agregar nueva dirección → POST con el payload correcto',
      (tester) async {
    final repository = MockAddressRepository();
    when(() => repository.getAddresses()).thenAnswer((_) async => [home]);
    const created = Address(
      id: 'addr-3',
      alias: 'Depto',
      fullAddress: 'Jr. Nueva 456',
      district: 'Surco',
    );
    when(() => repository.createAddress(
          alias: 'Depto',
          fullAddress: 'Jr. Nueva 456',
          district: 'Surco',
        )).thenAnswer((_) async => created);

    await pumpScreen(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('addresses-add-new')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('addresses-form-alias')),
      'Depto',
    );
    await tester.enterText(
      find.byKey(const ValueKey('addresses-form-full')),
      'Jr. Nueva 456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('addresses-form-district')),
      'Surco',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('addresses-form-save')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('addresses-form-save')));
    await tester.pumpAndSettle();

    verify(() => repository.createAddress(
          alias: 'Depto',
          fullAddress: 'Jr. Nueva 456',
          district: 'Surco',
        )).called(1);
    expect(find.text('Depto'), findsOneWidget);
  });

  testWidgets('editar dirección existente → PATCH con el id en el path',
      (tester) async {
    final repository = MockAddressRepository();
    when(() => repository.getAddresses()).thenAnswer((_) async => [home]);
    const updated = Address(
      id: 'addr-1',
      alias: 'Casa nueva',
      fullAddress: 'Av. Los Álamos 123',
      district: 'San Juan de Miraflores',
      isDefault: true,
    );
    when(() => repository.updateAddress(
          'addr-1',
          alias: 'Casa nueva',
          fullAddress: 'Av. Los Álamos 123',
          district: 'San Juan de Miraflores',
          isDefault: true,
        )).thenAnswer((_) async => updated);

    await pumpScreen(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('addresses-edit-addr-1')));
    await tester.pumpAndSettle();

    // Precargado con los valores actuales.
    expect(find.text('Casa'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('addresses-form-alias')),
      'Casa nueva',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('addresses-form-save')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('addresses-form-save')));
    await tester.pumpAndSettle();

    verify(() => repository.updateAddress(
          'addr-1',
          alias: 'Casa nueva',
          fullAddress: 'Av. Los Álamos 123',
          district: 'San Juan de Miraflores',
          isDefault: true,
        )).called(1);
  });

  testWidgets(
      'eliminar la dirección principal → reasigna la siguiente como principal',
      (tester) async {
    final repository = MockAddressRepository();
    // Tras el DELETE, el backend ya no devuelve `home`; `work` sigue sin
    // default (el backend NO reasigna solo — la promoción la hace el cliente).
    var afterDelete = false;
    when(() => repository.getAddresses()).thenAnswer((_) async {
      if (!afterDelete) return [home, work];
      return [work];
    });
    when(() => repository.deleteAddress('addr-1')).thenAnswer((_) async {
      afterDelete = true;
    });
    const promoted = Address(
      id: 'addr-2',
      alias: 'Trabajo',
      fullAddress: 'Av. Callao 850',
      district: 'Surco',
      isDefault: true,
    );
    when(() => repository.updateAddress('addr-2', isDefault: true))
        .thenAnswer((_) async => promoted);

    await pumpScreen(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('addresses-delete-addr-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ELIMINAR'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteAddress('addr-1')).called(1);
    verify(() => repository.updateAddress('addr-2', isDefault: true))
        .called(1);
  });

  testWidgets(
      'eliminar una dirección NO principal → no reasigna ninguna default',
      (tester) async {
    final repository = MockAddressRepository();
    when(() => repository.getAddresses()).thenAnswer((_) async => [home, work]);
    when(() => repository.deleteAddress('addr-2')).thenAnswer((_) async {});

    await pumpScreen(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('addresses-delete-addr-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ELIMINAR'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteAddress('addr-2')).called(1);
    verifyNever(() => repository.updateAddress(any(), isDefault: true));
  });

  testWidgets('cancelar el diálogo de eliminar no borra nada', (tester) async {
    final repository = MockAddressRepository();
    when(() => repository.getAddresses()).thenAnswer((_) async => [home]);

    await pumpScreen(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('addresses-delete-addr-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.deleteAddress(any()));
    expect(find.text('Casa'), findsOneWidget);
  });
}
