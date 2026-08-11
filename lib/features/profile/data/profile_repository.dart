import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:dio/dio.dart';

/// Repositorio de perfil contra el backend real.
///
/// Endpoints (contrato verificado contra `celtas-backend/src/modules/users/
/// users.controller.ts` + `dto/update-profile.dto.ts`):
///   - `GET /users/me` → perfil actual leído de la BD (no del payload del
///     JWT), mismo shape que el `User` de auth.
///   - `PATCH /users/me` con `{ fullName?, phone? }` → 200 con el perfil
///     actualizado. `email`, `password`, `provider`, `role` y `totalSpent`
///     NO son editables — el backend los rechaza con 400
///     (`forbidNonWhitelisted`) si vienen en el body.
class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<User> getProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      return User.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<User> updateProfile({String? fullName, String? phone}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: {
          'fullName': ?fullName,
          'phone': ?phone,
        },
      );
      return User.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
