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
      when(() => dio.get<Map<String, dynamic>>('/rewards/progress'))
          .thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/progress'),
          data: {
            'estrellasParaProximoPremio': 4,
            'estrellasPorPremio': 10,
            'premiosDisponibles': [
              {'id': 'r-1', 'expiresAt': '2026-09-10T00:00:00.000Z'},
            ],
            'promocionActiva': null,
          },
        ),
      );

      final progress = await repository.getProgress();

      expect(progress.estrellasParaProximoPremio, 4);
      expect(progress.estrellasPorPremio, 10);
      expect(progress.premiosDisponibles.single.id, 'r-1');
      expect(progress.promocionActiva, isNull);
      verify(() => dio.get<Map<String, dynamic>>('/rewards/progress'))
          .called(1);
    });

    test('error del backend (401) → ApiException con el mensaje real', () async {
      when(() => dio.get<Map<String, dynamic>>('/rewards/progress'))
          .thenThrow(
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
    });
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

    test('GET /rewards/catalog y parsea la lista completa', () async {
      when(() => dio.get<List<dynamic>>('/rewards/catalog')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/catalog'),
          data: catalogJson,
        ),
      );

      final items = await repository.getCatalog();

      expect(items, hasLength(1));
      expect(items.single.id, 'i-1');
      expect(items.single.name, 'Berserker Burger');
      verify(() => dio.get<List<dynamic>>('/rewards/catalog')).called(1);
    });

    test('respuesta vacía (sin data) → lista vacía, no crashea', () async {
      when(() => dio.get<List<dynamic>>('/rewards/catalog')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/rewards/catalog'),
        ),
      );

      final items = await repository.getCatalog();

      expect(items, isEmpty);
    });

    test('error del backend → ApiException con el mensaje real', () async {
      when(() => dio.get<List<dynamic>>('/rewards/catalog')).thenThrow(
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
