import 'package:celtas_mobile/core/config/env.dart';
import 'package:celtas_mobile/features/addresses/data/models/geoapify_suggestion.dart';
import 'package:dio/dio.dart';

/// Cliente HTTP dedicado a Geoapify.
///
/// Deliberadamente NO reutiliza `ApiClient.instance.dio`: ese cliente apunta
/// al backend de Celtas y sus interceptores (adjuntar `Authorization`,
/// desenvolver el envelope `{ success, data }`, refresh de sesión en 401) no
/// aplican a `api.geoapify.com` — mezclar ambos rompería silenciosamente
/// cualquiera de los dos. Sin SDK propio de Geoapify: son endpoints REST
/// simples, no lo justifican (ver skill `geoapify-direcciones`).
Dio buildGeoapifyDio() => Dio(
  BaseOptions(
    baseUrl: 'https://api.geoapify.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
);

/// Autocomplete/Geocoding/Reverse Geocoding de Geoapify.
///
/// Regla no negociable de la skill `geoapify-direcciones`: el rate limit
/// (5 req/seg) es compartido por TODA la app, no por usuario, y un fallo acá
/// (429 u otro) nunca debe romper la pantalla ni bloquear que el usuario
/// guarde su dirección con lo que ya tiene. Por eso ningún método de esta
/// clase lanza — todos devuelven `[]`/`null` ante cualquier error, silencioso
/// a propósito (no hay una superficie de "reintentar" para el
/// autocompletado: el usuario simplemente puede seguir escribiendo, usar el
/// mapa, o usar el GPS).
class GeoapifyRepository {
  GeoapifyRepository(this._dio);

  final Dio _dio;

  /// `true` si hay una API key configurada en `.env`. Los callers deberían
  /// chequear esto antes de mostrar la UI de autocompletado/mapa como
  /// "disponible" (sin key, Geoapify devuelve 401 en cada request — mejor no
  /// disparar requests que van a fallar siempre).
  bool get hasApiKey =>
      AppConfig.geoapifyApiKey != null && AppConfig.geoapifyApiKey!.isNotEmpty;

  /// Sugerencias de direcciones mientras el usuario escribe.
  /// `GET /v1/geocode/autocomplete`. El caller es responsable del debounce
  /// (~300-500ms) — este método no lo aplica, dispara la request de
  /// inmediato al ser llamado.
  Future<List<GeoapifySuggestion>> autocomplete(String text) async {
    final query = text.trim();
    if (!hasApiKey || query.isEmpty) return const [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/geocode/autocomplete',
        queryParameters: {
          'text': query,
          'apiKey': AppConfig.geoapifyApiKey,
          'lang': 'es',
          'filter': 'countrycode:pe',
          'limit': 5,
        },
      );
      return GeoapifySuggestion.listFromResponse(response.data);
    } on DioException {
      // Incluye 429 (rate limit compartido) y cualquier otro fallo de red:
      // sin sugerencias nuevas, el usuario sigue escribiendo o usa mapa/GPS.
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Texto completo → coordenadas (fallback cuando el usuario no pasó por el
  /// autocompletado, ej. pegó una dirección completa de una vez).
  /// `GET /v1/geocode/search`.
  Future<GeoapifySuggestion?> geocode(String text) async {
    final query = text.trim();
    if (!hasApiKey || query.isEmpty) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/geocode/search',
        queryParameters: {
          'text': query,
          'apiKey': AppConfig.geoapifyApiKey,
          'lang': 'es',
          'filter': 'countrycode:pe',
          'limit': 1,
        },
      );
      return GeoapifySuggestion.firstFromResponse(response.data);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Coordenadas → texto, para autocompletar `fullAddress`/`district` en
  /// cuanto el usuario suelta el pin en el mapa (por GPS o por drag manual).
  /// `GET /v1/geocode/reverse`.
  Future<GeoapifySuggestion?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!hasApiKey) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/geocode/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'apiKey': AppConfig.geoapifyApiKey,
          'lang': 'es',
        },
      );
      return GeoapifySuggestion.firstFromResponse(response.data);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
