import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in DioExceptionType.values) {
    test('classifies $type by Dio evidence, never by message', () {
      final error = apiExceptionFromDio(
        DioException(
          requestOptions: RequestOptions(path: '/menu'),
          type: type,
          message: 'Sin Internet timeout server 503',
        ),
      );
      final expected = switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.transformTimeout => ApiErrorKind.timeout,
        DioExceptionType.connectionError ||
        DioExceptionType.badCertificate => ApiErrorKind.connection,
        _ => ApiErrorKind.other,
      };
      expect(error.kind, expected);
      expect(error.toString(), error.message);
      expect(error.message, isNot(contains('Sin Internet')));
    });
  }

  for (final status in [400, 401, 499, 500, 503, 599, 600]) {
    for (final withEnvelope in [true, false]) {
      test(
        'HTTP $status, envelope=$withEnvelope preserves status and category',
        () {
          final request = RequestOptions(path: '/menu');
          final error = apiExceptionFromDio(
            DioException(
              requestOptions: request,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: request,
                statusCode: status,
                data: withEnvelope
                    ? {'message': 'Mensaje del backend'}
                    : '<html/>',
              ),
            ),
          );
          expect(error.statusCode, status);
          expect(
            error.kind,
            status >= 500 && status < 600
                ? ApiErrorKind.server
                : ApiErrorKind.other,
          );
          if (withEnvelope) expect(error.message, 'Mensaje del backend');
        },
      );
    }
  }

  test('existing constructors remain compatible', () {
    const error = ApiException('legacy');
    expect(error.kind, ApiErrorKind.other);
    expect(error.toString(), 'legacy');
    expect(
      const ApiException('legacy', statusCode: 503).kind,
      ApiErrorKind.server,
    );
  });
}
