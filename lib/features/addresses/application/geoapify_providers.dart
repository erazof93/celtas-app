import 'package:celtas_mobile/features/addresses/data/geoapify_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instancia única de `dio` configurada para Geoapify (base URL propia, sin
/// los interceptores del backend de Celtas — ver `buildGeoapifyDio`).
final geoapifyDioProvider = Provider((ref) => buildGeoapifyDio());

/// Repositorio de Geoapify (Autocomplete/Geocoding/Reverse Geocoding).
final geoapifyRepositoryProvider = Provider<GeoapifyRepository>(
  (ref) => GeoapifyRepository(ref.read(geoapifyDioProvider)),
);
