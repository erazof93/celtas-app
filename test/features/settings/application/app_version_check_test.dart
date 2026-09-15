import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de `evaluateAppVersion` en aislamiento (pura, sin red ni Riverpod) —
/// mismo criterio que `notification_permission_action.dart`.
void main() {
  group('evaluateAppVersion', () {
    test(
      'build actual mayor que el mínimo requerido → no pide actualizar',
      () {
        final result = evaluateAppVersion(
          currentVersion: '1.0.1+17',
          minVersion: '1.0.1+16',
        );

        expect(result.isUpdateRequired, isFalse);
        expect(result.minVersion, '1.0.1+16');
      },
    );

    test('build actual menor que el mínimo requerido → pide actualizar', () {
      final result = evaluateAppVersion(
        currentVersion: '1.0.1+16',
        minVersion: '1.0.1+17',
      );

      expect(result.isUpdateRequired, isTrue);
      expect(result.minVersion, '1.0.1+17');
    });

    test('build actual igual al mínimo requerido → no pide actualizar', () {
      final result = evaluateAppVersion(
        currentVersion: '1.0.1+16',
        minVersion: '1.0.1+16',
      );

      expect(result.isUpdateRequired, isFalse);
    });

    test(
      'compara el build number, no el semver X.Y.Z: un X.Y.Z mayor con '
      'build menor igual pide actualizar',
      () {
        // Caso real que motivó esta regla: el backend puede publicar el
        // mismo 1.0.1 con distinto build, o incluso un X.Y.Z "viejo" con un
        // build más nuevo si se reempaquetó — el build number es la única
        // fuente de orden confiable (ver doc de `evaluateAppVersion`).
        final result = evaluateAppVersion(
          currentVersion: '2.0.0+10',
          minVersion: '1.0.1+20',
        );

        expect(result.isUpdateRequired, isTrue);
      },
    );

    test('minVersion null (key ausente en el backend) → sin bloqueo', () {
      final result = evaluateAppVersion(currentVersion: '1.0.1+17');

      expect(result.isUpdateRequired, isFalse);
      expect(result.minVersion, isNull);
    });

    test('minVersion vacío → sin bloqueo', () {
      final result = evaluateAppVersion(
        currentVersion: '1.0.1+17',
        minVersion: '',
      );

      expect(result.isUpdateRequired, isFalse);
    });

    test('minVersion sin "+" (formato inválido) → sin bloqueo, no lanza', () {
      final result = evaluateAppVersion(
        currentVersion: '1.0.1+17',
        minVersion: '1.0.1',
      );

      expect(result.isUpdateRequired, isFalse);
    });

    test(
      'minVersion con build no numérico (formato inválido) → sin bloqueo, '
      'no lanza',
      () {
        final result = evaluateAppVersion(
          currentVersion: '1.0.1+17',
          minVersion: '1.0.1+abc',
        );

        expect(result.isUpdateRequired, isFalse);
      },
    );
  });
}
