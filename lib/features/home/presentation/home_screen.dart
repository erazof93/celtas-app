import 'package:cached_network_image/cached_network_image.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla Home: carrusel de banners + menú por categorías.
///
/// Módulo 3. Consume `GET /banners/active` (carrusel con indicador de puntos)
/// y `GET /menu` (categorías con tarjetas de producto). El botón "+" de cada
/// tarjeta muestra un SnackBar "Agregado" — el carrito real llega en el módulo
/// 4 (estado 100% local en Riverpod).
///
/// Estados:
///   - Carga: spinner + `SlowBackendNotice` (el backend de Render puede tardar
///     30-50s en despertar).
///   - Error: mensaje + botón de reintento.
///   - Vacío: sin banners activos → se oculta el carrusel (no es error); sin
///     categorías → mensaje de menú vacío.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(activeBannersProvider);
    final menuAsync = ref.watch(publicMenuProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _HomeHeader(),
            Expanded(
              child: RefreshIndicator(
                color: CeltasColors.orange,
                backgroundColor: CeltasColors.surface,
                onRefresh: () async {
                  ref.invalidate(activeBannersProvider);
                  ref.invalidate(publicMenuProvider);
                  try {
                    await Future.wait([
                      ref.read(activeBannersProvider.future),
                      ref.read(publicMenuProvider.future),
                    ]);
                  } catch (_) {
                    // Los estados de error de cada provider ya se muestran en
                    // la UI (banners/menú) — el refresh no debe lanzar una
                    // excepción async sin manejar.
                  }
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    CeltasSpacing.page,
                    0,
                    CeltasSpacing.page,
                    24,
                  ),
                  children: [
                    // Carrusel de banners: se oculta si no hay banners activos.
                    bannersAsync.when(
                      loading: () => const _BannersLoading(),
                      error: (error, _) => _BannersError(
                        onRetry: () {
                          ref.invalidate(activeBannersProvider);
                        },
                      ),
                      data: (banners) => banners.isEmpty
                          ? const SizedBox.shrink()
                          : _BannerCarousel(banners: banners),
                    ),
                    const SizedBox(height: 18),
                    // Menú por categorías.
                    menuAsync.when(
                      loading: () => const _MenuLoading(),
                      error: (error, _) => _MenuError(
                        message: error.toString(),
                        onRetry: () {
                          ref.invalidate(publicMenuProvider);
                        },
                      ),
                      data: (categories) => categories.isEmpty
                          ? const _EmptyMenu()
                          : _MenuList(categories: categories),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header (pin de ubicación + campana) ────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(CeltasSpacing.page, 14, CeltasSpacing.page, 8),
      child: Row(
        children: [
          const SvgStrokeIcon(
            path:
                'M12 22s7-6.5 7-12a7 7 0 1 0-14 0c0 5.5 7 12 7 12z'
                'M12 10a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
            size: 18,
            color: CeltasColors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entregar en',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: CeltasColors.textMuted,
                      ),
                ),
                Text(
                  'Casa · Av. Corrientes 1234',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CeltasColors.cream,
                      ),
                ),
              ],
            ),
          ),
          const SvgStrokeIcon(
            path:
                'M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9'
                'M13.7 21a2 2 0 0 1-3.4 0',
            size: 20,
            color: CeltasColors.cream,
          ),
        ],
      ),
    );
  }
}

// ─── Carrusel de banners ────────────────────────────────────────────────────

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});

  final List<Banner> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) =>
                _BannerCard(banner: widget.banners[index]),
          ),
        ),
        const SizedBox(height: 10),
        // Indicador de puntos: activo 16x3 naranja, inactivo 6x3 gris.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (index) {
            final active = index == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 3,
              decoration: BoxDecoration(
                color: active ? CeltasColors.orange : CeltasColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final Banner banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CeltasRadii.banner),
        color: CeltasColors.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: banner.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: CeltasColors.surface,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CeltasColors.orange,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: CeltasColors.surface,
                alignment: Alignment.center,
                child: Text(
                  banner.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            )
          else
            Container(
              color: CeltasColors.surface,
              alignment: Alignment.center,
              child: Text(
                banner.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          // Gradiente oscuro de izquierda a derecha (del CSS real del mockup:
          // `linear-gradient(90deg, rgba(13,13,13,.85) 20%, transparent 70%)`).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CeltasColors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
                stops: const [0.2, 0.7],
              ),
            ),
          ),
          // Título del banner (Cinzel, abajo a la izquierda).
          Positioned(
            left: 16,
            bottom: 14,
            child: Text(
              banner.title.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: CeltasColors.cream,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menú por categorías ────────────────────────────────────────────────────

class _MenuList extends StatefulWidget {
  const _MenuList({required this.categories});

  final List<PublicMenuCategory> categories;

  @override
  State<_MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<_MenuList> {
  /// Categoría seleccionada en los chips (null = "todas").
  String? _selectedCategoryId;

  List<PublicMenuCategory> get _visibleCategories {
    final selected = _selectedCategoryId;
    if (selected == null) return widget.categories;
    return widget.categories
        .where((category) => category.id == selected)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final visible = _visibleCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips de categorías (mockup: "Burgers", "Chicken", "Bebidas").
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryChip(
                label: 'Todas',
                selected: _selectedCategoryId == null,
                onTap: () => setState(() => _selectedCategoryId = null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 10),
                _CategoryChip(
                  label: category.name,
                  selected: _selectedCategoryId == category.id,
                  onTap: () =>
                      setState(() => _selectedCategoryId = category.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final category in visible) ...[
          Text(
            category.name.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
          ),
          const SizedBox(height: 12),
          for (final item in category.items) ...[
            _ProductCard(item: item),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? CeltasColors.orange : CeltasColors.surface,
          borderRadius: BorderRadius.circular(CeltasRadii.pill),
          border: selected
              ? null
              : Border.all(color: CeltasColors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? CeltasColors.black : CeltasColors.textLabel,
              ),
        ),
      ),
    );
  }
}

/// Tarjeta de producto del mockup: fila con imagen 76x76, nombre, descripción,
/// precio dorado y botón "+" circular naranja. Esquina superior derecha cortada
/// (`clip-path: polygon(12px 0, ...)` del CSS real).
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});

  final PublicMenuItem item;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _CardCornerClipper(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CeltasColors.card,
          border: Border.all(color: CeltasColors.cardBorder),
        ),
        child: Row(
          children: [
            _ProductImage(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: CeltasColors.cream,
                        ),
                  ),
                  const SizedBox(height: 2),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: CeltasColors.textMuted,
                          ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    'S/ ${item.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: CeltasColors.gold,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Botón "+" rápido: agrega al carrito sin entrar al detalle.
            // El carrito real llega en el módulo 4; por ahora solo avisa.
            _AddButton(
              key: ValueKey('add-${item.id}'),
              onTap: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        'Agregado: ${item.name}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: CeltasColors.cream,
                            ),
                      ),
                      backgroundColor: CeltasColors.surface,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.item});

  final PublicMenuItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: CeltasColors.surface,
          borderRadius: BorderRadius.circular(CeltasRadii.control),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          size: 24,
          color: CeltasColors.textSubtle,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(CeltasRadii.control),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 76,
          height: 76,
          color: CeltasColors.surface,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: CeltasColors.orange,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 76,
          height: 76,
          color: CeltasColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant,
            size: 24,
            color: CeltasColors.textSubtle,
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: CeltasColors.orange,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const SvgStrokeIcon(
          path: 'M12 5v14M5 12h14',
          size: 16,
          color: CeltasColors.black,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

/// Recorta la esquina superior derecha en diagonal (12px), replicando el
/// `clip-path: polygon(12px 0,100% 0,100% calc(100% - 12px),calc(100% - 12px)
/// 100%,0 100%,0 12px)` del CSS real de las cards del Home.
class _CardCornerClipper extends CustomClipper<Path> {
  const _CardCornerClipper(this.cut);

  final double cut;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(_CardCornerClipper oldClipper) => oldClipper.cut != cut;
}

// ─── Estados de carga / error / vacío ───────────────────────────────────────

class _BannersLoading extends StatelessWidget {
  const _BannersLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        borderRadius: BorderRadius.circular(CeltasRadii.banner),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: CeltasColors.orange,
        ),
      ),
    );
  }
}

/// Error del carrusel de banners: caja compacta con mensaje y reintento.
/// Antes este error se tragaba en silencio (`SizedBox.shrink`); ahora el
/// usuario puede reintentar sin perder el menú que ya cargó.
class _BannersError extends StatelessWidget {
  const _BannersError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        borderRadius: BorderRadius.circular(CeltasRadii.banner),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 22,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No se pudieron cargar los banners',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CeltasColors.textMuted,
                  ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: CeltasColors.orange,
            ),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}

class _MenuLoading extends StatelessWidget {
  const _MenuLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 40),
        Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: CeltasColors.orange,
            ),
          ),
        ),
        SizedBox(height: 12),
        SlowBackendNotice(),
      ],
    );
  }
}

class _MenuError extends StatelessWidget {
  const _MenuError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'No se pudo cargar el menú',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CeltasColors.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          CeltasButton(
            label: 'REINTENTAR',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 36,
            color: CeltasColors.textSubtle,
          ),
          const SizedBox(height: 12),
          Text(
            'El menú está vacío por ahora',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Volvé pronto, estamos preparando algo rico.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: CeltasColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}