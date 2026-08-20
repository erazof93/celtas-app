import 'package:celtas_mobile/features/addresses/data/geoapify_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _okResponse(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/v1/geocode/autocomplete'),
      data: data,
      statusCode: 200,
    );

const _featureCollection = {
  'features': [
    {
      'properties': {
        'formatted': 'Av. Los Álamos 123, San Juan de Miraflores, Perú',
        'lat': -12.1633,
        'lon': -76.9718,
        'district': 'San Juan de Miraflores',
      },
    },
  ],
};

/// Escenario "con API key configurada" — ver el docstring de
/// `geoapify_repository_no_key_test.dart` sobre por qué está en un archivo
/// separado (`AppConfig.geoapifyApiKey` es `static final`, cacheado una sola
/// vez por isolate).
void main() {
  late MockDio dio;
  late GeoapifyRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions());
    dotenv.loadFromString(
      envString:
          'API_BASE_URL=https://backend-celtas.onrender.com\n'
          'GEOAPIFY_API_KEY=test-key-123',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = GeoapifyRepository(dio);
  });

  test('hasApiKey es true con GEOAPIFY_API_KEY en .env', () {
    expect(repository.hasApiKey, isTrue);
  });

  test('autocomplete() con texto vacío no dispara request', () async {
    final result = await repository.autocomplete('   ');
    expect(result, isEmpty);
    verifyNever(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    );
  });

  test('autocomplete() parsea la respuesta real de Geoapify', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/v1/geocode/autocomplete',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => _okResponse(_featureCollection));

    final result = await repository.autocomplete('Av. Los Álamos');

    expect(result, hasLength(1));
    expect(result.single.district, 'San Juan de Miraflores');
  });

  test(
    '429 (rate limit compartido) → NUNCA lanza, devuelve [] silenciosamente',
    () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/v1/geocode/autocomplete',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/geocode/autocomplete'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/geocode/autocomplete'),
            statusCode: 429,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final result = await repository.autocomplete('Av. Los Álamos');
      expect(result, isEmpty);
    },
  );

  test('error de red en reverseGeocode() → null, nunca lanza', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/v1/geocode/reverse',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/v1/geocode/reverse'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await repository.reverseGeocode(
      latitude: -12.1633,
      longitude: -76.9718,
    );
    expect(result, isNull);
  });

  test(
    'geocode() (fallback de texto completo) parsea el primer resultado',
    () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/v1/geocode/search',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => _okResponse(_featureCollection));

      final result = await repository.geocode('Av. Los Álamos 123, SJM');

      expect(result?.formatted, contains('Av. Los Álamos 123'));
    },
  );
}
