import 'package:celtas_mobile/features/addresses/application/current_location_controller.dart';
import 'package:celtas_mobile/features/addresses/application/location_resolution_failure.dart';
import 'package:celtas_mobile/features/addresses/data/location_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

class FakePosition extends Fake implements Position {
  FakePosition({this.latitude = -12.1, this.longitude = -76.9});

  @override
  final double latitude;
  @override
  final double longitude;
}

void main() {
  late MockLocationRepository repository;

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [locationRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repository = MockLocationRepository();
  });

  group('requestCurrentPosition()', () {
    test(
      'permiso ya concedido (whileInUse) → pide la posición directo, NUNCA '
      'llama requestPermission()',
      () async {
        when(
          () => repository.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.whileInUse);
        when(
          () => repository.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        final position = FakePosition();
        when(
          () => repository.getCurrentPosition(),
        ).thenAnswer((_) async => position);

        final container = createContainer();
        await container
            .read(currentLocationControllerProvider.notifier)
            .requestCurrentPosition();

        final state = container.read(currentLocationControllerProvider);
        expect(state.value, position);
        verifyNever(() => repository.requestPermission());
        verifyNever(() => repository.openAppSettings());
      },
    );

    test(
      'denied → pide el permiso una vez; si lo concede, pide la posición',
      () async {
        when(
          () => repository.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);
        when(
          () => repository.requestPermission(),
        ).thenAnswer((_) async => LocationPermission.whileInUse);
        when(
          () => repository.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        final position = FakePosition();
        when(
          () => repository.getCurrentPosition(),
        ).thenAnswer((_) async => position);

        final container = createContainer();
        await container
            .read(currentLocationControllerProvider.notifier)
            .requestCurrentPosition();

        final state = container.read(currentLocationControllerProvider);
        expect(state.value, position);
        verify(() => repository.requestPermission()).called(1);
        verifyNever(() => repository.openAppSettings());
      },
    );

    test(
      'denied y el usuario rechaza el diálogo → falla con permissionDenied, '
      'NUNCA reintenta requestPermission() a ciegas',
      () async {
        when(
          () => repository.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);
        when(
          () => repository.requestPermission(),
        ).thenAnswer((_) async => LocationPermission.denied);

        final container = createContainer();
        await container
            .read(currentLocationControllerProvider.notifier)
            .requestCurrentPosition();

        final state = container.read(currentLocationControllerProvider);
        expect(state.hasError, isTrue);
        expect(
          state.error,
          isA<LocationResolutionFailure>().having(
            (e) => e.reason,
            'reason',
            LocationResolutionReason.permissionDenied,
          ),
        );
        verify(() => repository.requestPermission()).called(1);
        verifyNever(() => repository.getCurrentPosition());
      },
    );

    test(
      'deniedForever → abre Configuración del sistema directo, NUNCA llama '
      'requestPermission() (el diálogo nativo ya no aparece)',
      () async {
        when(
          () => repository.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.deniedForever);
        when(
          () => repository.openAppSettings(),
        ).thenAnswer((_) async => true);

        final container = createContainer();
        await container
            .read(currentLocationControllerProvider.notifier)
            .requestCurrentPosition();

        final state = container.read(currentLocationControllerProvider);
        expect(state.hasError, isTrue);
        expect(
          state.error,
          isA<LocationResolutionFailure>().having(
            (e) => e.reason,
            'reason',
            LocationResolutionReason.permissionDeniedForever,
          ),
        );
        verify(() => repository.openAppSettings()).called(1);
        verifyNever(() => repository.requestPermission());
        verifyNever(() => repository.getCurrentPosition());
      },
    );

    test(
      'permiso concedido pero GPS del sistema apagado → falla con '
      'serviceDisabled, sin llamar getCurrentPosition()',
      () async {
        when(
          () => repository.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.whileInUse);
        when(
          () => repository.isLocationServiceEnabled(),
        ).thenAnswer((_) async => false);

        final container = createContainer();
        await container
            .read(currentLocationControllerProvider.notifier)
            .requestCurrentPosition();

        final state = container.read(currentLocationControllerProvider);
        expect(
          state.error,
          isA<LocationResolutionFailure>().having(
            (e) => e.reason,
            'reason',
            LocationResolutionReason.serviceDisabled,
          ),
        );
        verifyNever(() => repository.getCurrentPosition());
      },
    );

    test(
      'getCurrentPosition() lanza (ej. timeout de Geolocator) → falla con '
      'unknown, nunca deja escapar la excepción nativa sin clasificar',
      () async {
        when(
          () => repository.checkPermission(),
        ).thenAnswer((_) async => LocationPermission.whileInUse);
        when(
          () => repository.isLocationServiceEnabled(),
        ).thenAnswer((_) async => true);
        when(
          () => repository.getCurrentPosition(),
        ).thenThrow(Exception('timeout'));

        final container = createContainer();
        await container
            .read(currentLocationControllerProvider.notifier)
            .requestCurrentPosition();

        final state = container.read(currentLocationControllerProvider);
        expect(
          state.error,
          isA<LocationResolutionFailure>().having(
            (e) => e.reason,
            'reason',
            LocationResolutionReason.unknown,
          ),
        );
      },
    );
  });

  group('reset()', () {
    test('limpia el estado a AsyncData(null)', () async {
      when(
        () => repository.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.deniedForever);
      when(() => repository.openAppSettings()).thenAnswer((_) async => true);

      final container = createContainer();
      final notifier = container.read(
        currentLocationControllerProvider.notifier,
      );
      await notifier.requestCurrentPosition();
      expect(
        container.read(currentLocationControllerProvider).hasError,
        isTrue,
      );

      notifier.reset();

      expect(container.read(currentLocationControllerProvider).value, isNull);
    });
  });
}
