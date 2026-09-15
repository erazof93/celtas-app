import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

/// `appVersionCheckProvider`: combina la versión instalada
/// (`currentAppVersionProvider`, overrideado acá para no depender del
/// method channel real de `package_info_plus`) contra `min_app_version` de
/// `GET /settings/public`. Ver doc del provider para el criterio de
/// comparación (build number, no semver) y el fail-open ante error de red.
void main() {
  late MockSettingsRepository repository;

  ProviderContainer createContainer({required String currentVersion}) {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository),
        currentAppVersionProvider.overrideWith(
          (ref) async => currentVersion,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repository = MockSettingsRepository();
  });

  test(
    'min_app_version 1.0.1+16, app instalada +17 → no pide actualizar',
    () async {
      when(() => repository.getPublicSettings()).thenAnswer(
        (_) async => {
          'whatsapp_business_number': '51999999999',
          'min_app_version': '1.0.1+16',
        },
      );

      final container = createContainer(currentVersion: '1.0.1+17');
      final result = await container.read(appVersionCheckProvider.future);

      expect(result.isUpdateRequired, isFalse);
      expect(result.minVersion, '1.0.1+16');
    },
  );

  test(
    'min_app_version 1.0.1+17, app instalada +16 → pide actualizar',
    () async {
      when(() => repository.getPublicSettings()).thenAnswer(
        (_) async => {'min_app_version': '1.0.1+17'},
      );

      final container = createContainer(currentVersion: '1.0.1+16');
      final result = await container.read(appVersionCheckProvider.future);

      expect(result.isUpdateRequired, isTrue);
      expect(result.minVersion, '1.0.1+17');
    },
  );

  test(
    'el backend no devuelve la key min_app_version → comportamiento '
    'default, sin bloqueo',
    () async {
      when(() => repository.getPublicSettings()).thenAnswer(
        (_) async => {'whatsapp_business_number': '51999999999'},
      );

      final container = createContainer(currentVersion: '1.0.1+17');
      final result = await container.read(appVersionCheckProvider.future);

      expect(result.isUpdateRequired, isFalse);
      expect(result.minVersion, isNull);
    },
  );

  test(
    'red desconectada / timeout (ApiException del repositorio) → fallback '
    'graceful, permite continuar sin bloquear',
    () async {
      when(() => repository.getPublicSettings()).thenThrow(
        const ApiException(
          'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        ),
      );

      final container = createContainer(currentVersion: '1.0.1+17');
      final result = await container.read(appVersionCheckProvider.future);

      expect(result.isUpdateRequired, isFalse);
      expect(result.minVersion, isNull);
    },
  );
}
