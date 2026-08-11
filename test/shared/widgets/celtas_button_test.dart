import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Placeholder del mismo tamaño que `_WhatsappIcon` (19x19) en
/// `checkout_screen.dart` — no importa el ícono real (es privado al archivo),
/// solo que ocupa el mismo ancho dentro del `Row` del botón.
class _IconPlaceholder extends StatelessWidget {
  const _IconPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 19);
}

Widget _wrap(Widget child) {
  return ProviderScopeless(child: child);
}

/// Envoltorio mínimo (`MaterialApp` + tema real) sin depender de Riverpod,
/// ya que `CeltasButton` no lee ningún provider.
class ProviderScopeless extends StatelessWidget {
  const ProviderScopeless({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CeltasButton — regresión de overflow en pantallas reales angostas', () {
    // Reproduce el ancho lógico de un Xiaomi real (1080px físicos, dpr 3.0 →
    // 360dp lógicos) donde se encontró el bug en la auditoría del módulo 10:
    // el label completo del CTA de checkout se cortaba con ellipsis a 15px.
    Future<void> pumpAtRealisticWidth(
      WidgetTester tester,
      Widget button,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          Padding(
            // Mismo padding horizontal de 24px del contenedor real en
            // `checkout_screen.dart` alrededor del `CeltasButton`.
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: button,
          ),
        ),
      );
    }

    testWidgets(
      'CONFIRMAR PEDIDO POR WHATSAPP con ícono no produce overflow de RenderFlex',
      (tester) async {
        await pumpAtRealisticWidth(
          tester,
          CeltasButton(
            angled: true,
            label: 'CONFIRMAR PEDIDO POR WHATSAPP',
            icon: const _IconPlaceholder(),
            onPressed: () {},
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.text('CONFIRMAR PEDIDO POR WHATSAPP'),
          findsOneWidget,
        );
      },
    );

    testWidgets('botón con ícono usa fontSize 14 (fix del overflow)', (
      tester,
    ) async {
      await pumpAtRealisticWidth(
        tester,
        CeltasButton(
          angled: true,
          label: 'CONFIRMAR PEDIDO POR WHATSAPP',
          icon: const _IconPlaceholder(),
          onPressed: () {},
        ),
      );

      final text = tester.widget<Text>(
        find.text('CONFIRMAR PEDIDO POR WHATSAPP'),
      );
      expect(text.style?.fontSize, 14);

      // El otro cambio del fix: padding horizontal 24→16 cuando hay ícono,
      // para dejarle más ancho disponible al label.
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CeltasButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final padding = container.padding as EdgeInsets?;
      expect(padding?.horizontal, 32); // 16 a cada lado
    });

    testWidgets('botón sin ícono conserva fontSize 16 y padding 24 (sin regresión)', (
      tester,
    ) async {
      await pumpAtRealisticWidth(
        tester,
        CeltasButton(label: 'CONTINUAR', onPressed: () {}),
      );

      final text = tester.widget<Text>(find.text('CONTINUAR'));
      expect(text.style?.fontSize, 16);
      expect(tester.takeException(), isNull);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CeltasButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final padding = container.padding as EdgeInsets?;
      expect(padding?.horizontal, 48); // 24 a cada lado
    });
  });

  // NOTA (riesgo documentado, no un bug): no existe una aserción
  // automatizada de que el texto NO se corte con ellipsis en un ancho de
  // pantalla real (`RenderParagraph.didExceedMaxLines`). Se intentó durante
  // esta auditoría y resultó en falsos positivos/negativos no confiables:
  // `flutter test` no carga las fuentes reales (`Manrope`/`Cinzel` vía
  // `google_fonts`) sin tooling adicional (ej. `golden_toolkit` o cargar los
  // assets de fuente a mano), así que el ancho medido del texto en el
  // entorno de test no coincide con el ancho real en dispositivo — la
  // prueba fallaba incluso con el fix ya aplicado, en anchos más generosos
  // que cualquier teléfono real. La única verificación fiable de "no se
  // corta" sigue siendo la inspección visual en dispositivo real, ya hecha
  // en la auditoría del módulo 10. Este archivo cubre lo que SÍ es
  // determinístico y no depende de fuentes: los valores exactos de
  // `fontSize`/padding que integran el fix, y que el `Row` no truena con
  // una excepción real de overflow.
}
