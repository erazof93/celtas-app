import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_tokens.freezed.dart';
part 'auth_tokens.g.dart';

/// Payload de `POST /auth/login`, `POST /auth/register`, `POST /auth/google`
/// y `POST /auth/refresh` (rotación de tokens: cada refresh emite un
/// `refreshToken` nuevo que hay que persistir).
///
/// Contrato verificado contra `celtas-backend/src/modules/auth/auth.service.ts`
/// (interfaz `AuthTokens & { user: User }`) y
/// `celtas-admin/src/features/auth/types.ts`.
@freezed
abstract class AuthTokens with _$AuthTokens {
  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    required User user,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);
}