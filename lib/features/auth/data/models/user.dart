import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Proveedor con el que se creó la cuenta (contrato real del backend:
/// `UserProvider` en `user.entity.ts`).
enum UserProvider { local, google }

/// Rol del usuario (contrato real del backend: `UserRole` en `user.entity.ts`).
enum UserRole { cliente, admin }

/// Usuario autenticado, tal como lo devuelve el backend en el payload de
/// `POST /auth/login`, `POST /auth/register`, `POST /auth/google` y
/// `POST /auth/refresh` (campo `user` dentro de `data`).
///
/// Contrato verificado contra `celtas-backend/src/modules/users/entities/
/// user.entity.ts` y `celtas-admin/src/features/auth/types.ts`. El campo
/// `password` está excluido por el backend (`@Exclude()`), nunca llega.
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String fullName,
    required UserProvider provider,
    String? googleId,
    String? phone,
    String? fcmToken,
    required double totalSpent,
    required UserRole role,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}