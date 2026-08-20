import 'package:celtas_mobile/features/addresses/data/models/geoapify_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixture con el shape REAL confirmado contra
  // `tests/test-data/mock-geocoder-response-with-categories.json` del repo
  // oficial `geoapify/geocoder-autocomplete` (mismas APIs que consume esta
  // app) — ver docstring de `GeoapifySuggestion`.
  Map<String, dynamic> featureJson({
    String? district,
    String? suburb,
    String? city,
    String? street,
    String? housenumber,
    String? name,
    double lat = -12.1633,
    double lon = -76.9718,
    String formatted = 'Av. Los Álamos 123, San Juan de Miraflores, Perú',
  }) => {
    'type': 'Feature',
    'properties': {
      'datasource': {'sourcename': 'openstreetmap'},
      'country': 'Perú',
      'country_code': 'pe',
      'state': 'Lima',
      'county': 'Lima',
      'city': ?city,
      'suburb': ?suburb,
      'district': ?district,
      'street': ?street,
      'housenumber': ?housenumber,
      'name': ?name,
      'lon': lon,
      'lat': lat,
      'result_type': 'street',
      'formatted': formatted,
      'address_line1': 'Av. Los Álamos 123',
      'address_line2': 'San Juan de Miraflores, Perú',
      'place_id': 'abc123',
    },
    'geometry': {
      'type': 'Point',
      'coordinates': [lon, lat],
    },
  };

  group('GeoapifySuggestion.fromFeature', () {
    test('parsea un feature completo', () {
      final suggestion = GeoapifySuggestion.fromFeature(
        featureJson(district: 'San Juan de Miraflores'),
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.latitude, -12.1633);
      expect(suggestion.longitude, -76.9718);
      expect(
        suggestion.formatted,
        'Av. Los Álamos 123, San Juan de Miraflores, Perú',
      );
      expect(suggestion.district, 'San Juan de Miraflores');
    });

    test('feature sin properties → null (nunca lanza)', () {
      expect(GeoapifySuggestion.fromFeature({'type': 'Feature'}), isNull);
    });

    test('feature que no es un Map → null', () {
      expect(GeoapifySuggestion.fromFeature('no soy un feature'), isNull);
      expect(GeoapifySuggestion.fromFeature(null), isNull);
    });

    test('falta lat → null', () {
      final json = featureJson();
      (json['properties'] as Map<String, dynamic>).remove('lat');
      expect(GeoapifySuggestion.fromFeature(json), isNull);
    });

    test('falta formatted → null', () {
      final json = featureJson();
      (json['properties'] as Map<String, dynamic>).remove('formatted');
      expect(GeoapifySuggestion.fromFeature(json), isNull);
    });
  });

  group('bestDistrict', () {
    test(
      'usa city si está presente (caso real confirmado en dispositivo: '
      'district de Geoapify trae un barrio OSM, no el distrito peruano)',
      () {
        final suggestion = GeoapifySuggestion.fromFeature(
          featureJson(
            city: 'San Juan de Miraflores',
            suburb: 'San Juan de Miraflores',
            district: 'El Arenal',
          ),
        )!;
        expect(suggestion.bestDistrict, 'San Juan de Miraflores');
      },
    );

    test('sin city → cae a suburb', () {
      final suggestion = GeoapifySuggestion.fromFeature(
        featureJson(suburb: 'San Juan de Miraflores', district: 'El Arenal'),
      )!;
      expect(suggestion.bestDistrict, 'San Juan de Miraflores');
    });

    test('sin city ni suburb → cae a district como último recurso', () {
      final suggestion = GeoapifySuggestion.fromFeature(
        featureJson(district: 'El Arenal'),
      )!;
      expect(suggestion.bestDistrict, 'El Arenal');
    });

    test('sin ningún candidato → null (el form no se autocompleta a ciegas)', () {
      final suggestion = GeoapifySuggestion.fromFeature(featureJson())!;
      expect(suggestion.bestDistrict, isNull);
    });

    test('city vacío/blanco se trata como ausente', () {
      final suggestion = GeoapifySuggestion.fromFeature(
        featureJson(city: '   ', suburb: 'San Juan de Miraflores'),
      )!;
      expect(suggestion.bestDistrict, 'San Juan de Miraflores');
    });
  });

  group('bestFullAddress', () {
    test(
      'prioriza street+housenumber sobre formatted (caso real confirmado '
      'en dispositivo: reverse geocoding devolvió un colegio cercano como '
      'feature principal en vez del jirón)',
      () {
        final suggestion = GeoapifySuggestion.fromFeature(
          featureJson(
            street: 'Jirón Pedro Alcocer',
            housenumber: '894',
            city: 'San Juan de Miraflores',
            formatted:
                'Institución Educativa Johannes Gutenberg School, Jirón '
                'Pedro Alcocer, San Juan de Miraflores, Perú',
          ),
        )!;
        expect(
          suggestion.bestFullAddress,
          'Jirón Pedro Alcocer 894, San Juan de Miraflores',
        );
      },
    );

    test('street sin housenumber → solo el nombre de la calle + distrito', () {
      final suggestion = GeoapifySuggestion.fromFeature(
        featureJson(street: 'Jirón Pastor Sevilla', city: 'San Juan de Miraflores'),
      )!;
      expect(
        suggestion.bestFullAddress,
        'Jirón Pastor Sevilla, San Juan de Miraflores',
      );
    });

    test('sin street → cae a formatted', () {
      final suggestion = GeoapifySuggestion.fromFeature(
        featureJson(formatted: 'Parque Cáceres, San Juan de Miraflores, Perú'),
      )!;
      expect(
        suggestion.bestFullAddress,
        'Parque Cáceres, San Juan de Miraflores, Perú',
      );
    });

    test('street sin ningún distrito disponible → solo la calle', () {
      final suggestion = GeoapifySuggestion.fromFeature(
        featureJson(street: 'Jirón Pastor Sevilla'),
      )!;
      expect(suggestion.bestFullAddress, 'Jirón Pastor Sevilla');
    });

    test(
      'street idéntico a name (POI sin calle real cerca, caso real '
      'confirmado en dispositivo: un parque) → cae a formatted en vez de '
      'mostrar el nombre del POI disfrazado de calle',
      () {
        final suggestion = GeoapifySuggestion.fromFeature(
          featureJson(
            street: 'Parque Cáceres',
            name: 'Parque Cáceres',
            city: 'San Juan de Miraflores',
            formatted:
                'Parque Cáceres, San Juan de Miraflores, San Juan de '
                'Miraflores 15058, Perú',
          ),
        )!;
        expect(
          suggestion.bestFullAddress,
          'Parque Cáceres, San Juan de Miraflores, San Juan de Miraflores '
          '15058, Perú',
        );
      },
    );
  });

  group('GeoapifySuggestion.listFromResponse', () {
    test('parsea una FeatureCollection con varios resultados', () {
      final response = {
        'type': 'FeatureCollection',
        'features': [
          featureJson(formatted: 'Dirección 1'),
          featureJson(formatted: 'Dirección 2'),
        ],
      };

      final results = GeoapifySuggestion.listFromResponse(response);

      expect(results, hasLength(2));
      expect(results[0].formatted, 'Dirección 1');
      expect(results[1].formatted, 'Dirección 2');
    });

    test('descarta features inválidos sin romper el resto', () {
      final response = {
        'features': [
          featureJson(formatted: 'Válida'),
          {'properties': null},
        ],
      };

      final results = GeoapifySuggestion.listFromResponse(response);

      expect(results, hasLength(1));
      expect(results.single.formatted, 'Válida');
    });

    test('respuesta sin "features" → lista vacía, nunca lanza', () {
      expect(GeoapifySuggestion.listFromResponse({}), isEmpty);
      expect(GeoapifySuggestion.listFromResponse(null), isEmpty);
      expect(GeoapifySuggestion.listFromResponse('inesperado'), isEmpty);
    });
  });

  group('GeoapifySuggestion.firstFromResponse', () {
    test('devuelve el primer resultado', () {
      final response = {
        'features': [featureJson(formatted: 'Primera')],
      };
      expect(
        GeoapifySuggestion.firstFromResponse(response)?.formatted,
        'Primera',
      );
    });

    test('respuesta vacía → null', () {
      expect(GeoapifySuggestion.firstFromResponse({'features': []}), isNull);
    });
  });
}
