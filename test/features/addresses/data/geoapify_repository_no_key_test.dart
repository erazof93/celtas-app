import 'package:celtas_mobile/features/addresses/data/geoapify_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// Separado de `geoapify_repository_test.dart` a propósito: `AppConfig.
/// geoapifyApiKey` es `static final` (evaluado una sola vez por isolate, ver
/// `lib/core/config/env.dart`) — mezclar ambos escenarios (con/sin key) en
/// el mismo archivo haría que el segundo grupo leyera el valor cacheado del
/// primero en vez del `.env` recién cargado.
void main() {
  late MockDio dio;
  late GeoapifyRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestOptions());
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = GeoapifyRepository(dio);
  });

  test('hasApiKey es false sin GEOAPIFY_API_KEY en .env', () {
    expect(repository.hasApiKey, isFalse);
  });

  test(
    'autocomplete() sin API key no dispara ninguna request, devuelve [] '
    '(nunca rompe la pantalla, ver skill geoapify-direcciones)',
    () async {
      final result = await repository.autocomplete('Av. Los Álamos');
      expect(result, isEmpty);
      verifyNever(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    },
  );

  test('reverseGeocode() sin API key no dispara request, devuelve null', () async {
    final result = await repository.reverseGeocode(
      latitude: -12.1,
      longitude: -76.9,
    );
    expect(result, isNull);
  });

  test('geocode() sin API key no dispara request, devuelve null', () async {
    final result = await repository.geocode('Av. Los Álamos 123');
    expect(result, isNull);
  });
}
