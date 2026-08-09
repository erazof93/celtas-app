import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final tokens = AuthTokens(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    user: User(
      id: 'user-1',
      email: 'cliente@celtas.pe',
      fullName: 'Cliente de Prueba',
      provider: UserProvider.local,
      totalSpent: 0,
      role: UserRole.cliente,
      createdAt: DateTime.utc(2026, 1, 15),
      updatedAt: DateTime.utc(2026, 1, 15),
    ),
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  testWidgets(
      'login exitoso → navega a /home y NO vuelve al Splash '
      '(regresión: el router se recreaba en cada cambio de auth)', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => tokens);
    when(() => repository.saveRefreshToken('refresh-1'))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const CeltasApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Splash (sin sesión) → COMENZAR → Login.
    expect(find.text('COMENZAR'), findsOneWidget);
    await tester.tap(find.text('COMENZAR'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);

    // Login tradicional.
    await tester.enterText(find.byType(TextFormField).at(0), 'cliente@celtas.pe');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pumpAndSettle();

    // Autenticado → /home (placeholder con "Sesión iniciada").
    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('Cliente de Prueba'), findsOneWidget);
    // NO debe volver al Splash.
    expect(find.text('COMENZAR'), findsNothing);
  });

  testWidgets('logout desde /home → vuelve al Splash (onboarding)',
      (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => tokens);
    when(() => repository.saveRefreshToken('refresh-1'))
        .thenAnswer((_) async {});
    when(() => repository.signOutFromGoogle()).thenAnswer((_) async {});
    when(() => repository.clearRefreshToken()).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const CeltasApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Login rápido.
    await tester.tap(find.text('COMENZAR'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'cliente@celtas.pe');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pumpAndSettle();
    expect(find.text('Sesión iniciada'), findsOneWidget);

    // Logout → sin sesión → el router refresca y redirige a /login.
    await tester.tap(find.text('CERRAR SESIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Sesión iniciada'), findsNothing);
  });
}