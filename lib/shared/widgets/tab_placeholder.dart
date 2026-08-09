import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Placeholder genérico para los tabs que se completan en módulos posteriores.
///
/// Mismo estilo que el placeholder de Home del módulo 1: título en Cinzel
/// (headlineMedium), descripción muted, padding de página, fondo negro del
/// tema. Cada tab lo usa con su título y una nota de qué módulo lo completa.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CeltasSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(title, style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: CeltasColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}