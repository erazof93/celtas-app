import 'package:cached_network_image/cached_network_image.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Detalle de producto (mockup 05 · DETALLE DE PRODUCTO).
///
/// Ruta `/product/:id`. El producto se busca en el menú ya cargado por el
/// Home (`publicMenuProvider`) — no hay endpoint de detalle propio en el
/// backend público, el menú trae todo.
///
/// Layout exacto del mockup:
///   - Hero de 400px con gradiente vertical
///     `rgba(13,13,13,.5) 0% → transparent 30% → rgba(13,13,13,.95) 100%` y
///     botones circulares de volver (38px, fondo `rgba(13,13,13,.6)`).
///   - Nombre en Cinzel 24px, descripción 14px muted, precio dorado 22px.
///   - Selector de cantidad (stepper `#17130F` borde `#2A231C` radio 12).
///   - Barra inferior fija con botón angled "AGREGAR AL CARRITO · S/ X.XX"
///     donde el precio ya viene multiplicado por la cantidad seleccionada.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(publicMenuProvider);

    return menuAsync.when(
      loading: () => const _DetailLoading(),
      error: (error, _) => _DetailError(
        message: error.toString(),
        onRetry: () => ref.invalidate(publicMenuProvider),
      ),
      data: (categories) {
        for (final category in categories) {
          for (final item in category.items) {
            if (item.id == productId) {
              return _ProductDetailBody(item: item);
            }
          }
        }
        return const _DetailNotFound();
      },
    );
  }
}

/// Cuerpo del detalle: hero + contenido scrollable + barra de agregar fija.
class _ProductDetailBody extends ConsumerStatefulWidget {
  const _ProductDetailBody({required this.item});

  final PublicMenuItem item;

  @override
  ConsumerState<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends ConsumerState<_ProductDetailBody> {
  int _quantity = 1;

  void _addToCart() {
    ref.read(cartProvider.notifier).addItem(widget.item, quantity: _quantity);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Agregado: ${widget.item.name} ×$_quantity',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: CeltasColors.cream),
          ),
          backgroundColor: CeltasColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          // El SnackBar persiste en el ScaffoldMessenger raíz: si el usuario
          // vuelve al Home antes de que expire, puede quedar tapado por la
          // barra flotante "VER CARRITO" que aparece ahí con el carrito no
          // vacío (`_CartSummaryBar`, mismo margen de 88 ya usado en
          // `home_screen.dart` para que esa barra no tape el último ítem del
          // menú).
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          action: SnackBarAction(
            label: 'VER CARRITO',
            textColor: CeltasColors.gold,
            onPressed: () {
              // Ocultar el SnackBar antes de navegar: persiste en el
              // ScaffoldMessenger raíz y tapa los CTAs del carrito.
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              context.push('/cart');
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final totalPrice = item.price * _quantity;

    return Scaffold(
      // `top: false`: el hero de 400px es full-bleed a propósito (los
      // botones superpuestos ya se posicionan a mano con `top: 44` para
      // salvar el status bar). Solo el borde inferior necesita el inset del
      // sistema — mismo criterio que `CeltasBottomNav`
      // (`shared/widgets/celtas_bottom_nav.dart`): sin esto, la barra
      // "AGREGAR AL CARRITO" queda tapada por la barra de navegación del
      // sistema Android en dispositivos sin gesture nav.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Hero 400px con gradiente y botones superpuestos.
            SizedBox(
              height: 400,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _HeroImage(item: item),
                  // Gradiente vertical del CSS real del mockup.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          CeltasColors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          CeltasColors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0, 0.3, 1],
                      ),
                    ),
                  ),
                  // Botón superior: volver. El corazón de favoritos del mockup
                  // se quitó — no hay funcionalidad de favoritos en el alcance
                  // actual del proyecto; se evalúa como función nueva más
                  // adelante si hace falta.
                  Positioned(
                    top: 44,
                    left: 20,
                    child: _CircleIconButton(
                      key: const ValueKey('detail-back'),
                      onTap: () => context.pop(),
                      child: const SvgStrokeIcon(
                        path: 'M15 18l-6-6 6-6',
                        size: 18,
                        color: CeltasColors.cream,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Contenido scrollable.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: CeltasColors.cream,
                          ),
                    ),
                    const SizedBox(height: 6),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      Text(
                        item.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.5,
                          color: CeltasColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'S/ ${item.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: CeltasColors.gold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Selector de cantidad (mockup: label CANTIDAD + stepper).
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CANTIDAD',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: CeltasColors.textLabel,
                              ),
                        ),
                        _QuantityStepper(
                          quantity: _quantity,
                          onDecrement: () => setState(
                            () => _quantity = _quantity > 1 ? _quantity - 1 : 1,
                          ),
                          onIncrement: () => setState(
                            () =>
                                _quantity = _quantity < 99 ? _quantity + 1 : 99,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Barra inferior fija con el botón de agregar.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              decoration: const BoxDecoration(
                color: CeltasColors.black,
                border: Border(top: BorderSide(color: CeltasColors.divider)),
              ),
              child: CeltasButton(
                key: const ValueKey('detail-add'),
                angled: true,
                label:
                    'AGREGAR AL CARRITO · S/ ${totalPrice.toStringAsFixed(2)}',
                onPressed: _addToCart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagen grande del producto (400px). Sin foto → placeholder con ícono.
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.item});

  final PublicMenuItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.image;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: CeltasColors.surface,
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          size: 48,
          color: CeltasColors.textSubtle,
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: CeltasColors.surface,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: CeltasColors.orange,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: CeltasColors.surface,
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          size: 48,
          color: CeltasColors.textSubtle,
        ),
      ),
    );
  }
}

/// Botón circular 38px con fondo `rgba(13,13,13,.6)` (mockup).
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: CeltasColors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Stepper de cantidad del detalle (mockup: radio 12, padding 8×16, gap 18).
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        border: Border.all(color: CeltasColors.border),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('detail-qty-minus'),
            onTap: onDecrement,
            child: const SvgStrokeIcon(
              path: 'M5 12h14',
              size: 16,
              color: CeltasColors.cream,
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '$quantity',
            key: const ValueKey('detail-qty-value'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CeltasColors.cream,
            ),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            key: const ValueKey('detail-qty-plus'),
            onTap: onIncrement,
            child: const SvgStrokeIcon(
              path: 'M12 5v14M5 12h14',
              size: 16,
              color: CeltasColors.orange,
              strokeWidth: 2.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estados de carga / error / no encontrado ───────────────────────────────

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: CeltasColors.orange,
                ),
              ),
              SizedBox(height: 12),
              SlowBackendNotice(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CeltasSpacing.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 36,
                  color: CeltasColors.textSubtle,
                ),
                const SizedBox(height: 12),
                Text(
                  'No se pudo cargar el producto',
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
                CeltasButton(label: 'REINTENTAR', onPressed: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailNotFound extends StatelessWidget {
  const _DetailNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CeltasSpacing.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: CeltasColors.textSubtle,
                ),
                const SizedBox(height: 12),
                Text(
                  'Producto no encontrado',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                CeltasButton(label: 'VOLVER', onPressed: () => context.pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
