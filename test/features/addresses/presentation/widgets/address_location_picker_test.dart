import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/geoapify_providers.dart';
import 'package:celtas_mobile/features/addresses/data/geoapify_repository.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/address_location_picker.dart';
import 'package:celtas_mobile/features/addresses/presentation/widgets/address_map_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

class MockGeoapifyRepository extends Mock implements GeoapifyRepository {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Con GEOAPIFY_API_KEY seteada a propósito: sin ella `AddressMapPicker`
    // cae al placeholder "Mapa no disponible" y NUNCA monta el `FlutterMap`
    // real, con lo que su `MapController` queda sin adjuntar — invocar
    // `onCenterChanged` en ese estado revienta en
    // `_AddressMapPickerState.didUpdateWidget` (`MapController.camera`
    // exige que `FlutterMap` se haya construido al menos una vez), un
    // crash real que confirma que este test necesita el mapa real montado,
    // igual que en dispositivo.
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com\n'
          'GEOAPIFY_API_KEY=test-key-for-widget-tests',
    );
  });

  late MockGeoapifyRepository repository;

  Future<void> pumpPicker(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [geoapifyRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: AddressLocationPicker(
              fullAddressController: TextEditingController(),
              districtController: TextEditingController(),
              latitude: null,
              longitude: null,
              onLocationChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    repository = MockGeoapifyRepository();
    when(
      () => repository.reverseGeocode(
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) async => null);
  });

  testWidgets(
    'arrastrar el mapa dispara reverse geocoding solo UNA vez, tras soltar '
    '(debounce) — no una vez por cada frame intermedio del gesto',
    (tester) async {
      await pumpPicker(tester);

      final mapPicker = tester.widget<AddressMapPicker>(
        find.byType(AddressMapPicker),
      );

      // Simula ~10 frames intermedios de un solo drag continuo del pin
      // (lo que `onPositionChanged` de `flutter_map` dispara en cada frame
      // mientras el dedo sigue sobre la pantalla — confirmado en
      // dispositivo real), cada uno separado por menos que la ventana de
      // debounce (400ms), igual que un drag real de medio segundo.
      final dragFrames = List.generate(
        10,
        (i) => LatLng(-12.1633 - (i + 1) * 0.0001, -76.9718),
      );
      for (final point in dragFrames) {
        mapPicker.onCenterChanged(point);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Todavía dentro de la ventana de debounce desde el último frame: sin
      // el fix, cada uno de los 10 frames de arriba ya habría disparado su
      // propia llamada de reverse geocoding.
      verifyNever(
        () => repository.reverseGeocode(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );

      // El pin se "suelta": pasa la ventana completa de debounce sin que
      // llegue un nuevo frame.
      await tester.pump(const Duration(milliseconds: 400));

      final lastPoint = dragFrames.last;
      verify(
        () => repository.reverseGeocode(
          latitude: lastPoint.latitude,
          longitude: lastPoint.longitude,
        ),
      ).called(1);
    },
  );
}
