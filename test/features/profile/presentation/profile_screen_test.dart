import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/notification_permission_repository.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/features/profile/application/profile_providers.dart';
import 'package:celtas_mobile/features/profile/data/profile_repository.dart';
import 'package:celtas_mobile/features/profile/presentation/profile_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationPermissionRepository extends Mock
    implements NotificationPermissionRepository {}

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  final user = User(
    id: 'user-1',
    email: 'ragnar@email.com',
    fullName: 'Ragnar Andersen',
    provider: UserProvider.local,
    phone: '+51 999 999 999',
    totalSpent: 0,
    role: UserRole.cliente,
    createdAt: DateTime.utc(2026, 1, 15),
    updatedAt: DateTime.utc(2026, 1, 15),
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  GoRouter router() => GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: '/addresses',
            builder: (_, _) => const Scaffold(body: Text('DIRECCIONES')),
          ),
          GoRoute(
            path: '/coupons',
            builder: (_, _) => const Scaffold(body: Text('CUPONES')),
          ),
          GoRoute(
            path: '/orders',
            builder: (_, _) => const Scaffold(body: Text('PEDIDOS')),
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const Scaffold(body: Text('LOGIN')),
          ),
        ],
      );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required MockProfileRepository profileRepository,
    MockAuthRepository? authRepository,
    MockNotificationPermissionRepository? notificationPermissionRepository,
  }) async {
    final authRepo = authRepository ?? MockAuthRepository();
    when(() => authRepo.readRefreshToken()).thenAnswer((_) async => null);

    // Default: ya autorizado, para no afectar los tests que no le importa
    // el estado del permiso de notificaciones.
    final notificationPermissionRepo =
        notificationPermissionRepository ??
        MockNotificationPermissionRepository();
    if (notificationPermissionRepository == null) {
      when(
        () => notificationPermissionRepo.getStatus(),
      ).thenAnswer((_) async => AuthorizationStatus.authorized);
    }

    // `logout()` llama `clearFcmToken()` (DELETE /users/me/fcm-token) — sin
    // este override golpearía la red real en el test de "Cerrar sesión".
    final notificationRepo = MockNotificationRepository();
    when(() => notificationRepo.clearFcmToken()).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepository),
        authRepositoryProvider.overrideWithValue(authRepo),
        notificationPermissionRepositoryProvider.overrideWithValue(
          notificationPermissionRepo,
        ),
        notificationRepositoryProvider.overrideWithValue(notificationRepo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('muestra nombre, email, teléfono e iniciales del avatar',
      (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => user);

    await pumpScreen(tester, profileRepository: repository);

    expect(find.text('Ragnar Andersen'), findsOneWidget);
    expect(find.text('ragnar@email.com'), findsOneWidget);
    expect(find.text('+51 999 999 999'), findsOneWidget);
    expect(find.text('RA'), findsOneWidget);
  });

  testWidgets('error al cargar → mensaje real y REINTENTAR', (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile())
        .thenThrow(const ApiException('No se pudo conectar'));

    await pumpScreen(tester, profileRepository: repository);

    expect(find.text('No se pudo conectar'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('editar perfil → PATCH con fullName/phone, el email no se envía',
      (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => user);
    final updated = user.copyWith(fullName: 'Ragnar Lodbrok', phone: '+51 1');
    when(() => repository.updateProfile(
          fullName: 'Ragnar Lodbrok',
          phone: '+51 1',
        )).thenAnswer((_) async => updated);

    await pumpScreen(tester, profileRepository: repository);

    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();

    // El email se muestra de solo lectura, no como campo editable.
    expect(find.text('El email no se puede editar'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-fullname')),
      'Ragnar Lodbrok',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-phone')),
      '+51 1',
    );
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();

    verify(() => repository.updateProfile(
          fullName: 'Ragnar Lodbrok',
          phone: '+51 1',
        )).called(1);
    expect(find.text('Ragnar Lodbrok'), findsOneWidget);
  });

  testWidgets('error del backend al guardar → mensaje real, formulario sigue abierto',
      (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => user);
    when(() => repository.updateProfile(
          fullName: any(named: 'fullName'),
          phone: any(named: 'phone'),
        )).thenThrow(const ApiException('El teléfono es inválido'));

    await pumpScreen(tester, profileRepository: repository);

    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();

    expect(find.text('El teléfono es inválido'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-fullname')), findsOneWidget);
  });

  testWidgets('Direcciones guardadas → navega a /addresses', (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => user);

    await pumpScreen(tester, profileRepository: repository);

    await tester.tap(find.byKey(const ValueKey('profile-menu-addresses')));
    await tester.pumpAndSettle();

    expect(find.text('DIRECCIONES'), findsOneWidget);
  });

  testWidgets('Mis cupones → navega a /coupons', (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => user);

    await pumpScreen(tester, profileRepository: repository);

    await tester.tap(find.byKey(const ValueKey('profile-menu-coupons')));
    await tester.pumpAndSettle();

    expect(find.text('CUPONES'), findsOneWidget);
  });

  testWidgets('Cerrar sesión → confirma, cierra sesión real y navega a Login',
      (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => user);
    final authRepo = MockAuthRepository();
    when(() => authRepo.signOutFromGoogle()).thenAnswer((_) async {});
    when(() => authRepo.clearRefreshToken()).thenAnswer((_) async {});

    final container = await pumpScreen(
      tester,
      profileRepository: repository,
      authRepository: authRepo,
    );

    await tester.tap(find.byKey(const ValueKey('profile-menu-logout')));
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(find.text('CERRAR SESIÓN'));
    await tester.pumpAndSettle();

    verify(() => authRepo.signOutFromGoogle()).called(1);
    verify(() => authRepo.clearRefreshToken()).called(1);
    // La navegación a /login la hace el redirect del router real (ya
    // cubierto en app_router_test.dart); acá solo verificamos que el
    // controller de sesión pasó a unauthenticated.
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  testWidgets('Cerrar sesión → cancelar no cierra la sesión', (tester) async {
    final repository = MockProfileRepository();
    when(() => repository.getProfile()).thenAnswer((_) async => user);
    final authRepo = MockAuthRepository();

    await pumpScreen(
      tester,
      profileRepository: repository,
      authRepository: authRepo,
    );

    await tester.tap(find.byKey(const ValueKey('profile-menu-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    verifyNever(() => authRepo.signOutFromGoogle());
    expect(find.text('LOGIN'), findsNothing);
  });

  group('Renglón de notificaciones', () {
    testWidgets('authorized → muestra "Activadas"', (tester) async {
      final repository = MockProfileRepository();
      when(() => repository.getProfile()).thenAnswer((_) async => user);
      final permissionRepo = MockNotificationPermissionRepository();
      when(
        () => permissionRepo.getStatus(),
      ).thenAnswer((_) async => AuthorizationStatus.authorized);

      await pumpScreen(
        tester,
        profileRepository: repository,
        notificationPermissionRepository: permissionRepo,
      );

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Activadas'), findsOneWidget);
    });

    testWidgets('denied → muestra "Desactivadas"', (tester) async {
      final repository = MockProfileRepository();
      when(() => repository.getProfile()).thenAnswer((_) async => user);
      final permissionRepo = MockNotificationPermissionRepository();
      when(
        () => permissionRepo.getStatus(),
      ).thenAnswer((_) async => AuthorizationStatus.denied);

      await pumpScreen(
        tester,
        profileRepository: repository,
        notificationPermissionRepository: permissionRepo,
      );

      expect(find.text('Desactivadas'), findsOneWidget);
    });

    testWidgets(
      'notDetermined → tocar el renglón dispara requestPermission(), '
      'NUNCA openSystemSettings()',
      (tester) async {
        final repository = MockProfileRepository();
        when(() => repository.getProfile()).thenAnswer((_) async => user);
        final permissionRepo = MockNotificationPermissionRepository();
        var calls = 0;
        when(() => permissionRepo.getStatus()).thenAnswer((_) async {
          calls++;
          // Primera consulta (build inicial): notDetermined. Tras el tap,
          // handleTap() nunca asume el resultado de requestPermission() —
          // vuelve a preguntar el estado real (refresh()), que ya debe
          // reflejar el cambio.
          return calls == 1
              ? AuthorizationStatus.notDetermined
              : AuthorizationStatus.authorized;
        });
        when(
          () => permissionRepo.requestPermission(),
        ).thenAnswer((_) async => AuthorizationStatus.authorized);

        await pumpScreen(
          tester,
          profileRepository: repository,
          notificationPermissionRepository: permissionRepo,
        );

        await tester.tap(
          find.byKey(const ValueKey('profile-notifications-tap')),
        );
        await tester.pumpAndSettle();

        verify(() => permissionRepo.requestPermission()).called(1);
        verifyNever(() => permissionRepo.openSystemSettings());
        expect(calls, 2);
        // Refrescó tras el pedido: ahora muestra el estado real nuevo.
        expect(find.text('Activadas'), findsOneWidget);
      },
    );

    testWidgets(
      'denied → tocar el renglón abre Configuración del sistema, NUNCA '
      'vuelve a llamar requestPermission() (el diálogo nativo ya no '
      'aparece una vez rechazado)',
      (tester) async {
        final repository = MockProfileRepository();
        when(() => repository.getProfile()).thenAnswer((_) async => user);
        final permissionRepo = MockNotificationPermissionRepository();
        when(
          () => permissionRepo.getStatus(),
        ).thenAnswer((_) async => AuthorizationStatus.denied);
        when(
          () => permissionRepo.openSystemSettings(),
        ).thenAnswer((_) async => true);

        await pumpScreen(
          tester,
          profileRepository: repository,
          notificationPermissionRepository: permissionRepo,
        );

        await tester.tap(
          find.byKey(const ValueKey('profile-notifications-tap')),
        );
        await tester.pumpAndSettle();

        verify(() => permissionRepo.openSystemSettings()).called(1);
        verifyNever(() => permissionRepo.requestPermission());
      },
    );

    testWidgets(
      'authorized → tocar el renglón no llama a request ni a openSettings',
      (tester) async {
        final repository = MockProfileRepository();
        when(() => repository.getProfile()).thenAnswer((_) async => user);
        final permissionRepo = MockNotificationPermissionRepository();
        when(
          () => permissionRepo.getStatus(),
        ).thenAnswer((_) async => AuthorizationStatus.authorized);

        await pumpScreen(
          tester,
          profileRepository: repository,
          notificationPermissionRepository: permissionRepo,
        );

        await tester.tap(
          find.byKey(const ValueKey('profile-notifications-tap')),
        );
        await tester.pumpAndSettle();

        verifyNever(() => permissionRepo.requestPermission());
        verifyNever(() => permissionRepo.openSystemSettings());
      },
    );

    testWidgets(
      'AppLifecycleState.resumed reconsulta el estado real (por si el '
      'usuario lo cambió desde Configuración sin reiniciar la app)',
      (tester) async {
        final repository = MockProfileRepository();
        when(() => repository.getProfile()).thenAnswer((_) async => user);
        final permissionRepo = MockNotificationPermissionRepository();
        var calls = 0;
        when(() => permissionRepo.getStatus()).thenAnswer((_) async {
          calls++;
          // Primera consulta: desactivadas. El usuario "se fue a
          // Configuración y las activó" — la segunda consulta (tras
          // resumed) ya debe reflejar el cambio real.
          return calls == 1
              ? AuthorizationStatus.denied
              : AuthorizationStatus.authorized;
        });

        await pumpScreen(
          tester,
          profileRepository: repository,
          notificationPermissionRepository: permissionRepo,
        );

        expect(find.text('Desactivadas'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(calls, 2);
        expect(find.text('Activadas'), findsOneWidget);
        expect(find.text('Desactivadas'), findsNothing);
      },
    );
  });
}
