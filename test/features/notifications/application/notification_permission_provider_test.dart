import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_permission_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationPermissionRepository extends Mock
    implements NotificationPermissionRepository {}

void main() {
  late MockNotificationPermissionRepository repository;

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        notificationPermissionRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repository = MockNotificationPermissionRepository();
  });

  group('build()', () {
    test('carga el estado real desde el repositorio', () async {
      when(
        () => repository.getStatus(),
      ).thenAnswer((_) async => AuthorizationStatus.authorized);

      final container = createContainer();
      final status = await container.read(
        notificationPermissionProvider.future,
      );

      expect(status, AuthorizationStatus.authorized);
    });
  });

  group('handleTap()', () {
    test(
      'notDetermined → llama requestPermission(), NUNCA openSystemSettings()',
      () async {
        when(
          () => repository.getStatus(),
        ).thenAnswer((_) async => AuthorizationStatus.notDetermined);
        when(
          () => repository.requestPermission(),
        ).thenAnswer((_) async => AuthorizationStatus.authorized);

        final container = createContainer();
        await container.read(notificationPermissionProvider.future);
        await container
            .read(notificationPermissionProvider.notifier)
            .handleTap();

        verify(() => repository.requestPermission()).called(1);
        verifyNever(() => repository.openSystemSettings());
      },
    );

    test(
      'denied → llama openSystemSettings(), NUNCA requestPermission() de '
      'nuevo (el diálogo nativo ya no vuelve a aparecer una vez rechazado)',
      () async {
        when(
          () => repository.getStatus(),
        ).thenAnswer((_) async => AuthorizationStatus.denied);
        when(
          () => repository.openSystemSettings(),
        ).thenAnswer((_) async => true);

        final container = createContainer();
        await container.read(notificationPermissionProvider.future);
        await container
            .read(notificationPermissionProvider.notifier)
            .handleTap();

        verify(() => repository.openSystemSettings()).called(1);
        verifyNever(() => repository.requestPermission());
      },
    );

    test(
      'authorized → no llama ni requestPermission() ni openSystemSettings()',
      () async {
        when(
          () => repository.getStatus(),
        ).thenAnswer((_) async => AuthorizationStatus.authorized);

        final container = createContainer();
        await container.read(notificationPermissionProvider.future);
        await container
            .read(notificationPermissionProvider.notifier)
            .handleTap();

        verifyNever(() => repository.requestPermission());
        verifyNever(() => repository.openSystemSettings());
      },
    );

    test(
      'después de requestPermission() vuelve a consultar el estado real '
      '(nunca asume el resultado)',
      () async {
        when(
          () => repository.getStatus(),
        ).thenAnswer((_) async => AuthorizationStatus.notDetermined);
        when(
          () => repository.requestPermission(),
        ).thenAnswer((_) async => AuthorizationStatus.authorized);

        final container = createContainer();
        await container.read(notificationPermissionProvider.future);

        // Tras requestPermission(), getStatus() ya reportaría el nuevo
        // estado real si se volviera a preguntar — se hace explícito
        // devolviendo algo distinto la segunda vez.
        when(
          () => repository.getStatus(),
        ).thenAnswer((_) async => AuthorizationStatus.authorized);

        await container
            .read(notificationPermissionProvider.notifier)
            .handleTap();

        final state = container
            .read(notificationPermissionProvider)
            .requireValue;
        expect(state, AuthorizationStatus.authorized);
        // getStatus() se llamó al menos dos veces: build() inicial + el
        // refresh() posterior a requestPermission().
        verify(() => repository.getStatus()).called(2);
      },
    );
  });

  group('refresh()', () {
    test('reconsulta el estado real sin llamar a request/openSettings', () async {
      when(
        () => repository.getStatus(),
      ).thenAnswer((_) async => AuthorizationStatus.denied);

      final container = createContainer();
      await container.read(notificationPermissionProvider.future);

      when(
        () => repository.getStatus(),
      ).thenAnswer((_) async => AuthorizationStatus.authorized);
      await container.read(notificationPermissionProvider.notifier).refresh();

      final state = container
          .read(notificationPermissionProvider)
          .requireValue;
      expect(state, AuthorizationStatus.authorized);
      verifyNever(() => repository.requestPermission());
      verifyNever(() => repository.openSystemSettings());
    });
  });
}
