import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late NotificationRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = NotificationRepository(dio);
  });

  group('updateFcmToken', () {
    test('éxito: PATCH /users/me/fcm-token con { fcmToken }', () async {
      when(
        () => dio.patch<void>('/users/me/fcm-token', data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/users/me/fcm-token'),
        ),
      );

      await repository.updateFcmToken('device-token-123');

      verify(
        () => dio.patch<void>(
          '/users/me/fcm-token',
          data: {'fcmToken': 'device-token-123'},
        ),
      ).called(1);
    });

    test('error del backend → ApiException con el mensaje real', () async {
      when(
        () => dio.patch<void>('/users/me/fcm-token', data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/fcm-token'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/me/fcm-token'),
            statusCode: 400,
            data: {
              'success': false,
              'message': 'fcmToken es obligatorio',
              'statusCode': 400,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.updateFcmToken(''),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'fcmToken es obligatorio',
          ),
        ),
      );
    });

    test('error de red → ApiException de conexión', () async {
      when(
        () => dio.patch<void>('/users/me/fcm-token', data: any(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/fcm-token'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.updateFcmToken('device-token-123'),
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

  group('clearFcmToken', () {
    test('éxito: DELETE /users/me/fcm-token sin body', () async {
      when(() => dio.delete<void>('/users/me/fcm-token')).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/users/me/fcm-token'),
        ),
      );

      await repository.clearFcmToken();

      verify(() => dio.delete<void>('/users/me/fcm-token')).called(1);
    });

    test('error del backend → ApiException con el mensaje real', () async {
      when(() => dio.delete<void>('/users/me/fcm-token')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/fcm-token'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/me/fcm-token'),
            statusCode: 401,
            data: {
              'success': false,
              'message': 'No autorizado',
              'statusCode': 401,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.clearFcmToken(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No autorizado',
          ),
        ),
      );
    });

    test('error de red → ApiException de conexión', () async {
      when(() => dio.delete<void>('/users/me/fcm-token')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/fcm-token'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        repository.clearFcmToken(),
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
}
