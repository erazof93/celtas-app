import 'package:celtas_mobile/features/auth/application/auth_controller.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';

/// Screen fixtures already simulate authenticated backend responses. Supply
/// that session without starting unrelated native storage/network restoration.
/// Tests of restoration and account transitions use the real controller.
class AuthenticatedScreenTestController extends AuthController {
  @override
  AuthState build() => AuthState.authenticated(
    accessToken: 'screen-test-access',
    user: User(
      id: 'screen-test-user',
      email: 'screen-test@example.invalid',
      fullName: 'Usuario de prueba',
      provider: UserProvider.local,
      totalSpent: 0,
      role: UserRole.cliente,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
}
