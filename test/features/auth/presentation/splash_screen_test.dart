import 'dart:async';

import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/presentation/splash_screen.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    // Sin red en tests: GoogleFonts usa la fuente de respaldo.
    GoogleFonts.config.allowRuntimeFetching = false;
    // `AuthController.build()` registra `ApiClient.instance.session`, y el
    // singleton lee `AppConfig.apiBaseUrl` de `flutter_dotenv`.
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  testWidgets(
    'Splash limita almacenamiento pendiente y permite reintento único',
    (tester) async {
      final repository = MockAuthRepository();
      // Bootstrap que nunca resuelve → el estado queda en `unknown`.
      var reads = 0;
      when(() => repository.readRefreshToken()).thenAnswer((_) {
        reads++;
        return Completer<String?>().future;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(theme: AppTheme.dark, home: const SplashScreen()),
        ),
      );

      // Bootstrap en curso: spinner, sin aviso todavía.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('El servidor está despertando, puede tardar unos segundos…'),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 20));
      expect(
        find.text('El servidor está despertando, puede tardar unos segundos…'),
        findsNothing,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final retry = tester
          .widget<CeltasButton>(find.byType(CeltasButton))
          .onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(reads, 2);
      expect(
        tester.widget<CeltasButton>(find.byType(CeltasButton)).onPressed,
        isNull,
      );
      expect(find.text('Restaurando tu sesión…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
