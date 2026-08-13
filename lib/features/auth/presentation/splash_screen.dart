import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// Splash / onboarding (pantalla 01 del mockup).
///
/// Mientras el `AuthController` hace bootstrap de la sesión (refresh con el
/// token persistido) muestra la marca con un spinner. Si no hay sesión, pasa
/// al modo onboarding con el botón COMENZAR. Si el bootstrap falló por un
/// error transitorio (backend dormido), ofrece REINTENTAR conservando la
/// sesión.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Gradiente radial naranja en la base (del CSS real del mockup).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.2,
                  colors: [
                    CeltasColors.orange.withValues(alpha: 0.35),
                    CeltasColors.orange.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.6],
                  center: const Alignment(0, 1),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  SvgPicture.asset(
                    'assets/branding/iconos.svg',
                    width: 88,
                    height: 88,
                    colorFilter: const ColorFilter.mode(
                      CeltasColors.gold,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'CELTAS',
                    style: textTheme.displayLarge?.copyWith(
                      fontSize: 44,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'CARNE AL FUEGO. DIRECTO A TU PUERTA.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CeltasColors.textLabel,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(flex: 3),
                  _buildBottom(context, ref, authState),
                  const SizedBox(height: 56),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottom(BuildContext context, WidgetRef ref, AuthState authState) {
    switch (authState.status) {
      case AuthStatus.unknown:
        // Bootstrap en curso: spinner + aviso si el backend tarda (cold start
        // de Render, 30-50s la primera request tras inactividad).
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: CircularProgressIndicator(),
            ),
            SlowBackendNotice(),
          ],
        );
      case AuthStatus.error:
        // Error transitorio: se conserva la sesión, se ofrece reintentar.
        return Column(
          children: [
            Text(
              'No pudimos restaurar tu sesión.\nRevisa tu conexión e inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CeltasColors.redLight,
                    fontSize: 13,
                  ),
            ),
            const SizedBox(height: 16),
            CeltasButton(
              label: 'REINTENTAR',
              angled: true,
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).bootstrap(),
            ),
          ],
        );
      case AuthStatus.unauthenticated:
        // Onboarding: indicador de pasos + COMENZAR → Login.
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CeltasColors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CeltasColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CeltasColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            CeltasButton(
              label: 'COMENZAR',
              angled: true,
              onPressed: () => context.go('/login'),
            ),
          ],
        );
      case AuthStatus.authenticated:
        // El router redirige a /home; mientras tanto, spinner.
        return const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: CircularProgressIndicator(),
        );
    }
  }
}