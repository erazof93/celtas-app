import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato verificado contra `RewardsService.getProgress`
/// (`backend-celtas/src/modules/rewards/rewards.service.ts`): esquema de
/// HITOS configurables (ej. 5, 8, 15), reemplaza el viejo "cada N estrellas
/// = 1 premio".
void main() {
  group('RewardProgress.fromJson', () {
    test('parsea el contrato real con hitos, promocionActiva y premios '
        'disponibles', () {
      final json = {
        'estrellasDelMes': 9,
        'hitos': [
          {'estrellasRequeridas': 5, 'alcanzado': true, 'esEspecial': false},
          {'estrellasRequeridas': 8, 'alcanzado': true, 'esEspecial': false},
          {'estrellasRequeridas': 15, 'alcanzado': false, 'esEspecial': true},
        ],
        'premiosDisponibles': [
          {
            'id': 'r-1',
            'expiresAt': '2026-09-10T00:00:00.000Z',
            'esEspecial': false,
          },
        ],
        'promocionActiva': {
          'label': 'Navidad 2026',
          'multiplier': 2,
          'endDate': '2026-12-31',
        },
      };

      final progress = RewardProgress.fromJson(json);

      expect(progress.estrellasDelMes, 9);
      expect(progress.hitos, hasLength(3));
      expect(progress.hitos[0].estrellasRequeridas, 5);
      expect(progress.hitos[0].alcanzado, isTrue);
      expect(progress.hitos[0].esEspecial, isFalse);
      expect(progress.hitos[2].estrellasRequeridas, 15);
      expect(progress.hitos[2].alcanzado, isFalse);
      expect(progress.hitos[2].esEspecial, isTrue);
      expect(progress.premiosDisponibles, hasLength(1));
      expect(progress.premiosDisponibles.single.id, 'r-1');
      expect(progress.premiosDisponibles.single.esEspecial, isFalse);
      expect(
        progress.premiosDisponibles.single.expiresAt,
        DateTime.utc(2026, 9, 10),
      );
      expect(progress.promocionActiva?.label, 'Navidad 2026');
      expect(progress.promocionActiva?.multiplier, 2);
      // `endDate` se deja como string plano, NO se parsea a DateTime — mismo
      // criterio que `celtas-admin` con las fechas de `StarPromotion`.
      expect(progress.promocionActiva?.endDate, '2026-12-31');
      expect(progress.promocionActiva?.endDate, isA<String>());
    });

    test('promocionActiva null (sin promoción vigente hoy)', () {
      final json = {
        'estrellasDelMes': 4,
        'hitos': <Map<String, dynamic>>[],
        'premiosDisponibles': <Map<String, dynamic>>[],
        'promocionActiva': null,
      };

      final progress = RewardProgress.fromJson(json);

      expect(progress.promocionActiva, isNull);
      expect(progress.premiosDisponibles, isEmpty);
    });

    test('hitos vacío (admin sin hitos configurados todavía) parsea sin '
        'crashear', () {
      final json = {
        'estrellasDelMes': 0,
        'hitos': <Map<String, dynamic>>[],
        'premiosDisponibles': <Map<String, dynamic>>[],
      };

      final progress = RewardProgress.fromJson(json);

      expect(progress.hitos, isEmpty);
      expect(progress.estrellasDelMes, 0);
    });

    test('premiosDisponibles con premio especial (esEspecial: true) preserva '
        'el flag', () {
      final json = {
        'estrellasDelMes': 15,
        'hitos': <Map<String, dynamic>>[],
        'premiosDisponibles': [
          {
            'id': 'r-1',
            'expiresAt': '2026-09-01T00:00:00.000Z',
            'esEspecial': false,
          },
          {
            'id': 'r-2',
            'expiresAt': '2026-09-15T00:00:00.000Z',
            'esEspecial': true,
          },
        ],
      };

      final progress = RewardProgress.fromJson(json);

      expect(progress.premiosDisponibles.map((s) => s.esEspecial), [
        false,
        true,
      ]);
    });
  });

  group('RewardMilestoneProgress.fromJson', () {
    test('parsea un hito individual del contrato real', () {
      final milestone = RewardMilestoneProgress.fromJson({
        'estrellasRequeridas': 8,
        'alcanzado': true,
        'esEspecial': false,
      });

      expect(milestone.estrellasRequeridas, 8);
      expect(milestone.alcanzado, isTrue);
      expect(milestone.esEspecial, isFalse);
    });
  });
}
