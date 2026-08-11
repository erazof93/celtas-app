import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/coupons/data/coupon_repository.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late CouponRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = CouponRepository(dio);
  });

  const couponJson = {
    'valid': true,
    'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    'code': 'A1B2C3D4',
    'discountType': 'percentage',
    'discountValue': 10,
    'description': '10% de descuento',
    'expiresAt': '2026-09-01T00:00:00.000Z',
  };

  group('validateCoupon', () {
    test('éxito: POST /coupons/validate con { code } y parsea la respuesta',
        () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/coupons/validate',
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/coupons/validate'),
          data: couponJson,
        ),
      );

      final coupon = await repository.validateCoupon('A1B2C3D4');

      expect(coupon.valid, isTrue);
      expect(coupon.code, 'A1B2C3D4');
      expect(coupon.discountType, CouponDiscountType.percentage);
      expect(coupon.discountValue, 10);
      expect(coupon.description, '10% de descuento');
      expect(coupon.expiresAt, DateTime.utc(2026, 9));
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/coupons/validate',
          data: {'code': 'A1B2C3D4'},
        ),
      ).called(1);
    });

    test('cupón de monto fijo → discountType fixed_amount', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/coupons/validate',
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/coupons/validate'),
          data: {
            ...couponJson,
            'discountType': 'fixed_amount',
            'discountValue': 15,
            'description': 'S/15.00 de descuento',
          },
        ),
      );

      final coupon = await repository.validateCoupon('A1B2C3D4');

      expect(coupon.discountType, CouponDiscountType.fixedAmount);
      expect(coupon.discountValue, 15);
    });

    test('cupón inválido (400) → ApiException con el mensaje real del backend',
        () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/coupons/validate',
            data: any(named: 'data'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/coupons/validate'),
          response: Response(
            requestOptions: RequestOptions(path: '/coupons/validate'),
            statusCode: 400,
            data: {
              'success': false,
              'message': 'Este cupón ya fue utilizado',
              'statusCode': 400,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.validateCoupon('A1B2C3D4'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Este cupón ya fue utilizado')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('cupón expirado → ApiException "Este cupón ha expirado"', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/coupons/validate',
            data: any(named: 'data'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/coupons/validate'),
          response: Response(
            requestOptions: RequestOptions(path: '/coupons/validate'),
            statusCode: 400,
            data: {
              'success': false,
              'message': 'Este cupón ha expirado',
              'statusCode': 400,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.validateCoupon('A1B2C3D4'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Este cupón ha expirado',
          ),
        ),
      );
    });

    test('error de red → ApiException de conexión', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/coupons/validate',
            data: any(named: 'data'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/coupons/validate'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.validateCoupon('A1B2C3D4'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No se pudo conectar con el servidor'),
          ),
        ),
      );
    });
  });

  group('getMyCoupons', () {
    const listJson = [
      {
        'id': 'c-1',
        'code': 'VIKINGO10',
        'discountType': 'percentage',
        'discountValue': 10.0,
        'status': 'active',
        'expiresAt': '2026-12-31T00:00:00.000Z',
        'usedAt': null,
      },
      {
        'id': 'c-2',
        'code': 'FUEGO3000',
        'discountType': 'fixed_amount',
        'discountValue': 15.0,
        'status': 'used',
        'expiresAt': '2026-08-20T00:00:00.000Z',
        'usedAt': '2026-08-05T00:00:00.000Z',
      },
    ];

    test('éxito: GET /coupons/me y parsea la lista completa', () async {
      when(() => dio.get<List<dynamic>>('/coupons/me')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/coupons/me'),
          data: listJson,
        ),
      );

      final coupons = await repository.getMyCoupons();

      expect(coupons, hasLength(2));
      expect(coupons.first.code, 'VIKINGO10');
      expect(coupons.first.status.name, 'active');
      expect(coupons.last.code, 'FUEGO3000');
      expect(coupons.last.usedAt, DateTime.utc(2026, 8, 5));
      verify(() => dio.get<List<dynamic>>('/coupons/me')).called(1);
    });

    test('respuesta vacía (sin data) → lista vacía, no crashea', () async {
      when(() => dio.get<List<dynamic>>('/coupons/me')).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/coupons/me'),
        ),
      );

      final coupons = await repository.getMyCoupons();

      expect(coupons, isEmpty);
    });

    test('error del backend → ApiException con el mensaje real', () async {
      when(() => dio.get<List<dynamic>>('/coupons/me')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/coupons/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/coupons/me'),
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
        repository.getMyCoupons(),
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