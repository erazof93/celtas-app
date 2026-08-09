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
///
/// IMPORTANTE: el `GoRouter` se crea UNA sola vez. Recrearlo en cada cambio de
/// estado de auth (como hacía un `ref.watch` directo) lo reinicia en
/// `initialLocation` (`/`) y la app "salta" al Splash tras cada login/logout.
/// En su lugar, `ref.listen` + `router.refresh()` re-ejecuta el redirect con el
/// estado nuevo sin perder la ubicación actual.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      if (status == AuthStatus.unknown) return null;

      final location = state.matchedLocation;
      final isProtected = location == '/home';

      if (status == AuthStatus.authenticated) {
        // `/` es el Splash: con sesión activa no tiene sentido quedarse ahí.
        if (location == '/login' ||
            location == '/register' ||
            location == '/') {
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

  // Re-ejecuta el redirect cuando cambia el estado de auth, sin recrear el
  // router (evita el salto al Splash tras login/logout).
  ref.listen(authControllerProvider, (_, _) => router.refresh());

  return router;
});