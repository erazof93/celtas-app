import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/application/auth_controller.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro del dispositivo (refresh token).
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Repositorio de auth contra el backend real.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ApiClient.instance.dio,
    ref.watch(secureStorageProvider),
  ),
);

/// Estado de la sesión: `accessToken` en memoria + `user` actual.
///
/// El `accessToken` se pierde al cerrar la app a propósito; al reabrir, el
/// `bootstrap()` lo recupera vía refresh con el `refreshToken` de
/// `flutter_secure_storage`.
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);