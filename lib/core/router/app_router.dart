import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/presentation/login_screen.dart';
import 'package:celtas_mobile/features/auth/presentation/register_screen.dart';
import 'package:celtas_mobile/features/auth/presentation/splash_screen.dart';
import 'package:celtas_mobile/features/coupons/presentation/coupons_placeholder_screen.dart';
import 'package:celtas_mobile/features/home/presentation/home_screen.dart';
import 'package:celtas_mobile/features/orders/presentation/orders_placeholder_screen.dart';
import 'package:celtas_mobile/features/profile/presentation/profile_placeholder_screen.dart';
import 'package:celtas_mobile/shared/widgets/celtas_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Rutas raíz de los branches del shell (protegidas). Las rutas anidadas de
/// cada tab (ej. `/orders/123`, `/profile/addresses`) heredan la protección
/// por prefijo.
const _shellPaths = ['/home', '/orders', '/coupons', '/profile'];

bool _isShellPath(String location) =>
    _shellPaths.any((p) => location == p || location.startsWith('$p/'));

/// Router de la app.
///
/// Módulo 2: shell route con bottom nav persistente (Inicio, Pedidos, Cupones,
/// Perfil) usando `StatefulShellRoute.indexedStack` — cada tab mantiene su
/// propio stack de navegación (Home → detalle de producto, Pedidos → detalle
/// de pedido, etc.), que es lo que necesitan los módulos 3-8.
///
/// Guard de sesión: mientras el estado es `unknown` (bootstrap en curso) el
/// Splash decide; autenticado → se bloquea Login/Registro y se va a /home;
/// sin sesión → las rutas del shell redirigen a /login.
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

      if (status == AuthStatus.authenticated) {
        // `/` es el Splash: con sesión activa no tiene sentido quedarse ahí.
        if (location == '/login' ||
            location == '/register' ||
            location == '/') {
          return '/home';
        }
        return null;
      }

      // unauthenticated o error transitorio: rutas del shell → login.
      if (_isShellPath(location)) return '/login';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _ShellScaffold(
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrdersPlaceholderScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coupons',
                builder: (context, state) => const CouponsPlaceholderScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePlaceholderScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Re-ejecuta el redirect cuando cambia el estado de auth, sin recrear el
  // router (evita el salto al Splash tras login/logout).
  ref.listen(authControllerProvider, (_, _) => router.refresh());

  return router;
});

/// Scaffold del shell: el body es el `navigationShell` (el tab activo) y el
/// bottom nav es persistente. El tema (fondo negro, tipografía) viene del
/// `MaterialApp.router` y aplica a todo el shell.
class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CeltasBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Al tocar el tab ya activo no se re-pushea la rama (evita duplicar
          // el stack de ese tab).
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}