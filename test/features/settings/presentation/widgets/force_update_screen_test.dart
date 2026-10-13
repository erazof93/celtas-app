import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Fake del canal de plataforma de `url_launcher` — mismo criterio que
/// `FakeUrlLauncherPlatform` de `checkout_screen_test.dart`: sin esto,
/// `launchUrl` lanza `MissingPluginException` en widget tests.
class FakeUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  bool launchResult = true;
  Object? launchThrows;
  String? lastLaunchedUrl;
  LaunchOptions? lastLaunchOptions;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    lastLaunchOptions = options;
    final error = launchThrows;
    if (error != null) throw error;
    return launchResult;
  }
}

/// Pantalla obligatoria y contrato del launcher, sin servicios externos.
void main() {
  late FakeUrlLauncherPlatform fakeUrlLauncher;
  late UrlLauncherPlatform originalLauncher;

  setUp(() {
    originalLauncher = UrlLauncherPlatform.instance;
    fakeUrlLauncher = FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  tearDown(() => UrlLauncherPlatform.instance = originalLauncher);

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? minVersion = '1.2.0+30',
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: ForceUpdateScreen(minVersion: minVersion)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el título y el mensaje obligatorio de actualización', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Tu app está desactualizada'), findsOneWidget);
    expect(
      find.text('Necesitas actualizar Celtas para seguir usando la app.'),
      findsOneWidget,
    );
    expect(find.text('Abrir Play Store'), findsOneWidget);
  });

  testWidgets(
    'minVersion "1.2.0+30" → muestra solo la parte X.Y.Z, nunca el build',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('Versión requerida: 1.2.0'), findsOneWidget);
      expect(find.textContaining('+30'), findsNothing);
    },
  );

  testWidgets('minVersion null → no muestra la línea de versión requerida', (
    tester,
  ) async {
    await pumpScreen(tester, minVersion: null);

    expect(find.textContaining('Versión requerida'), findsNothing);
  });

  testWidgets(
    'tap en "Abrir Play Store" con éxito: llama launchUrl con la URL real de '
    'la ficha, modo externo, sin mostrar mensaje de error',
    (tester) async {
      fakeUrlLauncher.launchResult = true;
      await pumpScreen(tester);

      await tester.tap(find.text('Abrir Play Store'));
      await tester.pumpAndSettle();

      expect(
        fakeUrlLauncher.lastLaunchedUrl,
        'https://play.google.com/store/apps/details?id=com.celtas.celtas_mobile',
      );
      expect(
        fakeUrlLauncher.lastLaunchOptions?.mode,
        PreferredLaunchMode.externalApplication,
      );
      expect(find.textContaining('No se pudo abrir Play Store'), findsNothing);
      // Abrir la tienda no retira la pantalla obligatoria.
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
    },
  );

  testWidgets(
    'launchUrl devuelve false (sin app que resuelva el intent) → mensaje de '
    'error claro, sin crash, diálogo sigue abierto',
    (tester) async {
      fakeUrlLauncher.launchResult = false;
      await pumpScreen(tester);

      await tester.tap(find.text('Abrir Play Store'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo abrir Play Store'),
        findsOneWidget,
      );
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
    },
  );

  testWidgets(
    'launchUrl lanza PlatformException → mismo mensaje de error, sin crash',
    (tester) async {
      fakeUrlLauncher.launchThrows = PlatformException(
        code: 'ACTIVITY_NOT_FOUND',
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Abrir Play Store'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo abrir Play Store'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PopScope: canPop es false — el botón atrás/gesto del sistema no puede '
    'descartar el diálogo por su cuenta',
    (tester) async {
      await pumpScreen(tester);

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      // Simulación real del botón atrás del sistema (Android): debe seguir
      // presente, no solo por la propiedad declarada sino por el
      // comportamiento real de `Navigator.maybePop`.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
    },
  );

  testWidgets('tocar fuera del contenido no retira la pantalla obligatoria', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Toca una esquina, fuera del contenido.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(ForceUpdateScreen), findsOneWidget);
  });
}
