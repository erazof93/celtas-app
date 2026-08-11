import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:celtas_mobile/features/orders/data/order_history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late OrderHistoryRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = OrderHistoryRepository(dio);
  });

  group('getMyOrders', () {
    const listJson = [
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'status': 'pendiente',
        'addressSnapshot': '{"alias":"Casa","fullAddress":"Av. Los Álamos '
            '123","reference":null,"district":"San Juan de Miraflores"}',
        'total': 31.5,
        'whatsappUrl': 'https://wa.me/51999999999',
        'deliveredAt': null,
        'items': [
          {
            'id': 'item-1',
            'menuItemId': 'menu-1',
            'name': 'Berserker Burger',
            'unitPrice': 15.5,
            'quantity': 2,
            'subtotal': 31.0,
          },
        ],
        'createdAt': '2026-08-06T10:00:00.000Z',
      },
      {
        'id': 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
        'status': 'entregado',
        'addressSnapshot': '{"alias":"Trabajo","fullAddress":"Av. Callao '
            '850","reference":null,"district":"Surco"}',
        'total': 15.5,
        'whatsappUrl': 'https://wa.me/51999999999',
        'deliveredAt': '2026-08-07T18:00:00.000Z',
        'items': [
          {
            'id': 'item-2',
            'menuItemId': 'menu-2',
            'name': "Odin's Wings x8",
            'unitPrice': 15.5,
            'quantity': 1,
            'subtotal': 15.5,
          },
        ],
        'createdAt': '2026-08-05T10:00:00.000Z',
      },
    ];

    test('éxito: GET /orders/me y parsea la lista completa', () async {
      when(() => dio.get<List<dynamic>>('/orders/me')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/orders/me'),
          data: listJson,
        ),
      );

      final orders = await repository.getMyOrders();

      expect(orders, hasLength(2));
      expect(orders.first.status, OrderStatus.pendiente);
      expect(orders.first.items, hasLength(1));
      expect(orders.first.items.first.name, 'Berserker Burger');
      expect(orders.last.status, OrderStatus.entregado);
      expect(orders.last.deliveredAt, DateTime.utc(2026, 8, 7, 18));
      verify(() => dio.get<List<dynamic>>('/orders/me')).called(1);
    });

    test('respuesta vacía (sin data) → lista vacía, no crashea', () async {
      when(() => dio.get<List<dynamic>>('/orders/me')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/orders/me'),
        ),
      );

      final orders = await repository.getMyOrders();

      expect(orders, isEmpty);
    });

    test('error del backend → ApiException con el mensaje real', () async {
      when(() => dio.get<List<dynamic>>('/orders/me')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/orders/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/orders/me'),
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
        repository.getMyOrders(),
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
