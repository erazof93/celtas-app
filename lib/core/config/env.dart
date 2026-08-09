import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de entorno leída desde `.env` via `flutter_dotenv`.
///
/// Valores por defecto orientados a desarrollo: si `.env` falta o no define
/// `API_BASE_URL`, se apunta al backend de producción.
class AppConfig {
  AppConfig._();

  static final String apiBaseUrl =
      dotenv.env['API_BASE_URL'] ?? 'https://backend-celtas.onrender.com';
}