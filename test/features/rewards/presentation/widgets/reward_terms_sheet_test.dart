import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/rewards/presentation/widgets/reward_terms_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// `RewardTermsSheet` ("¿Cómo funciona el programa de Estrellas?"): copy
/// estático, sin datos del backend — pero el texto DEBE describir la regla
/// real de vigencia/limpieza mensual implementada en
/// `backend-celtas/src/modules/rewards/rewards.service.ts`
/// (`getEndOfMonthInLima` + filtro de mes para `redeemed`), no una
/// aproximación. Novena iteración: puntos 4 y 5 reescritos para reflejar esa
/// regla real (antes decían "vigencia de 15 días", que ya no es cierto).
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => RewardTermsSheet.show(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'punto 4: vigencia hasta fin de mes (ya NO "15 días")',
    (tester) async {
      await pumpSheet(tester);

      expect(
        find.text(
          'Cada premio es válido durante TODO el mes en que lo ganas. '
          'Tienes hasta el último día del mes para reclamarlo.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'punto 5: los premios NO reclamados pierden el derecho a canjearse al '
    'cambiar de mes; los YA RECLAMADOS quedan en el historial (invisibles '
    'en la app, pero en la BD)',
    (tester) async {
      await pumpSheet(tester);

      expect(
        find.text(
          'El 1º de cada mes, todo se reinicia. Los premios que no '
          'reclamaste desaparecen sin derecho a canjearse. Los premios YA '
          'RECLAMADOS quedan guardados en tu historial (invisibles en la '
          'app, pero en la BD).',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ninguna referencia a la vieja regla de "15 días" queda en el sheet',
    (tester) async {
      await pumpSheet(tester);

      expect(find.textContaining('15 días'), findsNothing);
    },
  );

  testWidgets(
    'los puntos 4 y 5 más largos no producen overflow — el sheet scrollea '
    'en vez de desbordar (regresión real: sin el `Flexible` + '
    '`SingleChildScrollView`, esto tiraba "RenderFlex overflowed by 38 '
    'pixels" en el viewport de test 800×600, no solo en teoría)',
    (tester) async {
      await pumpSheet(tester);

      expect(tester.takeException(), isNull);
    },
  );
}
