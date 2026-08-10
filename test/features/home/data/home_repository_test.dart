import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/home/data/home_repository.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late HomeRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = HomeRepository(dio);
  });

  group('getActiveBanners', () {
    test('éxito: devuelve la lista de banners del envelope', () async {
      when(() => dio.get<List<dynamic>>('/banners/active')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/banners/active'),
          data: [
            {
              'id': 'b-1',
              'title': 'aprovecha la 2x1',
              'imageUrl': 'https://res.cloudinary.com/x.webp',
              'actionType': 'none',
              'active': true,
              'order': 0,
              'createdAt': '2026-08-09T20:57:46.633Z',
              'updatedAt': '2026-08-09T20:57:48.872Z',
            },
          ],
        ),
      );

      final banners = await repository.getActiveBanners();

      expect(banners, hasLength(1));
      expect(banners.first.title, 'aprovecha la 2x1');
      expect(banners.first.actionType, BannerActionType.none);
      verify(() => dio.get<List<dynamic>>('/banners/active')).called(1);
    });

    test('data vacío → lista vacía (sin banners activos)', () async {
      when(() => dio.get<List<dynamic>>('/banners/active')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/banners/active'),
          data: const [],
        ),
      );

      final banners = await repository.getActiveBanners();

      expect(banners, isEmpty);
    });

    test('error de red → ApiException de conexión', () async {
      when(() => dio.get<List<dynamic>>('/banners/active')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/banners/active'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.getActiveBanners(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No se pudo conectar con el servidor'),
          ),
        ),
      );
    });

    test('error del backend → ApiException con el mensaje real', () async {
      when(() => dio.get<List<dynamic>>('/banners/active')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/banners/active'),
          response: Response(
            requestOptions: RequestOptions(path: '/banners/active'),
            statusCode: 500,
            data: {
              'success': false,
              'message': 'Error interno del servidor',
              'statusCode': 500,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.getActiveBanners(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Error interno del servidor',
          ),
        ),
      );
    });
  });

  group('getMenu', () {
    test('éxito: devuelve categorías con items', () async {
      when(() => dio.get<List<dynamic>>('/menu')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/menu'),
          data: [
            {
              'id': 'c-1',
              'name': 'Hamburguesa',
              'description': 'Hamburguesa artesanales',
              'items': [
                {
                  'id': 'i-1',
                  'name': 'Celtas Burgues Clasica',
                  'description': 'doble carne, queso y jamon',
                  'price': 15.5,
                  'image': 'https://res.cloudinary.com/x.jpg',
                },
              ],
            },
          ],
        ),
      );

      final menu = await repository.getMenu();

      expect(menu, hasLength(1));
      expect(menu.first.name, 'Hamburguesa');
      expect(menu.first.items.single.price, 15.5);
      verify(() => dio.get<List<dynamic>>('/menu')).called(1);
    });

    test('data vacío → lista vacía', () async {
      when(() => dio.get<List<dynamic>>('/menu')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/menu'),
          data: const [],
        ),
      );

      final menu = await repository.getMenu();

      expect(menu, isEmpty);
    });

    test('error de red → ApiException de conexión', () async {
      when(() => dio.get<List<dynamic>>('/menu')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/menu'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(
        repository.getMenu(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('tardó demasiado'),
          ),
        ),
      );
    });
  });
}