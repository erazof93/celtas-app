import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/presentation/login_screen.dart';
import 'package:celtas_mobile/features/auth/presentation/register_screen.dart';
import 'package:celtas_mobile/features/auth/presentation/splash_screen.dart';
import 'package:celtas_mobile/features/home/presentation/home_placeholder_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Router de la app.
///
/// Módulo 1: rutas de auth + placeholder de Home. El módulo 2 agrega la shell
/// route con bottom nav y el resto de las rutas protegidas.
///
/// Guard de sesión: mientras el estado es `unknown` (bootstrap en curso) el
/// Splash decide; autenticado → se bloquea Login/Registro y se va a /home;
/// sin sesión → las rutas protegidas redirigen a /login.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final status = authState.status;
      if (status == AuthStatus.unknown) return null;

      final location = state.matchedLocation;
      final isProtected = location == '/home';

      if (status == AuthStatus.authenticated) {
        if (location == '/login' || location == '/register') {
          return '/home';
        }
        return null;
      }

      // unauthenticated o error transitorio: rutas protegidas → login.
      if (isProtected) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
    ],
  );
});