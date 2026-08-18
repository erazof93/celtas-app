import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/celtas_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// `Scaffold` con un botón que llama a `showCeltasSnackBar` SIN pasar
  /// `backgroundColor`/`duration`/`margin` — a propósito, para que el caso
  /// "default" ejercite de verdad los valores por default reales de la
  /// función (no un eco de ellos armado en el propio test, que no detectaría
  /// un cambio de default en `celtas_snackbar.dart`).
  Widget wrapDefault(String message) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showCeltasSnackBar(context, message),
            child: const Text('mostrar'),
          ),
        ),
      ),
    );
  }

  /// Variante que sí pasa los tres argumentos opcionales explícitos, para
  /// probar que sobrescriben el default.
  Widget wrapCustom(
    String message, {
    required Color backgroundColor,
    required Duration duration,
    required EdgeInsets margin,
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showCeltasSnackBar(
              context,
              message,
              backgroundColor: backgroundColor,
              duration: duration,
              margin: margin,
            ),
            child: const Text('mostrar'),
          ),
        ),
      ),
    );
  }

  testWidgets('muestra el mensaje dentro de un SnackBar', (tester) async {
    await tester.pumpWidget(wrapDefault('Hola'));

    await tester.tap(find.text('mostrar'));
    await tester.pump();

    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text('Hola')),
      findsOneWidget,
    );
  });

  testWidgets(
    'usa el estilo por default: fondo CeltasColors.surface, floating, '
    '2 segundos, sin margen explícito',
    (tester) async {
      await tester.pumpWidget(wrapDefault('Hola'));

      await tester.tap(find.text('mostrar'));
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, CeltasColors.surface);
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.duration, const Duration(seconds: 2));
      expect(snackBar.margin, isNull);
    },
  );

  testWidgets(
    'backgroundColor, duration y margin pasados explícitamente sobrescriben '
    'el default',
    (tester) async {
      const customMargin = EdgeInsets.fromLTRB(16, 0, 16, 88);
      await tester.pumpWidget(
        wrapCustom(
          'Hola',
          backgroundColor: CeltasColors.gold,
          duration: const Duration(seconds: 5),
          margin: customMargin,
        ),
      );

      await tester.tap(find.text('mostrar'));
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, CeltasColors.gold);
      expect(snackBar.duration, const Duration(seconds: 5));
      expect(snackBar.margin, customMargin);
    },
  );

  testWidgets(
    'reemplaza un SnackBar visible en vez de apilarlo (hideCurrentSnackBar '
    'previo)',
    (tester) async {
      await tester.pumpWidget(wrapDefault('Primero'));

      await tester.tap(find.text('mostrar'));
      await tester.pump();
      expect(find.text('Primero'), findsOneWidget);

      await tester.tap(find.text('mostrar'));
      await tester.pump();

      // Un solo SnackBar en el árbol — el anterior se ocultó, no se apiló.
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );
}
