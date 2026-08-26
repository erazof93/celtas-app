import 'package:celtas_mobile/shared/utils/spanish_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDaysRemaining', () {
    test('vigencia futura → "Vence en N días"', () {
      final expiresAt = DateTime.now().add(const Duration(days: 12, hours: 1));
      expect(formatDaysRemaining(expiresAt), 'Vence en 12 días');
    });

    test('exactamente 1 día restante → singular ("día", no "días")', () {
      final expiresAt = DateTime.now().add(const Duration(days: 1, hours: 1));
      expect(formatDaysRemaining(expiresAt), 'Vence en 1 día');
    });

    test(
      'ya vencido (reloj desincronizado) → "Vence hoy", nunca un número '
      'negativo',
      () {
        final expiresAt = DateTime.now().subtract(const Duration(days: 3));
        expect(formatDaysRemaining(expiresAt), 'Vence hoy');
      },
    );

    test('vence dentro de las próximas 24h (mismo día) → "Vence hoy"', () {
      final expiresAt = DateTime.now().add(const Duration(hours: 2));
      expect(formatDaysRemaining(expiresAt), 'Vence hoy');
    });
  });

  group('formatLongDateFromYmd', () {
    test('parsea por componentes, sin pasar por DateTime.parse', () {
      expect(formatLongDateFromYmd('2026-12-31'), '31 dic 2026');
    });

    test('día de un solo dígito no lleva cero a la izquierda', () {
      expect(formatLongDateFromYmd('2026-01-05'), '5 ene 2026');
    });
  });
}
