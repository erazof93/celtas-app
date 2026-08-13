import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/presentation/login_screen.dart';
import 'package:celtas_mobile/features/auth/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

/// Cobertura de regresión para el reemplazo de `CeltasFlame` (CustomPainter
/// dibujado a mano, eliminado) por el SVG real de marca
/// (`assets/branding/iconos.svg`, cargado en runtime con `flutter_svg`).
///
/// IMPORTANTE (confirmado leyendo `vector_graphics` 1.2.3,
/// `lib/src/vector_graphics.dart:518-524`): si `SvgPicture.asset` falla al
/// cargar/parsear el SVG y NO se le pasa un `errorBuilder` (nuestro caso —
/// ninguno de los 2 usos en producción lo pasa), el widget degrada en
/// silencio a un `SizedBox` vacío del mismo tamaño, SIN lanzar ninguna
/// excepción visible ni para `tester.takeException()` ni como
/// `ErrorWidget`. Verificado de forma empírica: cambiar temporalmente la
/// ruta del asset en `SplashScreen` a una inexistente NO hace fallar
/// `tester.takeException()` ni agrega un `ErrorWidget` al árbol — un test
/// que solo revisara esas dos cosas pasaría igual con el asset roto. Por
/// eso la cobertura real de "el asset carga correctamente" viene del
/// segundo grupo de tests de este archivo, que llama directamente
/// `SvgAssetLoader(path).loadBytes(null)` (la misma carga que usa
/// `SvgPicture.asset` internamente) y confirma que efectivamente lanza al
/// pasarle una ruta rota, y no lanza con la ruta real. Los tests de widget
/// de abajo siguen siendo útiles para confirmar la configuración
/// (tamaño/color) que sí se puede leer de forma estática del `SvgPicture`
/// en el árbol, pero NO son evidencia de que el archivo referenciado
/// exista o sea un SVG válido.
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  testWidgets(
    'Splash: el ícono de marca (SVG) carga sin error, tamaño 88x88 y color '
    'gold (colorFilter srcIn), reemplazando a CeltasFlame',
    (tester) async {
      final repository = MockAuthRepository();
      when(() => repository.readRefreshToken()).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(theme: AppTheme.dark, home: const SplashScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final finder = find.byType(SvgPicture);
      expect(finder, findsOneWidget);

      final svgPicture = tester.widget<SvgPicture>(finder);
      expect(svgPicture.width, 88);
      expect(svgPicture.height, 88);
      expect(
        svgPicture.colorFilter,
        const ColorFilter.mode(CeltasColors.gold, BlendMode.srcIn),
      );
      // NOTA: esto NO confirma que el asset cargó bien (ver comentario del
      // archivo) — solo que el widget está configurado con el tamaño/color
      // esperados. La carga real se confirma en el grupo de tests de abajo.
    },
  );

  testWidgets(
    'Login: el ícono de marca (SVG) carga sin error, tamaño 24x24 y color '
    'orange (colorFilter srcIn)',
    (tester) async {
      final repository = MockAuthRepository();
      when(() => repository.readRefreshToken()).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(theme: AppTheme.dark, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final finder = find.byType(SvgPicture);
      expect(finder, findsOneWidget);

      final svgPicture = tester.widget<SvgPicture>(finder);
      expect(svgPicture.width, 24);
      expect(svgPicture.height, 24);
      expect(
        svgPicture.colorFilter,
        const ColorFilter.mode(CeltasColors.orange, BlendMode.srcIn),
      );
      // NOTA: esto NO confirma que el asset cargó bien (ver comentario del
      // archivo) — solo que el widget está configurado con el tamaño/color
      // esperados. La carga real se confirma en el grupo de tests de abajo.
    },
  );

  group('assets/branding/iconos.svg carga y parsea como SVG válido', () {
    // Esta es la cobertura que realmente detecta una ruta rota, un archivo
    // faltante o un SVG mal formado — usa el mismo `BytesLoader` que
    // `SvgPicture.asset` resuelve internamente (`SvgAssetLoader`), pero
    // esperando el resultado directamente en vez de depender de que el
    // widget reporte el error (no lo hace, ver comentario de arriba).
    testWidgets('la ruta real usada en producción carga sin lanzar', (
      tester,
    ) async {
      final bytes = await const SvgAssetLoader(
        'assets/branding/iconos.svg',
      ).loadBytes(null);
      expect(bytes.lengthInBytes, greaterThan(0));
    });

    testWidgets(
      'regresión: una ruta rota SÍ lanza (confirma que el test de arriba '
      'no pasaría igual con el asset roto)',
      (tester) async {
        expect(
          () => const SvgAssetLoader(
            'assets/branding/no-existe.svg',
          ).loadBytes(null),
          throwsA(anything),
        );
      },
    );
  });
}
