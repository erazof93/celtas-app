import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart';

/// Ítems del bottom nav, con los paths SVG exactos del mockup (viewBox 24×24).
///
/// Los círculos de los SVG originales (`<circle>`) se tradujeron a paths de
/// arco (`a...`) porque el parser del proyecto trabaja con `d` de path.
enum CeltasNavItem {
  home(
    'Inicio',
    'M3 10l9-7 9 7v10a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z',
  ),
  orders(
    'Pedidos',
    'M3 3h2l2.6 13h11.8L21 8H6'
    'M9 18.6a1.4 1.4 0 1 0 0 2.8a1.4 1.4 0 1 0 0-2.8'
    'M18 18.6a1.4 1.4 0 1 0 0 2.8a1.4 1.4 0 1 0 0-2.8',
  ),
  coupons(
    'Cupones',
    'M20.6 12.5a1.9 1.9 0 0 1 0-2.9L21.8 8a2 2 0 0 0-2-3.4l-1.7.6'
    'a1.9 1.9 0 0 1-2.5-1.5L15.3 2a2 2 0 0 0-3.9 0l-.3 1.7'
    'a1.9 1.9 0 0 1-2.5 1.5L6.9 4.6A2 2 0 0 0 4.9 8l1.2 1.6'
    'a1.9 1.9 0 0 1 0 2.9L4.9 14a2 2 0 0 0 2 3.4l1.7-.6'
    'a1.9 1.9 0 0 1 2.5 1.5l.3 1.7a2 2 0 0 0 3.9 0l.3-1.7'
    'a1.9 1.9 0 0 1 2.5-1.5l1.7.6a2 2 0 0 0 2-3.4z',
  ),
  profile(
    'Perfil',
    'M8 8a4 4 0 1 0 8 0a4 4 0 1 0-8 0'
    'M4 21c1.5-4 5-6 8-6s6.5 2 8 6',
  );

  const CeltasNavItem(this.label, this.path);

  final String label;
  final String path;
}

/// Bottom nav bar de Celtas, replicando los valores exactos del mockup:
///
/// - Contenedor: alto 78px, fondo `#111010`, borde superior `#241F19`,
///   `padding-bottom: 8px`.
/// - Ítems: columna centrada con `gap: 3px` entre ícono y label.
/// - Íconos: 21×21px. Activo → stroke `#E8590C` width 2.2; inactivo →
///   stroke `#6B6357` width 2.
/// - Labels: 10px. Activo → `#E8590C` bold; inactivo → `#6B6357` regular.
class CeltasBottomNav extends StatelessWidget {
  const CeltasBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    // El fondo/borde cubre hasta el borde físico de la pantalla (incluida el
    // área de la barra de navegación del sistema, tanto gestos como botones)
    // para que no quede un hueco negro debajo; `SafeArea` empuja los ítems
    // tocables por encima de esa barra sin recortar el fondo.
    return Container(
      decoration: const BoxDecoration(
        color: CeltasColors.navBar,
        border: Border(top: BorderSide(color: CeltasColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < CeltasNavItem.values.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: CeltasNavItem.values[i],
                      selected: i == currentIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CeltasNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CeltasColors.orange : CeltasColors.textSubtle;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgStrokeIcon(
            path: item.path,
            color: color,
            strokeWidth: selected ? 2.2 : 2,
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}