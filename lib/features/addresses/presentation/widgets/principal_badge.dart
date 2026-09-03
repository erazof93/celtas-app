import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Badge "PRINCIPAL" (contorno dorado) que marca la dirección `isDefault` del
/// usuario.
///
/// Compartido entre la lista de Direcciones (`_AddressListCard`) y el selector
/// del checkout (`_AddressCard`) para que se vea idéntico en ambos lados — el
/// estilo estaba duplicado a mano.
class PrincipalBadge extends StatelessWidget {
  const PrincipalBadge({super.key, this.visible = true});

  /// Cuando es `false` no ocupa espacio (`SizedBox.shrink`), para poder
  /// escribir `PrincipalBadge(visible: address.isDefault)` sin un `if` en el
  /// árbol.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CeltasColors.surfaceSelected,
        border: Border.all(color: CeltasColors.gold),
        borderRadius: BorderRadius.circular(CeltasRadii.badge),
      ),
      child: Text(
        'PRINCIPAL',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: CeltasColors.gold,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}
