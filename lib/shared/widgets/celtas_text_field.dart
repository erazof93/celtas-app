import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Campo de texto de Celtas: label dorado arriba (estilo del mockup, no
/// flotante) + input con el estilo del tema (fondo `#17130F`, borde `#2A231C`,
/// radio 12px).
class CeltasTextField extends StatelessWidget {
  const CeltasTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: textTheme.bodyLarge?.copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            errorStyle: textTheme.bodySmall?.copyWith(
              color: CeltasColors.redLight,
            ),
          ),
        ),
      ],
    );
  }
}