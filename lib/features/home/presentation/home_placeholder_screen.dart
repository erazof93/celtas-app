import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder del módulo 1 para verificar el flujo de sesión end-to-end
/// (login → home → logout). El módulo 2 lo reemplaza por el Home real con
/// bottom nav.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CeltasSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Sesión iniciada',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                user?.fullName ?? '—',
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                user?.email ?? '—',
                style: textTheme.bodyMedium?.copyWith(
                  color: CeltasColors.textMuted,
                ),
              ),
              const Spacer(),
              CeltasButton(
                label: 'CERRAR SESIÓN',
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}