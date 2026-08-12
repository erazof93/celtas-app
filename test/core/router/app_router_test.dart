import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/shared/widgets/celtas_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Overrides comunes: auth fake + Home sin requests reales (banners y menú
  /// vacíos — el Home real los carga del backend).
  List<Override> overrides(
    MockAuthRepository repository, {
    List<PublicMenuCategory> menu = const [],
  }) => [
        authRepositoryProvider.overrideWithValue(repository),
        activeBannersProvider.overrideWith((ref) async => const []),
        publicMenuProvider.overrideWith((ref) async => menu),
      ];

  /// Login rápido de punta a punta (Splash → Login → sesión activa).
  Future<void> login(
    WidgetTester tester,
    MockAuthRepository repository, {
    List<PublicMenuCategory> menu = const [],
  }) async {
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
        overrides: overrides(repository, menu: menu),
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
    expect(find.text('Entregar en'), findsOneWidget);
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
    expect(find.text('Entregar en'), findsOneWidget);
  });

  testWidgets('ruta protegida sin sesión → redirige a /login', (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(repository),
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
        overrides: overrides(repository),
        child: const CeltasApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Autenticado directo → shell con bottom nav, tab Inicio activo.
    expect(find.byType(CeltasBottomNav), findsOneWidget);
    expect(activeTabIndex(tester), 0);
    expect(find.text('Entregar en'), findsOneWidget);
    expect(find.text('COMENZAR'), findsNothing);
    expect(find.text('Bienvenido de nuevo'), findsNothing);
  });

  testWidgets('logout → vuelve al Login (onboarding)', (tester) async {
    final repository = MockAuthRepository();
    await login(tester, repository);
    when(() => repository.signOutFromGoogle()).thenAnswer((_) async {});
    when(() => repository.clearRefreshToken()).thenAnswer((_) async {});

    expect(find.text('Entregar en'), findsOneWidget);

    // Logout (el botón vive en Perfil, módulo 6; acá se invoca el controller
    // para cubrir la regresión del router) → sin sesión → redirige a /login.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CeltasApp)),
    );
    await container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byType(CeltasBottomNav), findsNothing);
    expect(find.text('Entregar en'), findsNothing);
  });

  testWidgets('tocar una tarjeta de producto → detalle de producto',
      (tester) async {
    final repository = MockAuthRepository();
    await login(tester, repository, menu: [
      const PublicMenuCategory(
        id: 'c-1',
        name: 'Hamburguesa',
        items: [
          PublicMenuItem(
            id: 'i-1',
            name: 'Berserker Burger',
            price: 15.5,
          ),
        ],
      ),
    ]);

    await tester.tap(find.text('Berserker Burger'));
    await tester.pumpAndSettle();

    // Detalle: nombre + selector de cantidad + botón con precio.
    expect(find.text('Berserker Burger'), findsOneWidget);
    expect(find.text('CANTIDAD'), findsOneWidget);
    expect(find.text('AGREGAR AL CARRITO · S/ 15.50'), findsOneWidget);
    // Sin bottom nav en el detalle (pantalla completa sobre el shell).
    expect(find.byType(CeltasBottomNav), findsNothing);
  });

  testWidgets('ícono de carrito del header → pantalla de carrito',
      (tester) async {
    final repository = MockAuthRepository();
    await login(tester, repository);

    await tester.tap(find.byKey(const ValueKey('home-cart-icon')));
    await tester.pumpAndSettle();

    expect(find.text('Tu carrito'), findsOneWidget);
    expect(find.byType(CeltasBottomNav), findsNothing);
  });

  testWidgets('rutas /product/:id y /cart sin sesión → redirigen a /login',
      (tester) async {
    final repository = MockAuthRepository();
    when(() => repository.readRefreshToken()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(repository),
        child: const CeltasApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CeltasApp)),
    );

    container.read(routerProvider).go('/product/i-1');
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byType(CeltasBottomNav), findsNothing);

    container.read(routerProvider).go('/cart');
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.byType(CeltasBottomNav), findsNothing);
  });

  group('doble-atrás para salir', () {
    // Todas las rutas empujadas (carrito, checkout, detalle, direcciones)
    // viven top-level SOBRE el shell (ver comentario de `_ShellScaffold`),
    // así que el `PopScope` de doble-atrás solo puede dispararse cuando el
    // shell es la ruta visible — se prueba explícitamente que una pantalla
    // empujada encima no lo activa.
    late List<MethodCall> platformCalls;

    setUp(() {
      platformCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    bool exited() =>
        platformCalls.any((c) => c.method == 'SystemNavigator.pop');

    testWidgets(
        'primer back en el shell → muestra aviso, no sale de la app',
        (tester) async {
      final repository = MockAuthRepository();
      await login(tester, repository);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('Presiona de nuevo para salir'), findsOneWidget);
      expect(exited(), isFalse);
      // Sigue en el shell, Home no se desmontó.
      expect(find.byType(CeltasBottomNav), findsOneWidget);
      expect(find.text('Entregar en'), findsOneWidget);
    });

    testWidgets(
        'segundo back dentro de la ventana de confirmación → sale de la app',
        (tester) async {
      final repository = MockAuthRepository();
      await login(tester, repository);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exited(), isTrue);
    });

    testWidgets(
        'back funciona igual en cualquier tab del shell (no solo Inicio)',
        (tester) async {
      final repository = MockAuthRepository();
      await login(tester, repository);

      await tester.tap(find.descendant(
        of: find.byType(CeltasBottomNav),
        matching: find.text('Cupones'),
      ));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exited(), isTrue);
    });

    testWidgets(
        'back con una pantalla empujada sobre el shell (carrito) → pop '
        'normal, sin aviso de salida', (tester) async {
      final repository = MockAuthRepository();
      await login(tester, repository);

      await tester.tap(find.byKey(const ValueKey('home-cart-icon')));
      await tester.pumpAndSettle();
      expect(find.text('Tu carrito'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Pop normal de /cart de vuelta al shell — nunca llegó al PopScope
      // del shell, así que no hay aviso ni salida.
      expect(find.text('Tu carrito'), findsNothing);
      expect(find.byType(CeltasBottomNav), findsOneWidget);
      expect(find.text('Presiona de nuevo para salir'), findsNothing);
      expect(exited(), isFalse);
    });

    testWidgets(
        'segundo back después de vencida la ventana de confirmación → '
        'vuelve a avisar, no sale', (tester) async {
      final repository = MockAuthRepository();
      await login(tester, repository);

      await tester.binding.handlePopRoute();
      await tester.pump();

      // Espera real (fuera de la zona de tiempo simulado de flutter_test,
      // que congela `Future.delayed` — el código de producción usa
      // `DateTime.now()` real, así que hace falta tiempo real de verdad)
      // más allá de la ventana de 2s de confirmación.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2, milliseconds: 200)),
      );

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exited(), isFalse);
      expect(find.text('Presiona de nuevo para salir'), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 15)));

    testWidgets(
        'cambiar de tab entre el primer y el segundo back NO resetea la '
        'ventana de confirmación (el State del shell persiste entre tabs; '
        'comportamiento no especificado, documentado acá para que un '
        'cambio futuro sea intencional, no accidental)', (tester) async {
      final repository = MockAuthRepository();
      await login(tester, repository);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Presiona de nuevo para salir'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(CeltasBottomNav),
        matching: find.text('Cupones'),
      ));
      await tester.pumpAndSettle();
      expect(activeTabIndex(tester), 2);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exited(), isTrue);
    });

    testWidgets(
        'logout tras un primer back sin confirmar, y login de nuevo → no '
        'arrastra la ventana previa (el State del shell se destruye al '
        'desmontarse fuera de la sesión)', (tester) async {
      final repository = MockAuthRepository();
      await login(tester, repository);
      when(() => repository.signOutFromGoogle()).thenAnswer((_) async {});
      when(() => repository.clearRefreshToken()).thenAnswer((_) async {});

      // Primer back sin confirmar: arma la ventana de 2s dentro del shell.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Presiona de nuevo para salir'), findsOneWidget);

      // Logout: el shell se desmonta (redirect a /login).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CeltasApp)),
      );
      await container.read(authControllerProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(find.byType(CeltasBottomNav), findsNothing);

      // Login de nuevo en la misma sesión de test (mismo widget tree): si
      // `_lastBackPressAt` hubiera sobrevivido en algún State reutilizado,
      // un solo back ahora saldría de la app en vez de mostrar el aviso.
      // El redirect tras logout manda directo a /login (no al onboarding
      // del Splash), como confirma el test "logout → vuelve al Login".
      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'cliente@celtas.pe',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pumpAndSettle();
      expect(find.byType(CeltasBottomNav), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(exited(), isFalse);
      expect(find.text('Presiona de nuevo para salir'), findsOneWidget);
    });
  });
}
