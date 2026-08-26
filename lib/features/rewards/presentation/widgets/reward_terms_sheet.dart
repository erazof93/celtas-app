import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';

/// Bottom sheet de "¿Cómo funciona el programa de Estrellas?" (mockup
/// `estrellas-04-terminos.png`). Contenido estático, sin datos del backend —
/// mismo esqueleto de contenedor que `CouponPickerSheet` (drag-handle 36×4,
/// `showModalBottomSheet` con `CeltasColors.card` + radio `CeltasRadii.card`
/// arriba).
///
/// Texto en tuteo (mismo criterio de todo el proyecto): el mockup original
/// usaba voseo rioplatense ("ganás", "seguís", "podés") — corregido acá.
class RewardTermsSheet extends StatelessWidget {
  const RewardTermsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CeltasColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CeltasRadii.card),
        ),
      ),
      builder: (_) => const RewardTermsSheet(),
    );
  }

  static const _points = [
    'Por cada S/ 10 en compras (sin contar el envío) ganas 1 estrella.',
    'Al completar tu objetivo del mes, ganas un premio para canjear por '
        'un producto disponible.',
    'Cada premio tiene una vigencia de 15 días desde que lo ganas.',
    'El conteo de estrellas se reinicia el día 1 de cada mes — los '
        'premios que ya ganaste no se pierden.',
    'Al canjear un premio, sigues participando normalmente — puedes '
        'ganar más de uno en el mismo mes.',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CeltasColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Cómo funciona el programa de Estrellas?',
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CeltasColors.cream,
              ),
            ),
            const SizedBox(height: 16),
            for (final point in _points) ...[
              _TermPoint(text: point),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            CeltasButton(
              angled: true,
              label: 'Entendido',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermPoint extends StatelessWidget {
  const _TermPoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_rounded,
          size: 18,
          color: CeltasColors.orange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  color: CeltasColors.textMuted,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
