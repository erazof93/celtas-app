import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Fake de la plataforma de Google (API v2.x — compatible con google_sign_in
/// 6.x). Reemplaza el canal nativo para que `GoogleSignIn().signIn()` y
/// `.authentication` funcionen en tests sin dispositivo.
class FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  FakeGoogleSignInPlatform({this.idToken = 'google-id-token', this.error});

  final String? idToken;
  final Object? error;

  @override
  Future<void> init({
    List<String> scopes = const <String>[],
    SignInOption signInOption = SignInOption.standard,
    String? hostedDomain,
    String? clientId,
  }) async {}

  @override
  Future<GoogleSignInUserData?> signIn() async {
    final e = error;
    if (e != null) throw e;
    return GoogleSignInUserData(
      id: 'google-1',
      email: 'cliente@gmail.com',
      displayName: 'Cliente Google',
    );
  }

  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async {
    return GoogleSignInTokenData(idToken: idToken, accessToken: 'access-fake');
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> disconnect() async {}
}

/// Si el usuario cancela, signIn() retorna null.
class FakeGoogleSignInCanceledPlatform extends GoogleSignInPlatform {
  @override
  Future<void> init({
    List<String> scopes = const <String>[],
    SignInOption signInOption = SignInOption.standard,
    String? hostedDomain,
    String? clientId,
  }) async {}

  @override
  Future<GoogleSignInUserData?> signIn() async => null;

  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async => GoogleSignInTokenData();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> disconnect() async {}
}

/// Payload de `AuthTokens` tal como lo devuelve el backend dentro de `data`.
Map<String, dynamic> tokensJson() => {
      'accessToken': 'access-1',
      'refreshToken': 'refresh-1',
      'user': {
        'id': 'user-1',
        'email': 'cliente@gmail.com',
        'fullName': 'Cliente Google',
        'provider': 'google',
        'totalSpent': 0,
        'role': 'cliente',
        'createdAt': '2026-01-15T10:30:00.000Z',
        'updatedAt': '2026-02-01T08:00:00.000Z',
      },
    };

void main() {
  late MockDio dio;
  late MockSecureStorage storage;
  late AuthRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com\n'
          'GOOGLE_SERVER_CLIENT_ID='
          '614499893538-sn5adeq44eog889k15c7s3pmqosapen6.apps.googleusercontent.com',
    );
  });

  setUp(() {
    dio = MockDio();
    storage = MockSecureStorage();
    repository = AuthRepository(dio, storage);
  });

  group('loginWithGoogle', () {
    test('éxito: envía el idToken al backend y devuelve AuthTokens', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/google',
          data: {'idToken': 'google-id-token'},
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/auth/google'),
          data: tokensJson(),
        ),
      );

      final tokens = await repository.loginWithGoogle();

      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
      expect(tokens.user.provider, UserProvider.google);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/google',
          data: {'idToken': 'google-id-token'},
        ),
      ).called(1);
    });

    test('usuario cierra el picker → GoogleSignInCanceledException', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInCanceledPlatform();

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(isA<GoogleSignInCanceledException>()),
      );
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });

    test('fallo de plataforma de Google → ApiException con mensaje claro',
        () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
        error: Exception('network error'),
      );

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No se pudo conectar con Google'),
          ),
        ),
      );
    });

    test('Google no devuelve idToken → ApiException', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(idToken: null);

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('token válido'),
          ),
        ),
      );
    });

    test('backend responde 409 (email ya existe como cuenta local) → '
        'ApiException con el mensaje del backend', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/google',
          data: {'idToken': 'google-id-token'},
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/google'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/google'),
            statusCode: 409,
            data: {
              'success': false,
              'message': 'Este correo ya está registrado con contraseña. '
                  'Inicia sesión tradicional o usa "olvidé mi contraseña".',
              'statusCode': 409,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                contains('ya está registrado con contraseña'),
              ),
        ),
      );
    });

    test('error de red en POST /auth/google → ApiException de conexión',
        () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/google',
          data: {'idToken': 'google-id-token'},
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/google'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.loginWithGoogle(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No se pudo conectar con el servidor'),
          ),
        ),
      );
    });

    test('Cada llamada crea una instancia nueva (sin estado residual)', () async {
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/google',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/auth/google'),
          data: tokensJson(),
        ),
      );

      final t1 = await repository.loginWithGoogle();
      final t2 = await repository.loginWithGoogle();

      expect(t1.accessToken, 'access-1');
      expect(t2.accessToken, 'access-1');
    });
  });

  group('login / register — errores del backend como ApiException', () {
    test('login con credenciales inválidas → ApiException con mensaje del '
        'backend', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            data: {
              'success': false,
              'message': 'Credenciales inválidas',
              'statusCode': 401,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.login(email: 'a@b.com', password: 'wrong'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Credenciales inválidas',
          ),
        ),
      );
    });

    test('register con email duplicado → ApiException con mensaje del backend',
        () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register'),
            statusCode: 409,
            data: {
              'success': false,
              'message': 'El email ya está registrado',
              'statusCode': 409,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.register(
          fullName: 'A',
          email: 'a@b.com',
          password: 'secret',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'El email ya está registrado',
          ),
        ),
      );
    });
  });
}
