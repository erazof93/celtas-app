import 'package:celtas_mobile/features/addresses/presentation/addresses_screen.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/presentation/login_screen.dart';
import 'package:celtas_mobile/features/auth/presentation/register_screen.dart';
import 'package:celtas_mobile/features/auth/presentation/splash_screen.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/cart/presentation/cart_screen.dart';
import 'package:celtas_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:celtas_mobile/features/coupons/presentation/coupons_screen.dart';
import 'package:celtas_mobile/features/home/presentation/home_screen.dart';
import 'package:celtas_mobile/features/menu/presentation/product_detail_screen.dart';
import 'package:celtas_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:celtas_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:celtas_mobile/features/orders/presentation/orders_screen.dart';
import 'package:celtas_mobile/features/profile/presentation/profile_screen.dart';
import 'package:celtas_mobile/features/rewards/presentation/reward_redeem_screen.dart';
import 'package:celtas_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:celtas_mobile/shared/widgets/celtas_bottom_nav.dart';
import 'package:celtas_mobile/shared/widgets/celtas_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Rutas que requieren sesión (prefijos del shell + rutas a pantalla completa
/// empujadas sobre el shell: detalle de producto, carrito, checkout). Las
/// rutas anidadas de cada tab (ej. `/orders/123`) heredan la protección por
/// prefijo.
const _protectedPaths = [
  '/home',
  '/orders',
  '/coupons',
  '/rewards',
  '/profile',
  '/product',
  '/cart',
  '/checkout',
  '/addresses',
  '/notifications',
];

bool _isProtectedPath(String location) =>
    _protectedPaths.any((p) => location == p || location.startsWith('$p/'));

/// Router de la app.
///
/// Módulo 2: shell route con bottom nav persistente (Inicio, Pedidos, Cupones,
/// Estrellas, Perfil) usando `StatefulShellRoute.indexedStack` — cada tab
/// mantiene su propio stack de navegación (Home → detalle de producto,
/// Pedidos → detalle de pedido, etc.), que es lo que necesitan los módulos
/// 3-8 y la feature de Estrellas.
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
      if (_isProtectedPath(location)) return '/login';
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
      // Detalle de producto: se empuja sobre el shell (sin bottom nav,
      // como el mockup 05). El producto se resuelve desde el menú ya cargado.
      // `extra` opcional: el `CartItem` que se está editando (ícono de lápiz
      // del carrito) — precarga cantidad/salsas y cambia el flujo de
      // `_addToCart` a `updateLine`, ver `product_detail_screen.dart`.
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
          editingItem: state.extra as CartItem?,
        ),
      ),
      // Carrito: pantalla completa sobre el shell (mockup 06, sin bottom nav).
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      // Checkout: dirección + resumen + confirmación por WhatsApp (módulo 5).
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      // Direcciones guardadas: CRUD completo, empujada desde Perfil (módulo 6,
      // mockup 09, sin bottom nav).
      GoRoute(
        path: '/addresses',
        builder: (context, state) => const AddressesScreen(),
      ),
      // Historial de notificaciones: empujada desde la campana del Home (sin
      // bottom nav, mismo criterio que carrito/direcciones). Sin mockup
      // correspondiente en design-reference/ — pantalla nueva.
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Detalle de pedido: empujado desde el listado del tab Pedidos (módulo
      // 7, mockup 11, sin bottom nav — igual que detalle de producto).
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => OrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      // Canje de un premio ya desbloqueado: empujada desde el botón
      // "Canjear" de `RewardsScreen`, sin bottom nav — mismo patrón que
      // `/product/:id`. `/rewards` (abajo) ya cubre este prefijo en
      // `_isProtectedPath`, no hace falta una entrada separada.
      GoRoute(
        path: '/rewards/redeem/:redemptionId',
        builder: (context, state) => RewardRedeemScreen(
          redemptionId: state.pathParameters['redemptionId']!,
        ),
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
                builder: (context, state) => const OrdersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coupons',
                builder: (context, state) => const CouponsScreen(),
              ),
            ],
          ),
          // Orden confirmado en el mockup aprobado: Inicio - Pedidos -
          // Cupones - Estrellas - Perfil. Esta rama tiene que estar en la
          // misma posición que `CeltasNavItem.rewards` en el enum (índice 3)
          // — `StatefulShellBranch` número `i` corresponde a
          // `CeltasNavItem.values[i]`.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rewards',
                builder: (context, state) => const RewardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
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
///
/// Las 4 rutas del shell (`/home`, `/orders`, `/coupons`, `/profile`) son la
/// base de la pila de navegación — todo lo demás (carrito, checkout, detalle
/// de producto/pedido, direcciones) se empuja como ruta top-level *sobre*
/// el shell (ver rutas arriba, ninguna vive dentro de un `StatefulShellBranch`).
/// Por eso el `PopScope` de doble-atrás solo necesita vivir acá: cuando hay
/// algo empujado encima, el back del sistema lo pop-ea a eso primero y nunca
/// llega a este widget; solo llega cuando el shell es la ruta visible.
class _ShellScaffold extends StatefulWidget {
  const _ShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<_ShellScaffold> {
  static const _confirmWindow = Duration(seconds: 2);

  DateTime? _lastBackPressAt;

  void _handleBackPress() {
    final now = DateTime.now();
    final last = _lastBackPressAt;
    if (last != null && now.difference(last) < _confirmWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressAt = now;
    showCeltasSnackBar(
      context,
      'Presiona de nuevo para salir',
      // Coincide con el default del helper, pero se pasa explícito a
      // propósito: liga la duración del SnackBar a `_confirmWindow`, la
      // misma ventana que usa la comparación de arriba, para que no puedan
      // desincronizarse si alguna cambia por separado en el futuro.
      // ignore: avoid_redundant_argument_values
      duration: _confirmWindow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: CeltasBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) => widget.navigationShell.goBranch(
            index,
            // Al tocar el tab ya activo no se re-pushea la rama (evita
            // duplicar el stack de ese tab).
            initialLocation: index == widget.navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}