import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart';

/// Bottom sheet "Sobre nuestras imágenes" — aviso de que las fotos de los
/// productos del Home son referenciales (generadas con asistencia de IA, no
/// fotos reales de cada preparación individual). Mismo esqueleto exacto que
/// `RewardTermsSheet` (`lib/features/rewards/presentation/widgets/
/// reward_terms_sheet.dart`): drag-handle 36×4, `showModalBottomSheet` con
/// `CeltasColors.card` + radio `CeltasRadii.card` arriba, lista de puntos en
/// `Flexible` + `SingleChildScrollView` para no desbordar en pantallas
/// bajas, botón "Entendido" fijo abajo.
class ProductImagesTermsSheet extends StatelessWidget {
  const ProductImagesTermsSheet({super.key});

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
      builder: (_) => const ProductImagesTermsSheet(),
    );
  }

  static const _points = [
    'Las fotos de nuestros productos son referencias artísticas que '
        'muestran una representación del plato, no una fotografía de cada '
        'preparación individual.',
    'El producto que recibes puede variar en decoración, presentación o '
        'el corte exacto de los ingredientes respecto a la imagen '
        'mostrada.',
    'El contenido, cantidad e ingredientes principales corresponden '
        'exactamente a la descripción — solo la presentación visual puede '
        'diferir ligeramente.',
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
              'Sobre nuestras imágenes',
              style: textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CeltasColors.cream,
              ),
            ),
            const SizedBox(height: 16),
            // Mismo criterio que `RewardTermsSheet`: `Flexible` +
            // `SingleChildScrollView` para que la lista de puntos scrollee
            // en vez de desbordar en pantallas bajas — el drag-handle, el
            // título y "Entendido" se quedan fijos.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final point in _points) ...[
                      _ProductImagePoint(text: point),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
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

class _ProductImagePoint extends StatelessWidget {
  const _ProductImagePoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: CeltasColors.gold,
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
