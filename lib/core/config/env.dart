import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de entorno leída desde `.env` via `flutter_dotenv`.
///
/// Valores por defecto orientados a desarrollo: si `.env` falta o no define
/// `API_BASE_URL`, se apunta al backend de producción.
class AppConfig {
  AppConfig._();

  static final String apiBaseUrl =
      dotenv.env['API_BASE_URL'] ?? 'https://backend-celtas.onrender.com';

  /// Client ID "Web application" de Google Cloud (proyecto `celtas-b0bd5`),
  /// el mismo que usa el backend para verificar el `idToken` en
  /// `POST /auth/google`. Se pasa a `GoogleSignIn.initialize(serverClientId:)`
  /// para que la SDK emita un idToken verificable por el servidor.
  ///
  /// En Android el Client ID de tipo "Android" se vincula por package name +
  /// SHA-1 (google-services.json), no se pega en código.
  static final String? googleServerClientId =
      dotenv.env['GOOGLE_SERVER_CLIENT_ID'];

  /// API key de Geoapify (Address Autocomplete/Geocoding/Reverse
  /// Geocoding/Map Tiles) — una sola key compartida por toda la app, rate
  /// limit de 5 req/seg TOTAL (ver skill `geoapify-direcciones`). `null`/
  /// vacía si todavía no se pegó en `.env`: `GeoapifyRepository` lo trata
  /// como "sin autocompletado disponible" en vez de lanzar, mismo criterio
  /// "nunca rompe la pantalla" que el resto de esta feature.
  static final String? geoapifyApiKey = dotenv.env['GEOAPIFY_API_KEY'];
}