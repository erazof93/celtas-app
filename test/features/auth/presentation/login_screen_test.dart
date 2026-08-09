import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final tokens = AuthTokens(
    accessToken: 'access-google',
    refreshToken: 'refresh-google',
    user: User(
      id: 'user-google',
      email: 'cliente@gmail.com',
      fullName: 'Cliente Google',
      provider: UserProvider.google,
      totalSpent: 0,
      role: UserRole.cliente,
      createdAt: DateTime.utc(2026, 1, 15),
      updatedAt: DateTime.utc(2026, 1, 15),
    ),
  );

  setUpAll(() {
    // Sin red en tests: GoogleFonts usa la fuente de respaldo.
    GoogleFonts.config.allowRuntimeFetching = false;
    // `AuthController.build()` registra `ApiClient.instance.session`, y el
    // singleton lee `AppConfig.apiBaseUrl` de `flutter_dotenv`.
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  Future<void> pumpLogin(WidgetTester tester, MockAuthRepository repository) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(theme: AppTheme.dark, home: const LoginScreen()),
      ),
    );
  }

  testWidgets('botón de Google: al tocarlo muestra "Conectando con Google…" '
      'y llama al controller', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
    // Flujo colgado en el POST al backend: el estado de carga se mantiene.
    final completer = Completer<AuthTokens>();
    when(() => repository.loginWithGoogle())
        .thenAnswer((_) => completer.future);
    when(() => repository.saveRefreshToken(any())).thenAnswer((_) async {});

    await pumpLogin(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    expect(find.text('Conectando con Google…'), findsOneWidget);
    verify(() => repository.loginWithGoogle()).called(1);

    // Aviso de backend lento si el POST tarda (cold start de Render).
    await tester.pump(const Duration(seconds: 6));
    expect(
      find.text('El servidor está despertando, puede tardar unos segundos…'),
      findsOneWidget,
    );

    // Cierra el flujo para no dejar estado colgado en el test.
    completer.complete(tokens);
    await tester.pump();
    expect(find.text('Conectando con Google…'), findsNothing);
  });

  testWidgets('botón de Google: éxito → termina el estado de carga sin error',
      (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
    when(() => repository.loginWithGoogle()).thenAnswer((_) async => tokens);
    when(() => repository.saveRefreshToken('refresh-google'))
        .thenAnswer((_) async {});

    await pumpLogin(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Conectando con Google…'), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.textContaining('error', findRichText: true), findsNothing);
  });

  testWidgets('botón de Google: el usuario cierra el picker → NO muestra '
      'mensaje de error', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
    when(() => repository.loginWithGoogle())
        .thenThrow(const GoogleSignInCanceledException());

    await pumpLogin(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Conectando con Google…'), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.textContaining('error', findRichText: true), findsNothing);
  });

  testWidgets('botón de Google: 409 del backend → muestra el mensaje del '
      'backend', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
    when(() => repository.loginWithGoogle()).thenThrow(
      const ApiException(
        'Este correo ya está registrado con contraseña. '
        'Inicia sesión tradicional o usa "olvidé mi contraseña".',
        statusCode: 409,
      ),
    );

    await pumpLogin(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('ya está registrado con contraseña'),
      findsOneWidget,
    );
    expect(find.text('Conectando con Google…'), findsNothing);
  });

  testWidgets('botón de Google: error de red → mensaje de conexión claro',
      (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
    when(() => repository.loginWithGoogle()).thenThrow(
      const ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      ),
    );

    await pumpLogin(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('No se pudo conectar con el servidor'),
      findsOneWidget,
    );
  });
}