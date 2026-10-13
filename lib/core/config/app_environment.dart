import 'package:celtas_mobile/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

enum AppEnvironment { production, dev }

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;
}

AppEnvironment selectEnvironment({required String? flavor, required bool dev}) {
  if (flavor == 'dev' && dev) return AppEnvironment.dev;
  if (flavor == null && !dev) return AppEnvironment.production;
  throw const ConfigurationException('La selección de entorno no es válida.');
}

/// DEV must be explicitly supplied; never reads the production asset.
class DevConfiguration {
  DevConfiguration(Map<String, String> values) {
    String requiredValue(String key) {
      final value = values[key]?.trim() ?? '';
      if (value.isEmpty) {
        throw const ConfigurationException(
          'Falta configuración DEV autorizada. Revisa la configuración y reintenta.',
        );
      }
      return value;
    }

    if (requiredValue('ENVIRONMENT') != 'dev' ||
        requiredValue('DEV_SERVICES_AUTHORIZED') != 'true') {
      throw const ConfigurationException(
        'La configuración no está autorizada para DEV.',
      );
    }
    final backend = Uri.tryParse(requiredValue('API_BASE_URL'));
    if (backend == null ||
        backend.scheme != 'https' ||
        backend.host.isEmpty ||
        backend.userInfo.isNotEmpty ||
        backend.hasQuery ||
        backend.hasFragment ||
        backend.host.toLowerCase().replaceAll(RegExp(r'\.$'), '') ==
            'backend-celtas.onrender.com') {
      throw const ConfigurationException(
        'El backend seleccionado no es válido para DEV.',
      );
    }
    final project = requiredValue('FIREBASE_PROJECT_ID');
    final sender = requiredValue('FIREBASE_MESSAGING_SENDER_ID');
    final app = requiredValue('FIREBASE_APP_ID');
    final google = requiredValue('GOOGLE_SERVER_CLIENT_ID');
    final apiKey = requiredValue('FIREBASE_API_KEY');
    if (project.toLowerCase() == DefaultFirebaseOptions.android.projectId ||
        sender == DefaultFirebaseOptions.android.messagingSenderId ||
        apiKey == DefaultFirebaseOptions.android.apiKey ||
        !app.startsWith('1:$sender:android:') ||
        !google.endsWith('.apps.googleusercontent.com') ||
        !google.startsWith('$sender-')) {
      throw const ConfigurationException(
        'Firebase u OAuth no son válidos para DEV.',
      );
    }
    firebase = FirebaseOptions(
      apiKey: apiKey,
      appId: app,
      messagingSenderId: sender,
      projectId: project,
    );
  }

  late final FirebaseOptions firebase;
}
