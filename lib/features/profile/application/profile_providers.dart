import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de perfil contra el backend real.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ApiClient.instance.dio),
);

/// Perfil del usuario autenticado (`GET /users/me`), leído fresco de la BD en
/// vez de reusar el `user` cacheado del login (puede haber cambiado, ej.
/// editado desde el panel admin).
///
/// `AsyncNotifier` en vez de `FutureProvider` porque tras `PATCH /users/me`
/// se actualiza el estado local con la respuesta real del backend (sin
/// re-fetch) y además se sincroniza `authControllerProvider.user` para que el
/// resto de la app vea el cambio.
class ProfileNotifier extends AsyncNotifier<User> {
  @override
  Future<User> build() {
    // Keep-alive (sin autoDispose): sin esto, tras logout + login de OTRA
    // cuenta en el mismo dispositivo, `profileProvider` sigue devolviendo el
    // user anterior hasta que algo más fuerce un re-fetch — bug latente
    // documentado en `test/features/profile/application/
    // profile_stale_user_repro_test.dart`. Se invalida solo (no desde
    // `AuthController.logout()`, que invertiría la dependencia auth→profile)
    // cada vez que cambia el `id` del user autenticado, cubriendo tanto
    // logout (→ null) como login de una cuenta distinta.
    ref.listen(authControllerProvider.select((s) => s.user?.id), (_, _) {
      ref.invalidateSelf();
    });
    return ref.read(profileRepositoryProvider).getProfile();
  }

  Future<void> updateProfile({String? fullName, String? phone}) async {
    final updated = await ref.read(profileRepositoryProvider).updateProfile(
          fullName: fullName,
          phone: phone,
        );
    state = AsyncData(updated);
    ref.read(authControllerProvider.notifier).updateUser(updated);
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, User>(
  ProfileNotifier.new,
);
