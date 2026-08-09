import 'package:celtas_mobile/shared/widgets/tab_placeholder.dart';
import 'package:flutter/material.dart';

/// Placeholder del tab Perfil — se completa en el módulo 6 (Perfil +
/// Direcciones: `GET`/`PATCH /users/me`, CRUD de direcciones, logout).
class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholder(
      title: 'Perfil',
      description: 'Tu perfil y direcciones aparecerán acá (módulo 6).',
    );
  }
}