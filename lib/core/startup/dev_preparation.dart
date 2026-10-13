import 'package:celtas_mobile/core/config/app_environment.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/startup/app_preparation_controller.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppPreparationController devPreparation({
  required String? flavor,
  required bool enabled,
  required String configuration,
  Future<String> Function()? packageId,
  Future<void> Function(FirebaseOptions)? initializeFirebase,
  Future<SharedPreferences> Function()? loadPreferences,
}) {
  DevConfiguration? validated;
  return AppPreparationController(
    loadPreferences: loadPreferences,
    // No NotificationService: FCM validation is a separate authorized phase.
    loadConfiguration: () async {
      if (!kDebugMode ||
          defaultTargetPlatform != TargetPlatform.android ||
          selectEnvironment(flavor: flavor, dev: enabled) !=
              AppEnvironment.dev) {
        throw const ConfigurationException(
          'DEV requiere Android debug y selección explícita.',
        );
      }
      final actualPackage =
          await (packageId?.call() ??
              PackageInfo.fromPlatform().then((info) => info.packageName));
      if (actualPackage != 'com.celtas.celtas_mobile.dev') {
        throw const ConfigurationException(
          'El identificador de la aplicación no corresponde a DEV.',
        );
      }
      if (configuration.trim().isEmpty) {
        throw const ConfigurationException(
          'Falta configuración DEV autorizada. Revisa la configuración y reintenta.',
        );
      }
      // Parse in a separate instance so invalid values cannot reach providers.
      final candidate = DotEnv()..loadFromString(envString: configuration);
      validated = DevConfiguration(candidate.env);
      dotenv.loadFromString(envString: configuration);
      restrictDevBackend(
        ApiClient.instance.dio,
        candidate.env['API_BASE_URL']!,
      );
    },
    initializeFirebase: () async {
      final options = validated!.firebase;
      if (initializeFirebase != null) {
        await initializeFirebase(options);
      } else {
        await Firebase.initializeApp(options: options);
      }
    },
  );
}

/// DEV must not follow backend redirects or send credentials to another origin.
void restrictDevBackend(Dio dio, String baseUrl) {
  final allowed = Uri.parse(baseUrl);
  dio.options.baseUrl = baseUrl;
  dio.options.followRedirects = false;
  dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (request, handler) {
        final target = request.uri;
        if (target.scheme != allowed.scheme ||
            target.host != allowed.host ||
            target.port != allowed.port ||
            request.followRedirects ||
            target.path
                .replaceAll(RegExp(r'/+$'), '')
                .endsWith('/users/me/fcm-token')) {
          handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.cancel,
              error: const ConfigurationException(
                'Destino u operación no autorizados para DEV.',
              ),
            ),
          );
          return;
        }
        handler.next(request);
      },
    ),
  );
}
