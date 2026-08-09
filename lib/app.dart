import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raíz de la app: tema + (en módulos siguientes) router y providers de sesión.
class CeltasApp extends StatelessWidget {
  const CeltasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Celtas',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _SetupPlaceholder(),
      ),
    );
  }
}

/// Pantalla temporal del módulo 0: desaparece cuando arranque el router real.
class _SetupPlaceholder extends StatelessWidget {
  const _SetupPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Celtas — módulo 0'),
      ),
    );
  }
}