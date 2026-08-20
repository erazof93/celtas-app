import 'package:cached_network_image/cached_network_image.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/celtas_snackbar.dart';
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
/// Layout exacto del mockup, con un ajuste de UX real post-mockup (ver abajo):
///   - Hero con gradiente vertical
///     `rgba(13,13,13,.5) 0% → transparent 30% → rgba(13,13,13,.95) 100%` y
///     botones circulares de volver (38px, fondo `rgba(13,13,13,.6)`). El
///     mockup original pedía 400px, pero eso empujaba el selector de salsas
///     (agregado post-mockup, ver más abajo) y su aviso de elección
///     pendiente fuera de la pantalla visible sin deslizar en celulares
///     comunes (hallazgo de UX real en dispositivo, no del mockup) — se
///     redujo a 270px, que sí deja selector + aviso visibles sin deslizar en
///     un producto con salsas en un celular de ~6.1", y sigue siendo un
///     hero grande y reconocible.
///   - Nombre en Cinzel 24px, descripción 14px muted, precio dorado 22px.
///   - Selector de salsas/cremas (solo si `item.sauces` no está vacío —
///     ej. arroz chaufa no lo muestra): sección nueva, no viene del mockup
///     original (12 pantallas, sin esta funcionalidad todavía) — se sigue el
///     mismo lenguaje visual del resto de la pantalla (chips con borde
///     dorado cuando están seleccionados, mismo criterio que "VER MIS
///     CUPONES" del carrito y el círculo de selección de `_AddressCard` del
///     checkout).
///   - Selector de cantidad (stepper `#17130F` borde `#2A231C` radio 12).
///   - Barra inferior fija con botón angled "AGREGAR AL CARRITO · S/ X.XX"
///     donde el precio ya viene multiplicado por la cantidad seleccionada.
///     Al tocarlo se agrega al carrito CON las salsas elegidas y se vuelve
///     automáticamente a Home (`context.pop()`) para seguir agregando —
///     `/product/:id` siempre se llega con `push` desde Home (ver
///     `home_screen.dart`: tarjeta de producto y banner tipo `menuItem`),
///     así que el pop siempre cae de vuelta ahí.
///
/// Modo edición (`editingItem`, mejora post-cierre pedida por el dueño del
/// negocio): cuando se llega con un `CartItem` ya en el carrito (ícono de
/// lápiz de `cart_screen.dart`, pasado por `extra` de `go_router` — ver
/// `app_router.dart`), la cantidad y las salsas arrancan precargadas con las
/// de esa fila, el botón dice "GUARDAR CAMBIOS" en vez del precio, y
/// confirmar llama a `CartNotifier.updateLine` en vez de `addItem` (reemplaza
/// la fila en vez de crear/sumar una nueva). El `pop()` sigue siendo el mismo
/// en ambos modos: como el modo edición siempre se llega con `push` desde
/// `/cart` (nunca desde Home), el pop cae de vuelta ahí solo — no hace falta
/// una rama de navegación aparte.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.editingItem,
  });

  final String productId;
  final CartItem? editingItem;

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
              return _ProductDetailBody(item: item, editingItem: editingItem);
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
  const _ProductDetailBody({required this.item, this.editingItem});

  final PublicMenuItem item;
  final CartItem? editingItem;

  @override
  ConsumerState<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends ConsumerState<_ProductDetailBody> {
  late int _quantity;
  late final Set<String> _selectedSauceIds;
  late bool _explicitlyNoSauces;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    // Modo edición: precarga cantidad, salsas y comentario de la fila que se
    // está editando en vez de arrancar en 1/vacío — ver doc de `editingItem`
    // en `ProductDetailScreen`. Si la fila editada tenía "Sin salsas" marcado
    // explícitamente, precarga ese chip en vez de dejar todo vacío.
    final editingItem = widget.editingItem;
    _quantity = editingItem?.quantity ?? 1;
    _selectedSauceIds = {
      for (final sauce in editingItem?.selectedSauces ?? const [])
        sauce.id,
    };
    _explicitlyNoSauces = editingItem?.explicitlyNoSauces ?? false;
    _commentController = TextEditingController(
      text: editingItem?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// El producto exige una elección real (al menos una salsa, o "Sin
  /// salsas") solo cuando ofrece catálogo de salsas — productos sin
  /// catálogo (`item.sauces.isEmpty`) nunca quedan bloqueados por esto.
  bool get _hasRequiredSauceChoice =>
      widget.item.sauces.isEmpty ||
      _selectedSauceIds.isNotEmpty ||
      _explicitlyNoSauces;

  void _toggleSauce(String sauceId) {
    setState(() {
      if (!_selectedSauceIds.remove(sauceId)) {
        _selectedSauceIds.add(sauceId);
      }
      // Mutuamente excluyente con "Sin salsas": elegir cualquier salsa real
      // desmarca esa opción si estaba activa.
      _explicitlyNoSauces = false;
    });
  }

  void _toggleNoSauces() {
    setState(() {
      if (_explicitlyNoSauces) {
        _explicitlyNoSauces = false;
      } else {
        _explicitlyNoSauces = true;
        // Mutuamente excluyente con las salsas reales: limpia cualquier
        // selección previa.
        _selectedSauceIds.clear();
      }
    });
  }

  void _addToCart() {
    final item = widget.item;
    final editingItem = widget.editingItem;
    final selectedSauces = item.sauces
        .where((sauce) => _selectedSauceIds.contains(sauce.id))
        .toList();
    // Vacío o solo espacios = sin comentario — mismo criterio que el
    // backend (`OrdersService.resolveComment`, `create-order.dto.ts`), así
    // dos filas sin nota real nunca quedan separadas por espacios sueltos.
    final rawComment = _commentController.text.trim();
    final comment = rawComment.isEmpty ? null : rawComment;
    if (editingItem != null) {
      ref.read(cartProvider.notifier).updateLine(
            editingItem.lineKey,
            quantity: _quantity,
            selectedSauces: selectedSauces,
            explicitlyNoSauces: _explicitlyNoSauces,
            comment: comment,
          );
    } else {
      ref.read(cartProvider.notifier).addItem(
            item,
            quantity: _quantity,
            selectedSauces: selectedSauces,
            explicitlyNoSauces: _explicitlyNoSauces,
            comment: comment,
          );
    }
    // El SnackBar vive en el ScaffoldMessenger raíz (por encima del
    // Navigator), así que sigue visible aunque esta pantalla haga `pop()` a
    // continuación — mismo criterio que ya usa el botón "+" rápido del
    // Home, que confirma sin bloquear la navegación. Ya no lleva la acción
    // "VER CARRITO": al volver a Home el usuario ya ve ahí la barra
    // flotante del carrito (`_CartSummaryBar`), y mantener la acción
    // apuntando a un `context` que esta pantalla está por descartar es
    // frágil.
    showCeltasSnackBar(
      context,
      editingItem != null
          ? 'Cambios guardados: ${item.name}'
          : 'Agregado: ${item.name} ×$_quantity',
      // Mismo margen ya usado en `home_screen.dart` para que el SnackBar no
      // quede tapado por `_CartSummaryBar`.
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    );
    // Vuelve a la pantalla desde la que se llegó acá — Home en el flujo
    // normal de "agregar" (pedido explícito del negocio: agregar no debe
    // dejarte varado en el detalle), o /cart en modo edición, porque
    // `/product/:id` en modo edición siempre se llega con `push` desde
    // `cart_screen.dart` (ver doc de `editingItem` arriba) y el pop cae de
    // vuelta ahí solo. El pop se difiere al siguiente frame porque en el
    // mismo frame en que se inserta el SnackBar, hacerlo de inmediato
    // duplica momentáneamente el SnackBar en el árbol de widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pop();
    });
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
            // Hero con gradiente y botones superpuestos — 270px, ver doc de
            // la clase (ajuste de UX real, no del mockup original).
            SizedBox(
              height: 270,
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
                    if (item.sauces.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SauceSelector(
                        sauces: item.sauces,
                        selectedIds: _selectedSauceIds,
                        explicitlyNoSauces: _explicitlyNoSauces,
                        onToggle: _toggleSauce,
                        onToggleNoSauces: _toggleNoSauces,
                      ),
                      if (!_hasRequiredSauceChoice) ...[
                        const SizedBox(height: 10),
                        const _SauceChoiceNotice(),
                      ],
                    ],
                    const SizedBox(height: 20),
                    _CommentField(controller: _commentController),
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
                label: widget.editingItem != null
                    ? 'GUARDAR CAMBIOS'
                    : 'AGREGAR AL CARRITO · '
                          'S/ ${totalPrice.toStringAsFixed(2)}',
                // `enabled` solo controla el estilo gris — el toque SIEMPRE
                // se procesa (`onPressed` real) para poder darle feedback al
                // usuario cuando falta elegir salsas, en vez de ignorar el
                // toque en silencio (`onPressed: null` no dispara el
                // `InkWell` en absoluto). Ver doc de `CeltasButton.enabled`.
                enabled: _hasRequiredSauceChoice,
                onPressed: () {
                  if (!_hasRequiredSauceChoice) {
                    // Mismo texto que el aviso inline bajo el selector
                    // (`_SauceChoiceNotice`) y mismo estilo/comportamiento
                    // que el resto de SnackBars de esta pantalla — mismo
                    // criterio que el aviso de cupón de `cart_screen.dart`.
                    showCeltasSnackBar(
                      context,
                      'Elegí tus salsas o toca "Sin salsas" para continuar',
                    );
                    return;
                  }
                  _addToCart();
                },
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

/// Selector de salsas/cremas. Solo se construye cuando `item.sauces` no está
/// vacío — ver `_ProductDetailBody.build`. Multi-selección entre las salsas
/// reales, más un chip adicional "Sin salsas" mutuamente excluyente con
/// ellas (ver `_ProductDetailBodyState._toggleSauce`/`_toggleNoSauces`): el
/// producto exige una elección real (al menos una salsa, o "Sin salsas")
/// antes de poder agregar/guardar.
class _SauceSelector extends StatelessWidget {
  const _SauceSelector({
    required this.sauces,
    required this.selectedIds,
    required this.explicitlyNoSauces,
    required this.onToggle,
    required this.onToggleNoSauces,
  });

  final List<SauceOption> sauces;
  final Set<String> selectedIds;
  final bool explicitlyNoSauces;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleNoSauces;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SALSAS Y CREMAS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: CeltasColors.textLabel,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Elegí las que quieras, o "Sin salsas"',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: CeltasColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final sauce in sauces)
              _SauceChip(
                key: ValueKey('detail-sauce-${sauce.id}'),
                label: sauce.name,
                selected: selectedIds.contains(sauce.id),
                onTap: () => onToggle(sauce.id),
              ),
            _SauceChip(
              key: const ValueKey('detail-sauce-none'),
              label: 'Sin salsas',
              selected: explicitlyNoSauces,
              onTap: onToggleNoSauces,
            ),
          ],
        ),
      ],
    );
  }
}

/// Chip individual de salsa (o del chip especial "Sin salsas", mismo
/// lenguaje visual). Mismo criterio que el círculo de selección de
/// `_AddressCard` (checkout_screen.dart) y el chip "VER MIS CUPONES" del
/// carrito: borde dorado/naranja cuando está activo.
class _SauceChip extends StatelessWidget {
  const _SauceChip({
    super.key,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? CeltasColors.orange.withValues(alpha: 0.15)
              : CeltasColors.surface,
          border: Border.all(
            color: selected ? CeltasColors.orange : CeltasColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(CeltasRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: CeltasColors.orange),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? CeltasColors.orange : CeltasColors.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso de que falta elegir salsas antes de poder agregar/guardar — mismo
/// patrón visual (card + ícono + texto, tono gold de advertencia) que
/// `_MissingAddressNotice` en `checkout_screen.dart`.
class _SauceChoiceNotice extends StatelessWidget {
  const _SauceChoiceNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('detail-sauce-choice-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CeltasColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
        border: Border.all(color: CeltasColors.gold, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: CeltasColors.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Elegí tus salsas o toca "Sin salsas" para continuar',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CeltasColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nota libre opcional del cliente para este ítem (ej. "sin cebolla"). Nueva
/// sección, sin precedente en `design-reference/` (12 pantallas, sin esta
/// funcionalidad todavía) — se sigue el mismo lenguaje visual del resto de
/// la pantalla (label bold + subtítulo muted, mismo patrón que "SALSAS Y
/// CREMAS" arriba). Siempre visible, a diferencia del selector de salsas:
/// el comentario no depende de que el producto tenga catálogo de salsas.
class _CommentField extends StatelessWidget {
  const _CommentField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTA PARA TU PEDIDO',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: CeltasColors.textLabel,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Opcional, ej. "sin cebolla"',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: CeltasColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('detail-comment'),
          controller: controller,
          maxLength: 140,
          minLines: 1,
          maxLines: 3,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: CeltasColors.cream,
          ),
          decoration: const InputDecoration(
            hintText: 'Ej. sin cebolla, bien cocida...',
            isDense: true,
          ),
        ),
      ],
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
