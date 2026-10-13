import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSession extends Mock implements AuthSessionBridge {}

class AuthTokensFake extends Fake implements AuthTokens {}

/// Adaptador de red falso: responde según un handler por request, sin tocar la
/// red. Permite simular 401, respuestas exitosas y delays controlados.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, int statusCode) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );

/// Envelope de tokens que devuelve `POST /auth/refresh` (contrato real).
final refreshTokensBody = {
  'accessToken': 'access-new',
  'refreshToken': 'refresh-new',
  'user': {
    'id': 'user-1',
    'email': 'cliente@celtas.pe',
    'fullName': 'Cliente de Prueba',
    'provider': 'local',
    'googleId': null,
    'phone': null,
    'fcmToken': null,
    'totalSpent': 0,
    'role': 'cliente',
    'createdAt': '2026-01-15T10:30:00.000Z',
    'updatedAt': '2026-02-01T08:00:00.000Z',
  },
};

void main() {
  late MockSession session;

  setUpAll(() {
    // `ApiClient.instance` (singleton) lee `AppConfig.apiBaseUrl` de
    // `flutter_dotenv` al construirse; en tests no hay `.env` cargado.
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
    // mocktail: fallback para `any()` sobre parámetros de tipo `AuthTokens`.
    registerFallbackValue(AuthTokensFake());
  });

  setUp(() {
    session = MockSession();
    ApiClient.instance.session = session;
    // Singleton: limpiar el hook entre tests para no arrastrar callbacks.
    ApiClient.instance.onSessionRefreshed = null;
    when(() => session.accessToken).thenReturn(null);
    when(() => session.revision).thenReturn(0);
    when(() => session.canRefresh).thenReturn(true);
    when(
      () => session.readRefreshToken(),
    ).thenAnswer((_) async => 'refresh-old');
    when(
      () => session.commitRefreshedTokens(
        any(),
        expectedRevision: any(named: 'expectedRevision'),
        isCurrent: any(named: 'isCurrent'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => session.clearSession(
        expectedRevision: any(named: 'expectedRevision'),
      ),
    ).thenAnswer((_) async {});
  });

  group('interceptor de error — 401 dispara refresh UNA sola vez', () {
    test(
      '401 → refresh → reintenta la request original con el token nuevo',
      () async {
        var menuCalls = 0;
        final adapter = StubAdapter((options) async {
          if (options.path == '/auth/refresh') {
            return jsonResponse({
              'success': true,
              'data': refreshTokensBody,
            }, 200);
          }
          menuCalls++;
          if (menuCalls == 1) {
            return jsonResponse({
              'success': false,
              'message': 'No autorizado',
              'statusCode': 401,
            }, 401);
          }
          return jsonResponse({
            'success': true,
            'data': {'ok': true},
          }, 200);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final response = await ApiClient.instance.dio.get('/menu');

        expect(response.statusCode, 200);
        expect(response.data, {'ok': true});

        // El refresh se ejecutó exactamente una vez y rotó el refresh token.
        verify(
          () => session.commitRefreshedTokens(
            any(),
            expectedRevision: 0,
            isCurrent: any(named: 'isCurrent'),
          ),
        ).called(1);

        verifyNever(
          () => session.clearSession(
            expectedRevision: any(named: 'expectedRevision'),
          ),
        );

        // La request original se reintentó una vez, con el access token nuevo.
        final menuRequests = adapter.requests
            .where((r) => r.path == '/menu')
            .toList();
        expect(menuRequests.length, 2);
        expect(menuRequests[1].headers['Authorization'], 'Bearer access-new');

        final refreshRequests = adapter.requests
            .where((r) => r.path == '/auth/refresh')
            .toList();
        expect(refreshRequests.length, 1);
      },
    );

    test(
      'si el reintento vuelve a fallar con 401, NO refresca de nuevo (no loop)',
      () async {
        var menuCalls = 0;
        final adapter = StubAdapter((options) async {
          if (options.path == '/auth/refresh') {
            return jsonResponse({
              'success': true,
              'data': refreshTokensBody,
            }, 200);
          }
          menuCalls++;
          return jsonResponse({
            'success': false,
            'message': 'No autorizado',
            'statusCode': 401,
          }, 401);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await expectLater(
          ApiClient.instance.dio.get('/menu'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        // El refresh ocurrió una sola vez: el reintento marcado con `_retry`
        // no vuelve a entrar al ciclo.
        verify(
          () => session.commitRefreshedTokens(
            any(),
            expectedRevision: 0,
            isCurrent: any(named: 'isCurrent'),
          ),
        ).called(1);

        expect(menuCalls, 2); // original + reintento, nada más.
        final refreshRequests = adapter.requests
            .where((r) => r.path == '/auth/refresh')
            .toList();
        expect(refreshRequests.length, 1);
      },
    );

    test(
      '401 sin refresh token guardado → limpia sesión y no reintenta',
      () async {
        when(() => session.readRefreshToken()).thenAnswer((_) async => null);
        final adapter = StubAdapter((options) async {
          return jsonResponse({
            'success': false,
            'message': 'No autorizado',
            'statusCode': 401,
          }, 401);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await expectLater(
          ApiClient.instance.dio.get('/menu'),
          throwsA(isA<DioException>()),
        );

        verify(
          () => session.clearSession(
            expectedRevision: any(named: 'expectedRevision'),
          ),
        ).called(1);
        verifyNever(
          () => session.commitRefreshedTokens(
            any(),
            expectedRevision: any(named: 'expectedRevision'),
            isCurrent: any(named: 'isCurrent'),
          ),
        );
        expect(
          adapter.requests.where((r) => r.path == '/auth/refresh'),
          isEmpty,
        );
        expect(adapter.requests.where((r) => r.path == '/menu').length, 1);
      },
    );

    test('refresh responde 401 definitivo → limpia sesión', () async {
      final adapter = StubAdapter((options) async {
        if (options.path == '/auth/refresh') {
          return jsonResponse({
            'success': false,
            'message': 'Refresh inválido',
            'statusCode': 401,
          }, 401);
        }
        return jsonResponse({
          'success': false,
          'message': 'No autorizado',
          'statusCode': 401,
        }, 401);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await expectLater(
        ApiClient.instance.dio.get('/menu'),
        throwsA(isA<DioException>()),
      );

      verify(
        () => session.clearSession(
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).called(1);
      verifyNever(
        () => session.commitRefreshedTokens(
          any(),
          expectedRevision: any(named: 'expectedRevision'),
          isCurrent: any(named: 'isCurrent'),
        ),
      );
    });
  });

  group('interceptor de error — cola de requests pendientes', () {
    test('requests que llegan durante el refresh se encolan y se liberan con '
        'el token nuevo', () async {
      final refreshGate = Completer<void>();
      final refreshSeen = Completer<void>();
      var menuCalls = 0;

      final adapter = StubAdapter((options) async {
        if (options.path == '/auth/refresh') {
          refreshSeen.complete();
          await refreshGate.future;
          return jsonResponse({
            'success': true,
            'data': refreshTokensBody,
          }, 200);
        }
        menuCalls++;
        // Los reintentos (tras el flush) viajan con el access token nuevo.
        if (options.headers['Authorization'] == 'Bearer access-new') {
          return jsonResponse({
            'success': true,
            'data': {'ok': true},
          }, 200);
        }
        return jsonResponse({
          'success': false,
          'message': 'No autorizado',
          'statusCode': 401,
        }, 401);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      // Request A: dispara el refresh (que queda bloqueado en refreshGate).
      final futureA = ApiClient.instance.dio.get('/menu');
      await refreshSeen.future;

      // Requests B y C: llegan con el refresh en vuelo → deben encolarse.
      final futureB = ApiClient.instance.dio.get('/menu');
      final futureC = ApiClient.instance.dio.get('/menu');
      // Deja que B y C reciban su 401 y se encolen antes de liberar el refresh.
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      refreshGate.complete();

      final results = await Future.wait([futureA, futureB, futureC]);
      for (final response in results) {
        expect(response.statusCode, 200);
        expect(response.data, {'ok': true});
      }

      // Un solo refresh para las tres requests.
      verify(
        () => session.commitRefreshedTokens(
          any(),
          expectedRevision: 0,
          isCurrent: any(named: 'isCurrent'),
        ),
      ).called(1);

      final refreshRequests = adapter.requests
          .where((r) => r.path == '/auth/refresh')
          .toList();
      expect(refreshRequests.length, 1);

      // 3 originales con 401 + 3 reintentos con el token nuevo.
      expect(menuCalls, 6);
    });

    test('reintento encolado con token rotado inválido → rechaza, no se '
        're-encola ni se cuelga (deadlock)', () async {
      final refreshGate = Completer<void>();
      final refreshSeen = Completer<void>();
      final aRetryGate = Completer<void>();
      final bRetrySeen = Completer<void>();
      // Identidad de los RequestOptions originales para distinguir el
      // reintento de A (lento, gated) del de B (401 inmediato).
      RequestOptions? originalA;
      RequestOptions? originalB;

      final adapter = StubAdapter((options) async {
        if (options.path == '/auth/refresh') {
          refreshSeen.complete();
          await refreshGate.future;
          return jsonResponse({
            'success': true,
            'data': refreshTokensBody,
          }, 200);
        }
        // Requests originales (sin token): 401.
        if (options.headers['Authorization'] == null) {
          if (originalA == null) {
            originalA = options;
          } else {
            originalB = options;
          }
          return jsonResponse({
            'success': false,
            'message': 'No autorizado',
            'statusCode': 401,
          }, 401);
        }
        // Reintentos (con el token recién rotado).
        if (identical(options, originalA)) {
          // A: reintento lento → mantiene `_isRefreshing` en true mientras el
          // reintento de B (401) se procesa.
          await aRetryGate.future;
          return jsonResponse({
            'success': true,
            'data': {'ok': true},
          }, 200);
        }
        // B: el token recién rotado es rechazado → 401 en el reintento.
        if (identical(options, originalB)) {
          bRetrySeen.complete();
          return jsonResponse({
            'success': false,
            'message': 'No autorizado',
            'statusCode': 401,
          }, 401);
        }
        return jsonResponse({
          'success': false,
          'message': 'No autorizado',
          'statusCode': 401,
        }, 401);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      // Request A: dispara el refresh (bloqueado en refreshGate).
      final futureA = ApiClient.instance.dio.get('/menu');
      await refreshSeen.future;

      // Request B: llega con el refresh en vuelo → se encola.
      final futureB = ApiClient.instance.dio.get('/menu');
      // Listener inmediato: el 401 final de B se captura como valor para no
      // disparar "unhandled error" mientras el test espera el flujo del refresh.
      final bResult = futureB.then<Object?>((r) => r, onError: (Object e) => e);
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // El refresh termina: B se libera con el token nuevo y reintenta → 401.
      refreshGate.complete();
      await bRetrySeen.future;
      // Deja que el 401 del reintento de B se procese por el interceptor.
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // B debe RECHAZAR con 401 (con timeout: si se re-encola y cuelga, el
      // test falla por TimeoutException en vez de pasar).
      final bOutcome = await bResult.timeout(const Duration(seconds: 5));
      expect(bOutcome, isA<DioException>());
      expect((bOutcome as DioException).response?.statusCode, 401);

      // A reintenta con éxito una vez liberado.
      aRetryGate.complete();
      final responseA = await futureA;
      expect(responseA.statusCode, 200);
      expect(responseA.data, {'ok': true});

      // Un solo refresh en todo el flujo: B NO dispara un segundo ciclo.
      verify(
        () => session.commitRefreshedTokens(
          any(),
          expectedRevision: 0,
          isCurrent: any(named: 'isCurrent'),
        ),
      ).called(1);

      final refreshRequests = adapter.requests
          .where((r) => r.path == '/auth/refresh')
          .toList();
      expect(refreshRequests.length, 1);
    });
  });

  group('identidad de sesión durante refresh silencioso', () {
    test(
      'cambio de cuenta desde el hook evita reenvío de la request antigua',
      () async {
        var revision = 0;
        when(() => session.revision).thenAnswer((_) => revision);
        ApiClient.instance.onSessionRefreshed = () => revision++;
        final adapter = StubAdapter(
          (options) async => options.path == '/auth/refresh'
              ? jsonResponse({'success': true, 'data': refreshTokensBody}, 200)
              : jsonResponse({'message': 'unauthorized'}, 401),
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        await expectLater(
          ApiClient.instance.dio.get('/menu'),
          throwsA(isA<DioException>()),
        );
        expect(adapter.requests.where((r) => r.path == '/menu'), hasLength(1));
      },
    );
    for (final status in [200, 401]) {
      test(
        'respuesta tardía $status no persiste ni borra otra cuenta',
        () async {
          var revision = 0;
          when(() => session.revision).thenAnswer((_) => revision);
          final started = Completer<void>();
          final pending = Completer<void>();
          var hooks = 0;
          ApiClient.instance.onSessionRefreshed = () => hooks++;
          final adapter = StubAdapter((options) async {
            if (options.path == '/auth/refresh') {
              started.complete();
              await pending.future;
              return jsonResponse(
                status == 200
                    ? {'success': true, 'data': refreshTokensBody}
                    : {'message': 'invalid'},
                status,
              );
            }
            return jsonResponse({'message': 'unauthorized'}, 401);
          });
          ApiClient.instance.dio.httpClientAdapter = adapter;
          final outcome = ApiClient.instance.dio
              .get('/menu')
              .then<Object?>((r) => r, onError: (Object e) => e);
          await started.future;
          revision++;
          pending.complete();
          expect(await outcome, isA<DioException>());
          verifyNever(
            () => session.commitRefreshedTokens(
              any(),
              expectedRevision: any(named: 'expectedRevision'),
              isCurrent: any(named: 'isCurrent'),
            ),
          );
          verifyNever(
            () => session.clearSession(
              expectedRevision: any(named: 'expectedRevision'),
            ),
          );
          expect(hooks, 0);
          expect(
            adapter.requests.where((r) => r.path == '/menu'),
            hasLength(1),
          );
        },
      );
    }

    test(
      '401 de una request vieja no refresca credenciales de la cuenta nueva',
      () async {
        var revision = 0;
        when(() => session.revision).thenAnswer((_) => revision);
        final started = Completer<void>();
        final pending = Completer<void>();
        final adapter = StubAdapter((options) async {
          started.complete();
          await pending.future;
          return jsonResponse({'message': 'unauthorized'}, 401);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final outcome = ApiClient.instance.dio
            .get('/menu')
            .then<Object?>((r) => r, onError: (Object e) => e);
        await started.future;
        revision++;
        pending.complete();
        expect(await outcome, isA<DioException>());
        expect(adapter.requests, hasLength(1));
        verifyNever(() => session.readRefreshToken());
      },
    );

    test(
      'bootstrap pendiente no dispara refresh silencioso paralelo',
      () async {
        when(() => session.canRefresh).thenReturn(false);
        final adapter = StubAdapter(
          (_) async => jsonResponse({'message': 'unauthorized'}, 401),
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        await expectLater(
          ApiClient.instance.dio.get('/menu'),
          throwsA(isA<DioException>()),
        );
        expect(adapter.requests, hasLength(1));
        verifyNever(() => session.readRefreshToken());
      },
    );
  });

  group('interceptor de error — hook onSessionRefreshed', () {
    test('se invoca UNA vez tras un refresh exitoso', () async {
      var calls = 0;
      ApiClient.instance.onSessionRefreshed = () => calls++;

      var menuCalls = 0;
      final adapter = StubAdapter((options) async {
        if (options.path == '/auth/refresh') {
          return jsonResponse({
            'success': true,
            'data': refreshTokensBody,
          }, 200);
        }
        menuCalls++;
        if (menuCalls == 1) {
          return jsonResponse({
            'success': false,
            'message': 'No autorizado',
            'statusCode': 401,
          }, 401);
        }
        return jsonResponse({
          'success': true,
          'data': {'ok': true},
        }, 200);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final response = await ApiClient.instance.dio.get('/menu');

      expect(response.statusCode, 200);
      expect(calls, 1);
    });

    test('NO se invoca si el refresh falla con 401 definitivo', () async {
      var calls = 0;
      ApiClient.instance.onSessionRefreshed = () => calls++;

      final adapter = StubAdapter((options) async {
        if (options.path == '/auth/refresh') {
          return jsonResponse({
            'success': false,
            'message': 'Refresh inválido',
            'statusCode': 401,
          }, 401);
        }
        return jsonResponse({
          'success': false,
          'message': 'No autorizado',
          'statusCode': 401,
        }, 401);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await expectLater(
        ApiClient.instance.dio.get('/menu'),
        throwsA(isA<DioException>()),
      );

      verify(
        () => session.clearSession(
          expectedRevision: any(named: 'expectedRevision'),
        ),
      ).called(1);
      expect(calls, 0);
    });

    test(
      'NO se invoca si el refresh falla por error transitorio (5xx)',
      () async {
        var calls = 0;
        ApiClient.instance.onSessionRefreshed = () => calls++;

        final adapter = StubAdapter((options) async {
          if (options.path == '/auth/refresh') {
            return jsonResponse({
              'success': false,
              'message': 'Server dormido',
              'statusCode': 503,
            }, 503);
          }
          return jsonResponse({
            'success': false,
            'message': 'No autorizado',
            'statusCode': 401,
          }, 401);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await expectLater(
          ApiClient.instance.dio.get('/menu'),
          throwsA(isA<DioException>()),
        );

        expect(calls, 0);
      },
    );

    test(
      'un callback que lanza no rompe el reintento de la request original',
      () async {
        ApiClient.instance.onSessionRefreshed = () =>
            throw StateError('callback roto');

        var menuCalls = 0;
        final adapter = StubAdapter((options) async {
          if (options.path == '/auth/refresh') {
            return jsonResponse({
              'success': true,
              'data': refreshTokensBody,
            }, 200);
          }
          menuCalls++;
          if (menuCalls == 1) {
            return jsonResponse({
              'success': false,
              'message': 'No autorizado',
              'statusCode': 401,
            }, 401);
          }
          return jsonResponse({
            'success': true,
            'data': {'ok': true},
          }, 200);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final response = await ApiClient.instance.dio.get('/menu');

        expect(response.statusCode, 200);
        expect(response.data, {'ok': true});
        final menuRequests = adapter.requests
            .where((r) => r.path == '/menu')
            .toList();
        expect(menuRequests.length, 2);
        expect(menuRequests[1].headers['Authorization'], 'Bearer access-new');
      },
    );
  });
}
