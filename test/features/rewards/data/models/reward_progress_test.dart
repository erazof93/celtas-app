import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato verificado contra `RewardsService.getProgress`
/// (`backend-celtas/src/modules/rewards/rewards.service.ts`).
void main() {
  group('RewardProgress.fromJson', () {
    test('parsea el contrato real con promocionActiva y premios disponibles',
        () {
      final json = {
        'estrellasParaProximoPremio': 4,
        'estrellasPorPremio': 10,
        'premiosDisponibles': [
          {'id': 'r-1', 'expiresAt': '2026-09-10T00:00:00.000Z'},
        ],
        'promocionActiva': {
          'label': 'Navidad 2026',
          'multiplier': 2,
          'endDate': '2026-12-31',
        },
      };

      final progress = RewardProgress.fromJson(json);

      expect(progress.estrellasParaProximoPremio, 4);
      expect(progress.estrellasPorPremio, 10);
      expect(progress.premiosDisponibles, hasLength(1));
      expect(progress.premiosDisponibles.single.id, 'r-1');
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
        'estrellasParaProximoPremio': 4,
        'estrellasPorPremio': 10,
        'premiosDisponibles': <Map<String, dynamic>>[],
        'promocionActiva': null,
      };

      final progress = RewardProgress.fromJson(json);

      expect(progress.promocionActiva, isNull);
      expect(progress.premiosDisponibles, isEmpty);
    });

    test('premiosDisponibles con varios premios preserva el orden del backend '
        '(ASC por expiresAt)', () {
      final json = {
        'estrellasParaProximoPremio': 0,
        'estrellasPorPremio': 10,
        'premiosDisponibles': [
          {'id': 'r-1', 'expiresAt': '2026-09-01T00:00:00.000Z'},
          {'id': 'r-2', 'expiresAt': '2026-09-15T00:00:00.000Z'},
        ],
      };

      final progress = RewardProgress.fromJson(json);

      expect(
        progress.premiosDisponibles.map((s) => s.id),
        ['r-1', 'r-2'],
      );
    });
  });
}
