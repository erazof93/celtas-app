import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/rewards/data/reward_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// Contrato verificado contra `backend-celtas/src/modules/rewards/
/// rewards.controller.ts` + `rewards.service.ts`.
void main() {
  late MockDio dio;
  late RewardRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = RewardRepository(dio);
  });

  group('getProgress', () {
    test('GET /rewards/progress y parsea la respuesta', () async {
      when(() => dio.get<Map<String, dynamic>>('/rewards/progress')).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/progress'),
          data: {
            'estrellasDelMes': 4,
            'hitos': [
              {
                'estrellasRequeridas': 5,
                'alcanzado': false,
                'esEspecial': false,
              },
            ],
            'premiosDisponibles': [
              {
                'id': 'r-1',
                'expiresAt': '2026-09-10T00:00:00.000Z',
                'esEspecial': false,
              },
            ],
            'promocionActiva': null,
          },
        ),
      );

      final progress = await repository.getProgress();

      expect(progress.estrellasDelMes, 4);
      expect(progress.hitos.single.estrellasRequeridas, 5);
      expect(progress.premiosDisponibles.single.id, 'r-1');
      expect(progress.promocionActiva, isNull);
      verify(
        () => dio.get<Map<String, dynamic>>('/rewards/progress'),
      ).called(1);
    });

    test(
      'error del backend (401) → ApiException con el mensaje real',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>('/rewards/progress'),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/rewards/progress'),
            response: Response(
              requestOptions: RequestOptions(path: '/rewards/progress'),
              statusCode: 401,
              data: {
                'success': false,
                'message': 'Sin token o token inválido',
                'statusCode': 401,
              },
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          repository.getProgress(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Sin token o token inválido',
            ),
          ),
        );
      },
    );
  });

  group('getCatalog', () {
    const catalogJson = [
      {
        'id': 'i-1',
        'name': 'Berserker Burger',
        'description': 'Doble carne, cheddar, bacon',
        'price': 15.5,
        'image': null,
      },
    ];

    test('GET /rewards/catalog SIN especial (default false) y parsea la '
        'lista completa, sin mandar queryParameters', () async {
      when(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          // ignore: avoid_redundant_argument_values
          queryParameters: null,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/catalog'),
          data: catalogJson,
        ),
      );

      final items = await repository.getCatalog();

      expect(items, hasLength(1));
      expect(items.single.id, 'i-1');
      expect(items.single.name, 'Berserker Burger');
      verify(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          // ignore: avoid_redundant_argument_values
          queryParameters: null,
        ),
      ).called(1);
    });

    test('getCatalog(especial: false) explícito tampoco manda '
        'queryParameters (equivalente a omitirlo)', () async {
      when(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          // ignore: avoid_redundant_argument_values
          queryParameters: null,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/catalog'),
          data: catalogJson,
        ),
      );

      // ignore: avoid_redundant_argument_values
      await repository.getCatalog(especial: false);

      verify(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          // ignore: avoid_redundant_argument_values
          queryParameters: null,
        ),
      ).called(1);
    });

    test('getCatalog(especial: true) manda especial=\'true\' como STRING '
        '(el controller compara especial === \'true\', no un bool)', () async {
      when(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          queryParameters: {'especial': 'true'},
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/catalog'),
          data: catalogJson,
        ),
      );

      final items = await repository.getCatalog(especial: true);

      expect(items, hasLength(1));
      verify(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          queryParameters: {'especial': 'true'},
        ),
      ).called(1);
    });

    test('respuesta vacía (sin data) → lista vacía, no crashea', () async {
      when(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          // ignore: avoid_redundant_argument_values
          queryParameters: null,
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/catalog'),
        ),
      );

      final items = await repository.getCatalog();

      expect(items, isEmpty);
    });

    test('error del backend → ApiException con el mensaje real', () async {
      when(
        () => dio.get<List<dynamic>>(
          '/rewards/catalog',
          // ignore: avoid_redundant_argument_values
          queryParameters: null,
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/rewards/catalog'),
          response: Response(
            requestOptions: RequestOptions(path: '/rewards/catalog'),
            statusCode: 401,
            data: {
              'success': false,
              'message': 'Sin token o token inválido',
              'statusCode': 401,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.getCatalog(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Sin token o token inválido',
          ),
        ),
      );
    });
  });
}
