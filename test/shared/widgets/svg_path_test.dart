import 'package:celtas_mobile/shared/widgets/svg_path.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paths reales usados en la app (celtas_flame.dart y google_logo.dart).
const flamePath =
    'M4 20 L11 4 M11 4 C11 4 9 8 13 10 M20 20 L13 4 M13 4 C13 4 15 8 11 10';

const googleBluePath =
    'M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 '
    '2.72v2.26h2.9c1.7-1.56 2.7-3.86 2.7-6.62z';

void main() {
  group('parseSvgPath', () {
    test('parsea el path de la llama (notación compacta M/L/C)', () {
      // Antes del fix esto lanzaba ArgumentError: el token "M4" no se
      // reconocía como comando M + coordenada 4.
      expect(() => parseSvgPath(flamePath), returnsNormally);
    });

    test('parsea el path del logo de Google (comandos relativos c/h/v/a/z)',
        () {
      // Antes del fix esto lanzaba ArgumentError: "c", "h", "v", "a" y "z"
      // no estaban soportados.
      expect(() => parseSvgPath(googleBluePath), returnsNormally);
    });

    test('parsea los 4 paths del logo de Google', () {
      const paths = [
        'M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.9c1.7-1.56 2.7-3.86 2.7-6.62z',
        'M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.26c-.8.54-1.84.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.98v2.33A9 9 0 0 0 9 18z',
        'M3.95 10.7A5.4 5.4 0 0 1 3.67 9c0-.59.1-1.16.28-1.7V4.97H.98A9 9 0 0 0 0 9c0 1.45.35 2.83.98 4.03l2.97-2.33z',
        'M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58C13.46.89 11.42 0 9 0A9 9 0 0 0 .98 4.97l2.97 2.33C4.66 5.17 6.65 3.58 9 3.58z',
      ];
      for (final d in paths) {
        expect(() => parseSvgPath(d), returnsNormally, reason: d);
      }
    });

    test('soporta comandos absolutos y relativos de la gramática completa', () {
      // M, L, H, V, C, S, Q, T, A, Z + variantes relativas.
      expect(
        () => parseSvgPath(
          'M10 10 L20 10 H30 V20 C30 30 40 30 40 20 S50 10 50 20 '
          'Q60 30 70 20 T90 20 A5 5 0 0 1 100 20 Z',
        ),
        returnsNormally,
      );
      expect(
        () => parseSvgPath(
          'm10 10 l10 0 h10 v10 c0 10 10 10 10 0 s10-10 10 0 '
          'q10 10 20 0 t20 0 a5 5 0 0 1 10 0 z',
        ),
        returnsNormally,
      );
    });

    test('lanza ArgumentError si el path no empieza con M/m', () {
      expect(() => parseSvgPath('L10 10'), throwsArgumentError);
    });

    test('lanza ArgumentError con un comando desconocido', () {
      expect(() => parseSvgPath('M0 0 X10 10'), throwsArgumentError);
    });
  });
}