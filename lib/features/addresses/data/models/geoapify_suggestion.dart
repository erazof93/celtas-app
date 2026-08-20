/// Resultado de Autocomplete/Geocoding/Reverse Geocoding de Geoapify, ya
/// parseado a los campos que esta app necesita.
///
/// Shape de la respuesta REAL de Geoapify (GeoJSON `FeatureCollection`,
/// `features[].properties` + `features[].geometry.coordinates`) verificado
/// contra los fixtures oficiales del widget `@geoapify/geocoder-autocomplete`
/// (`tests/test-data.ts` y `tests/test-data/mock-geocoder-response-with-
/// categories.json` del repo `geoapify/geocoder-autocomplete` en GitHub, que
/// consume exactamente estas mismas APIs) — no inventado de memoria. Mismos
/// endpoints/formato para las tres APIs (`/v1/geocode/autocomplete`,
/// `/v1/geocode/search`, `/v1/geocode/reverse`).
///
/// Sin dependencia de `dio` ni de red — puro y testeable con `Map` fijos,
/// mismo criterio que `NotificationTarget.fromPayload`.
class GeoapifySuggestion {
  const GeoapifySuggestion({
    required this.formatted,
    required this.latitude,
    required this.longitude,
    this.addressLine1,
    this.addressLine2,
    this.district,
    this.suburb,
    this.city,
    this.street,
    this.housenumber,
    this.name,
  });

  /// Dirección completa en una línea (`properties.formatted`). NO usar
  /// directo para autollenar `fullAddress` — ver [bestFullAddress].
  final String formatted;
  final double latitude;
  final double longitude;

  final String? addressLine1;
  final String? addressLine2;

  /// `properties.street`/`properties.housenumber`: el nombre de la calle y
  /// el número, si Geoapify pudo resolverlos — independientes de si el
  /// resultado principal es una dirección o un POI (ver [bestFullAddress]).
  final String? street;
  final String? housenumber;

  /// `properties.name`: nombre del POI cuando el resultado principal es uno
  /// (colegio, parque, negocio) — solo se usa para detectar el caso descrito
  /// en [bestFullAddress] en el que Geoapify "rellena" `street` con este
  /// mismo valor por no tener un segmento de calle real que ofrecer.
  final String? name;

  /// `properties.district`: presente en algunas ciudades (confirmado en el
  /// fixture oficial para distritos de París), pero NO garantizado para
  /// direcciones de Lima/San Juan de Miraflores — de ahí [bestDistrict].
  final String? district;
  final String? suburb;
  final String? city;

  /// Mejor esfuerzo para el campo `district` del formulario.
  ///
  /// `city` primero: confirmado en dispositivo real que para direcciones de
  /// San Juan de Miraflores (el único distrito donde opera Celtas — ver
  /// CLAUDE.md), `properties.city` de Geoapify trae el distrito peruano real
  /// ("San Juan de Miraflores"), mientras que `properties.district` trae una
  /// subzona/barrio OSM más fino ("El Arenal") que NO es el distrito
  /// administrativo — confundía el autollenado del formulario. `district` se
  /// deja como último fallback (nunca se descarta del todo: en otras
  /// jerarquías OSM, ej. París, sí corresponde a una división administrativa
  /// real) por si `city`/`suburb` vienen vacíos.
  String? get bestDistrict {
    final c = city;
    if (c != null && c.trim().isNotEmpty) return c;
    final s = suburb;
    if (s != null && s.trim().isNotEmpty) return s;
    final d = district;
    if (d != null && d.trim().isNotEmpty) return d;
    return null;
  }

  /// Mejor esfuerzo para el campo `fullAddress` del formulario: prioriza
  /// calle + número sobre `properties.formatted`.
  ///
  /// Confirmado en dispositivo real (Reverse Geocoding, tanto por GPS como
  /// por drag del mapa): Geoapify devuelve el feature indexado más cercano
  /// al punto, que muy seguido es un POI (colegio, parque, negocio) en vez
  /// del segmento de calle — `formatted` entonces arranca con
  /// "Institución Educativa X, Jirón Y, ..." en lugar de "Jirón Y ###". Los
  /// campos `street`/`housenumber` vienen resueltos por separado incluso
  /// cuando el resultado principal es un POI, así que se arma la dirección a
  /// mano a partir de ellos en vez de confiar en `formatted`. Cae a
  /// `formatted` si Geoapify no devolvió ningún `street` (ej. zonas rurales
  /// sin nomenclatura vial en OSM), o si `street` resultó ser el mismo
  /// texto que `name` — confirmado en dispositivo real que, para un POI sin
  /// segmento de calle indexado cerca (ej. un parque), Geoapify "rellena"
  /// `properties.street` con el propio nombre del POI (`street: "Parque
  /// Cáceres"`, igual que `name: "Parque Cáceres"`) en vez de dejarlo
  /// vacío — sin este chequeo, el POI se colaba disfrazado de calle.
  String get bestFullAddress {
    final s = street;
    if (s == null || s.trim().isEmpty) return formatted;
    final n = name;
    if (n != null && n.trim().isNotEmpty && s.trim() == n.trim()) {
      return formatted;
    }
    final h = housenumber;
    final streetPart = (h != null && h.trim().isNotEmpty) ? '$s $h' : s;
    final d = bestDistrict;
    return (d != null && d.trim().isNotEmpty) ? '$streetPart, $d' : streetPart;
  }

  /// Parsea un único `Feature` del GeoJSON. Devuelve `null` (nunca lanza) si
  /// falta cualquier campo indispensable (`lat`/`lon`/`formatted`) — un
  /// resultado incompleto de Geoapify se descarta en vez de romper la lista
  /// de sugerencias.
  static GeoapifySuggestion? fromFeature(Object? feature) {
    if (feature is! Map) return null;
    final properties = feature['properties'];
    if (properties is! Map) return null;

    final lat = _asDouble(properties['lat']);
    final lon = _asDouble(properties['lon']);
    final formatted = properties['formatted'];
    if (lat == null || lon == null || formatted is! String) return null;

    return GeoapifySuggestion(
      formatted: formatted,
      latitude: lat,
      longitude: lon,
      addressLine1: properties['address_line1'] as String?,
      addressLine2: properties['address_line2'] as String?,
      district: properties['district'] as String?,
      suburb: properties['suburb'] as String?,
      city: properties['city'] as String?,
      street: properties['street'] as String?,
      housenumber: properties['housenumber'] as String?,
      name: properties['name'] as String?,
    );
  }

  /// Parsea la respuesta completa (`{ type: 'FeatureCollection', features:
  /// [...] }`) de Autocomplete/Geocoding en una lista de sugerencias. Nunca
  /// lanza: una respuesta con forma inesperada da lista vacía.
  static List<GeoapifySuggestion> listFromResponse(Object? json) {
    if (json is! Map) return const [];
    final features = json['features'];
    if (features is! List) return const [];
    return features
        .map(fromFeature)
        .whereType<GeoapifySuggestion>()
        .toList(growable: false);
  }

  /// Igual que [listFromResponse] pero devuelve solo el primer resultado (o
  /// `null`) — para Geocoding/Reverse Geocoding, donde solo interesa el
  /// candidato más relevante (`limit=1`).
  static GeoapifySuggestion? firstFromResponse(Object? json) {
    final list = listFromResponse(json);
    return list.isEmpty ? null : list.first;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }
}
