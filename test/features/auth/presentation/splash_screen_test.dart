import 'dart:async';

import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/presentation/splash_screen.dart';
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
      'Splash muestra el aviso de backend lento si el bootstrap tarda '
      '(cold start de Render)', (tester) async {
    final repository = MockAuthRepository();
    // Bootstrap que nunca resuelve → el estado queda en `unknown`.
    when(() => repository.readRefreshToken())
        .thenAnswer((_) => Completer<String?>().future);

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

    // A los 5 segundos aparece el aviso (mismo patrón que celtas-admin).
    await tester.pump(const Duration(seconds: 5));
    expect(
      find.text('El servidor está despertando, puede tardar unos segundos…'),
      findsOneWidget,
    );
  });
}