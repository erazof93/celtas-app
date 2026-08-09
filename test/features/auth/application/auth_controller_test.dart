import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  final user = User(
    id: 'user-1',
    email: 'cliente@celtas.pe',
    fullName: 'Cliente de Prueba',
    provider: UserProvider.local,
    phone: '+51999999999',
    totalSpent: 128.5,
    role: UserRole.cliente,
    createdAt: DateTime.utc(2026, 1, 15, 10, 30),
    updatedAt: DateTime.utc(2026, 2, 1, 8),
  );

  setUpAll(() {
    // `AuthController.build()` registra `ApiClient.instance.session`, y el
    // singleton lee `AppConfig.apiBaseUrl` de `flutter_dotenv` al construirse.
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    repository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  /// `AuthController.build()` agenda `bootstrap()` en un microtask; este helper
  /// deja que corra antes de inspeccionar el estado.
  Future<void> pumpBootstrap() async {
    container.read(authControllerProvider);
    await pumpEventQueue();
  }

  DioException dio401() {
    final options = RequestOptions(path: '/auth/refresh');
    return DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
  }

  group('bootstrap — sin refresh token guardado', () {
    test('refreshToken null → estado unauthenticated', () async {
      when(() => repository.readRefreshToken()).thenAnswer((_) async => null);

      await pumpBootstrap();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(state.accessToken, isNull);
      verifyNever(() => repository.refresh(any()));
    });

    test('refreshToken vacío → estado unauthenticated', () async {
      when(() => repository.readRefreshToken()).thenAnswer((_) async => '');

      await pumpBootstrap();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      verifyNever(() => repository.refresh(any()));
    });
  });

  group('bootstrap — con refresh token guardado', () {
    test('refresh exitoso → estado authenticated con accessToken en memoria',
        () async {
      final tokens = AuthTokens(
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
        user: user,
      );
      when(() => repository.readRefreshToken())
          .thenAnswer((_) async => 'refresh-old');
      when(() => repository.refresh('refresh-old'))
          .thenAnswer((_) async => tokens);
      when(() => repository.saveRefreshToken('refresh-new'))
          .thenAnswer((_) async {});

      await pumpBootstrap();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.accessToken, 'access-new');
      expect(state.user, user);
      // Rotación: el refresh token nuevo emitido por el backend se persiste.
      verify(() => repository.saveRefreshToken('refresh-new')).called(1);
    });

    test('refresh responde 401 definitivo → limpia sesión y queda sin sesión',
        () async {
      when(() => repository.readRefreshToken())
          .thenAnswer((_) async => 'refresh-old');
      when(() => repository.refresh('refresh-old')).thenThrow(dio401());
      when(() => repository.clearRefreshToken()).thenAnswer((_) async {});

      await pumpBootstrap();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      verify(() => repository.clearRefreshToken()).called(1);
    });

    test('error transitorio (red) → estado error y NO limpia la sesión',
        () async {
      when(() => repository.readRefreshToken())
          .thenAnswer((_) async => 'refresh-old');
      when(() => repository.refresh('refresh-old')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.connectionError,
        ),
      );

      await pumpBootstrap();

      expect(container.read(authControllerProvider).status, AuthStatus.error);
      verifyNever(() => repository.clearRefreshToken());
    });
  });

  group('login / logout', () {
    test('login exitoso → persiste refreshToken y queda authenticated', () async {
      final tokens = AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        user: user,
      );
      // `build()` agenda `bootstrap()` en un microtask; sin refresh token
      // guardado termina en unauthenticated antes de que corra el login.
      when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
      when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => tokens);
      when(() => repository.saveRefreshToken('refresh-1'))
          .thenAnswer((_) async {});

      await container.read(authControllerProvider.notifier).login(
            email: 'cliente@celtas.pe',
            password: 'secret',
          );

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.accessToken, 'access-1');
      expect(state.user, user);
      verify(() => repository.saveRefreshToken('refresh-1')).called(1);
    });

    test('logout → limpia refreshToken y queda sin sesión', () async {
      when(() => repository.readRefreshToken()).thenAnswer((_) async => null);
      when(() => repository.clearRefreshToken()).thenAnswer((_) async {});

      await container.read(authControllerProvider.notifier).logout();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      verify(() => repository.clearRefreshToken()).called(1);
    });
  });
}