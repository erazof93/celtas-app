import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/shared/widgets/celtas_bottom_nav.dart';
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

  /// Login rápido de punta a punta (Splash → Login → sesión activa).
  Future<void> login(WidgetTester tester, MockAuthRepository repository) async {
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

    await tester.tap(find.text('COMENZAR'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'cliente@celtas.pe',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pumpAndSettle();
  }

  /// Índice del tab activo en el `IndexedStack` del shell.
  int? activeTabIndex(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

  testWidgets(
      'login exitoso → shell con bottom nav y NO vuelve al Splash '
      '(regresión: el router se recreaba en cada cambio de auth)', (tester) async {
    final repository = MockAuthRepository();
    await login(tester, repository);

    // Autenticado → shell con bottom nav persistente, tab Inicio activo.
    expect(find.byType(CeltasBottomNav), findsOneWidget);
    expect(activeTabIndex(tester), 0);
    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('Cliente de Prueba'), findsOneWidget);
    // NO debe volver al Splash.
    expect(find.text('COMENZAR'), findsNothing);
  });

  testWidgets('bottom nav con los 4 tabs y navegación entre ellos',
      (tester) async {
    final repository = MockAuthRepository();
    await login(tester, repository);

    // Los 4 labels están en el bottom nav.
    for (final label in ['Inicio', 'Pedidos', 'Cupones', 'Perfil']) {
      expect(
        find.descendant(
          of: find.byType(CeltasBottomNav),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }

    // Inicio → Pedidos.
    await tester.tap(find.descendant(
      of: find.byType(CeltasBottomNav),
      matching: find.text('Pedidos'),
    ));
    await tester.pumpAndSettle();
    expect(activeTabIndex(tester), 1);

    // Pedidos → Cupones.
    await tester.tap(find.descendant(
      of: find.byType(CeltasBottomNav),
      matching: find.text('Cupones'),
    ));
    await tester.pumpAndSettle();
    expect(activeTabIndex(tester), 2);

    // Cupones → Perfil.
    await tester.tap(find.descendant(
      of: find.byType(CeltasBottomNav),
      matching: find.text('Perfil'),
    ));
    await tester.pumpAndSettle();
    expect(activeTabIndex(tester), 3);

    // Perfil → Inicio (vuelta al primer tab).
    await tester.tap(find.descendant(
      of: find.byType(CeltasBottomNav),
      matching: find.text('Inicio'),
    ));
    await tester.pumpAndSettle();
    expect(activeTabIndex(tester), 0);
    expect(find.text('Sesión iniciada'), findsOneWidget);
  });

  testWidgets('ruta protegida sin sesión → redirige a /login', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const CeltasApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Sin sesión: el Splash muestra el onboarding.
    expect(find.text('COMENZAR'), findsOneWidget);

    // Intentar navegar a una ruta del shell sin sesión → /login.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CeltasApp)),
    );
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byType(CeltasBottomNav), findsNothing);
  });

  testWidgets(
      'sesión persistida al reabrir la app → vuelve al shell, no al '
      'Splash/Login', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => 'refresh-1');
    when(() => repository.refresh('refresh-1')).thenAnswer((_) async => tokens);
    when(() => repository.saveRefreshToken('refresh-1'))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const CeltasApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Autenticado directo → shell con bottom nav, tab Inicio activo.
    expect(find.byType(CeltasBottomNav), findsOneWidget);
    expect(activeTabIndex(tester), 0);
    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('COMENZAR'), findsNothing);
    expect(find.text('Bienvenido de nuevo'), findsNothing);
  });

  testWidgets('logout desde /home → vuelve al Login (onboarding)',
      (tester) async {
    final repository = MockAuthRepository();
    await login(tester, repository);
    when(() => repository.signOutFromGoogle()).thenAnswer((_) async {});
    when(() => repository.clearRefreshToken()).thenAnswer((_) async {});

    expect(find.text('Sesión iniciada'), findsOneWidget);

    // Logout → sin sesión → el router refresca y redirige a /login.
    await tester.tap(find.text('CERRAR SESIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byType(CeltasBottomNav), findsNothing);
    expect(find.text('Sesión iniciada'), findsNothing);
  });
}