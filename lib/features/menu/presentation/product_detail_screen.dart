import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/celtas_snackbar.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:celtas_mobile/shared/widgets/svg_stroke_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///     (agregado post-mockup, ver más abajo) fuera de la pantalla visible
///     sin deslizar en celulares comunes (hallazgo de UX real en
///     dispositivo, no del mockup) — se redujo a 270px, que sí deja el
///     selector visible sin deslizar en un producto con salsas en un
///     celular de ~6.1", y sigue siendo un hero grande y reconocible.
///   - Nombre en Cinzel 24px, descripción 14px muted, precio dorado 22px.
///   - Selector de salsas/bebidas/porciones extras (cada uno solo si
///     `item.sauces`/`item.beverages`/`item.extraPortions` no está vacío —
///     ej. arroz chaufa no muestra ninguno): sección nueva, no viene del
///     mockup original (12 pantallas, sin esta funcionalidad todavía). Cada
///     categoría es un `_OptionGroupDropdown`: un campo tipo "dropdown"
///     (mismo lenguaje visual de input que el resto de la pantalla — borde,
///     `CeltasColors.surface`, `CeltasRadii.input`) que muestra si la
///     elección ya quedó resuelta ("Listo") o no (vacío) y, al tocarlo, abre
///     un diálogo con checkboxes para editarla (multi-selección real, más
///     un checkbox "Sin X" mutuamente excluyente con las opciones reales,
///     ofrecido solo si `sauceAllowWithout`/`beverageAllowWithout`/
///     `extraPortionsAllowWithout` lo permite — dato por producto/categoría,
///     default `true`, configurado por el admin e independiente de
///     `groupRequired`; ver doc de `PublicMenuItem` y de
///     `_OptionGroupDropdown.allowWithout`).
///     Las 3 secciones se ordenan con los grupos OBLIGATORIOS primero
///     (`_ProductDetailBodyState._sectionOrder`) — dato por producto, así
///     que el orden se recalcula por producto, no es fijo. Las 3 categorías
///     comparten el mismo `groupRequired`/`groupMaxSelectable` por producto
///     (`sauceGroupRequired`/`Max`, `beverageGroupRequired`/`Max`,
///     `extraPortionsGroupRequired`/`Max` — configurado por el admin,
///     contrato verificado contra `OrdersService.validateGroupSelection` en
///     el backend), con el grupo obligatorio el checkbox "Sin X" ni se
///     ofrece (elegir "ninguna" no es válido ahí, sin importar
///     `AllowWithout` — el backend lo rechaza igual) y hace falta elegir al
///     menos una opción real. Bebidas/porciones extras tienen una diferencia
///     real de negocio frente a salsas, no solo de estilo — cada opción
///     elegida SÍ suma precio al total (el ítem del diálogo muestra el
///     precio, ej. "Coca-Cola 500ml — S/3.00"), a diferencia de las salsas.
///     Un grupo OPCIONAL (`groupRequired: false`) nunca bloquea "Agregar"
///     sin importar la selección — el cliente puede dejarlo sin tocar. La
///     validación se espeja acá SOLO para UX inmediata (badge "Obligatorio"
///     en un grupo obligatorio sin elegir, "Listo" apenas hay una opción
///     real elegida en CUALQUIER grupo — obligatorio u opcional —, SnackBar
///     al tocar "Agregar" con algo obligatorio pendiente) — el backend
///     vuelve a validar lo mismo al crear el pedido y es la única fuente de
///     verdad real, mismo principio que el resto del proyecto ("el total y
///     los subtotales se calculan
///     SIEMPRE en el backend, nunca se confía en el frontend").
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
  late final Set<String> _selectedBeverageIds;
  late bool _explicitlyNoBeverages;
  late final Set<String> _selectedExtraPortionIds;
  late bool _explicitlyNoExtraPortions;
  late final TextEditingController _commentController;

  // Una `GlobalKey` por campo dropdown — necesaria para poder hacer
  // `Scrollable.ensureVisible` hacia el campo concreto que está bloqueando
  // el "Agregar"/"Guardar cambios" (ver `_handleValidationFailure`). No se
  // puede resolver esto con un solo `BuildContext` porque las 3 secciones
  // son condicionales (`if (item.sauces.isNotEmpty) ...`) y pueden o no
  // estar montadas.
  final GlobalKey _sauceFieldKey = GlobalKey();
  final GlobalKey _beverageFieldKey = GlobalKey();
  final GlobalKey _extraFieldKey = GlobalKey();

  /// Id del grupo (`'sauce'`/`'beverage'`/`'extra'`) actualmente resaltado
  /// con borde rojo tras un intento fallido de "Agregar"/"Guardar cambios"
  /// — `null` en cualquier otro momento. Ver `_handleValidationFailure`.
  String? _highlightedViolation;

  @override
  void initState() {
    super.initState();
    // Modo edición: precarga cantidad, salsas, bebidas, extras y comentario
    // de la fila que se está editando en vez de arrancar en 1/vacío — ver
    // doc de `editingItem` en `ProductDetailScreen`. Si la fila editada
    // tenía "Sin X" marcado explícitamente en cualquiera de las tres
    // categorías, precarga ese chip en vez de dejar todo vacío.
    final editingItem = widget.editingItem;
    _quantity = editingItem?.quantity ?? 1;
    _selectedSauceIds = {
      for (final sauce in editingItem?.selectedSauces ?? const [])
        sauce.id,
    };
    _explicitlyNoSauces = editingItem?.explicitlyNoSauces ?? false;
    _selectedBeverageIds = {
      for (final beverage in editingItem?.selectedBeverages ?? const [])
        beverage.id,
    };
    _explicitlyNoBeverages = editingItem?.explicitlyNoBeverages ?? false;
    _selectedExtraPortionIds = {
      for (final extraPortion in editingItem?.selectedExtraPortions ?? const [])
        extraPortion.id,
    };
    _explicitlyNoExtraPortions = editingItem?.explicitlyNoExtraPortions ?? false;
    _commentController = TextEditingController(
      text: editingItem?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Mensaje de la violación actual del grupo de salsas, o `null` si la
  /// selección es válida — mismo criterio que [_beverageChoiceViolation]/
  /// [_extraPortionChoiceViolation] (`sauceGroupRequired`/`Max` viajan
  /// siempre desde `GET /menu`, ver doc de `PublicMenuItem`). Con el grupo
  /// NO obligatorio y sin nada elegido, no es una violación — solo bloquea
  /// (1) faltar una elección en un grupo obligatorio, o (2) pasarse del
  /// máximo permitido, sea el grupo obligatorio u opcional.
  String? get _sauceChoiceViolation {
    final item = widget.item;
    if (item.sauces.isEmpty) return null;
    if (item.sauceGroupRequired && _selectedSauceIds.isEmpty) {
      return 'Elige al menos 1 salsa (obligatorio)';
    }
    if (_selectedSauceIds.length > item.sauceGroupMaxSelectable) {
      return 'Máximo ${item.sauceGroupMaxSelectable} salsa(s) — quita '
          'alguna para continuar';
    }
    return null;
  }

  /// Mensaje de la violación actual del grupo de bebidas, o `null` si la
  /// selección es válida — mismo orden de chequeo que
  /// `OrdersService.validateGroupSelection` en el backend: primero
  /// obligatoriedad, después máximo. Sin bebidas ofrecidas, la validación
  /// no aplica (siempre `null`). Con el grupo NO obligatorio y sin nada
  /// elegido, YA NO es una violación — solo bloquea (1) faltar una elección
  /// en un grupo obligatorio, o (2) pasarse del máximo permitido, sea el
  /// grupo obligatorio u opcional.
  String? get _beverageChoiceViolation {
    final item = widget.item;
    if (item.beverages.isEmpty) return null;
    if (item.beverageGroupRequired && _selectedBeverageIds.isEmpty) {
      return 'Elige al menos 1 bebida (obligatorio)';
    }
    if (_selectedBeverageIds.length > item.beverageGroupMaxSelectable) {
      return 'Máximo ${item.beverageGroupMaxSelectable} bebida(s) — quita '
          'alguna para continuar';
    }
    return null;
  }

  /// Mismo criterio que [_beverageChoiceViolation], para porciones extras.
  String? get _extraPortionChoiceViolation {
    final item = widget.item;
    if (item.extraPortions.isEmpty) return null;
    if (item.extraPortionsGroupRequired && _selectedExtraPortionIds.isEmpty) {
      return 'Elige al menos 1 porción extra (obligatorio)';
    }
    if (_selectedExtraPortionIds.length >
        item.extraPortionsGroupMaxSelectable) {
      return 'Máximo ${item.extraPortionsGroupMaxSelectable} porción(es) '
          'extra — quita alguna para continuar';
    }
    return null;
  }

  /// Ids de los grupos con una violación pendiente ahora mismo, en el mismo
  /// orden en que las secciones aparecen en pantalla (`_sectionOrder`: los
  /// grupos obligatorios primero). El primero de esta lista es el que
  /// `_handleValidationFailure` resalta/hacia el que hace scroll al tocar
  /// "Agregar"/"Guardar cambios" con algo pendiente.
  List<String> get _violatedGroupKeys => [
    for (final key in _sectionOrder)
      if (_violationMessageFor(key) != null) key,
  ];

  String? _violationMessageFor(String groupKey) => switch (groupKey) {
    'sauce' => _sauceChoiceViolation,
    'beverage' => _beverageChoiceViolation,
    'extra' => _extraPortionChoiceViolation,
    _ => null,
  };

  GlobalKey _fieldKeyFor(String groupKey) => switch (groupKey) {
    'sauce' => _sauceFieldKey,
    'beverage' => _beverageFieldKey,
    _ => _extraFieldKey,
  };

  /// Feedback de "esto está bloqueando el Agregar" cuando el cliente toca
  /// el botón con una elección obligatoria pendiente: hace scroll hasta el
  /// campo violado, vibra (`HapticFeedback.mediumImpact`), resalta su
  /// borde en rojo por 800ms, y muestra el mensaje en un SnackBar — desde
  /// que se quitó el aviso inline bajo el dropdown (antes `_ChoiceNotice`,
  /// ver `_buildOptionSections`), este SnackBar es la única fuente textual
  /// de qué falta, además del badge "Obligatorio" del campo.
  Future<void> _handleValidationFailure(String groupKey) async {
    final message = _violationMessageFor(groupKey);
    if (message == null) return;
    final fieldContext = _fieldKeyFor(groupKey).currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        // 0.3 en vez de 0.0/1.0: deja el campo visible con algo de aire
        // arriba (no pegado al borde superior del viewport), más fácil de
        // leer junto con el título/subtítulo de la sección.
        alignment: 0.3,
      );
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _highlightedViolation = groupKey);
    showCeltasSnackBar(context, message);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _highlightedViolation = null);
  }

  double get _selectedBeveragesUnitPrice => widget.item.beverages
      .where((beverage) => _selectedBeverageIds.contains(beverage.id))
      .fold(0.0, (sum, beverage) => sum + beverage.price);

  double get _selectedExtraPortionsUnitPrice => widget.item.extraPortions
      .where(
        (extraPortion) => _selectedExtraPortionIds.contains(extraPortion.id),
      )
      .fold(0.0, (sum, extraPortion) => sum + extraPortion.price);

  void _addToCart() {
    final item = widget.item;
    final editingItem = widget.editingItem;
    final selectedSauces = item.sauces
        .where((sauce) => _selectedSauceIds.contains(sauce.id))
        .toList();
    final selectedBeverages = item.beverages
        .where((beverage) => _selectedBeverageIds.contains(beverage.id))
        .toList();
    final selectedExtraPortions = item.extraPortions
        .where(
          (extraPortion) =>
              _selectedExtraPortionIds.contains(extraPortion.id),
        )
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
            selectedBeverages: selectedBeverages,
            explicitlyNoBeverages: _explicitlyNoBeverages,
            selectedExtraPortions: selectedExtraPortions,
            explicitlyNoExtraPortions: _explicitlyNoExtraPortions,
            comment: comment,
          );
    } else {
      ref.read(cartProvider.notifier).addItem(
            item,
            quantity: _quantity,
            selectedSauces: selectedSauces,
            explicitlyNoSauces: _explicitlyNoSauces,
            selectedBeverages: selectedBeverages,
            explicitlyNoBeverages: _explicitlyNoBeverages,
            selectedExtraPortions: selectedExtraPortions,
            explicitlyNoExtraPortions: _explicitlyNoExtraPortions,
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

  /// Orden final de las secciones de opciones (`sauce`/`beverage`/`extra`,
  /// solo las que el producto realmente ofrece) — grupos OBLIGATORIOS
  /// (`groupRequired: true`) primero, opcionales después, orden pedido por
  /// el dueño del negocio: lo que bloquea "Agregar" debe verse antes que lo
  /// que no. `groupRequired` es un dato por producto
  /// (`item.sauceGroupRequired`/`beverageGroupRequired`/
  /// `extraPortionsGroupRequired`), así que este orden se recalcula en cada
  /// build, no es fijo. Partición manual en vez de `List.sort` (que en Dart
  /// no garantiza estabilidad): así dos grupos opcionales, o dos
  /// obligatorios, conservan su orden relativo original (salsas → bebidas →
  /// porciones extras). Fuente única de verdad del orden en pantalla — la
  /// usan tanto `_buildOptionSections` (para las secciones) como
  /// `_violatedGroupKeys` (para decidir cuál grupo resaltar primero al tocar
  /// "Agregar" con algo pendiente), así que nunca pueden desincronizarse
  /// entre sí.
  List<String> get _sectionOrder {
    final item = widget.item;
    final required = <String>[];
    final optional = <String>[];
    if (item.sauces.isNotEmpty) {
      (item.sauceGroupRequired ? required : optional).add('sauce');
    }
    if (item.beverages.isNotEmpty) {
      (item.beverageGroupRequired ? required : optional).add('beverage');
    }
    if (item.extraPortions.isNotEmpty) {
      (item.extraPortionsGroupRequired ? required : optional).add('extra');
    }
    return [...required, ...optional];
  }

  /// Secciones de `_OptionGroupDropdown`, ya intercaladas con su espaciado
  /// (`SizedBox(height: 20)`) y ordenadas según `_sectionOrder`. Ya no arma
  /// el aviso `_ChoiceNotice` bajo cada dropdown — el badge
  /// "Obligatorio"/"Listo" dentro del campo ya cubre esa señal.
  List<Widget> _buildOptionSections(PublicMenuItem item) {
    final sections = <String, Widget>{
      if (item.sauces.isNotEmpty)
        'sauce': _OptionGroupDropdown(
          fieldKey: _sauceFieldKey,
          testKey: 'sauce',
          title: 'SALSAS Y CREMAS',
          noneLabel: 'Sin salsas',
          hintText: 'Elige tus cremas',
          options: [
            for (final sauce in item.sauces)
              _SelectableOption(id: sauce.id, name: sauce.name),
          ],
          selectedIds: _selectedSauceIds,
          explicitlyNone: _explicitlyNoSauces,
          groupRequired: item.sauceGroupRequired,
          groupMaxSelectable: item.sauceGroupMaxSelectable,
          allowWithout: item.sauceAllowWithout,
          isHighlighted: _highlightedViolation == 'sauce',
          onApply: (selected, none) => setState(() {
            _selectedSauceIds
              ..clear()
              ..addAll(selected);
            _explicitlyNoSauces = none;
          }),
        ),
      if (item.beverages.isNotEmpty)
        'beverage': _OptionGroupDropdown(
          fieldKey: _beverageFieldKey,
          testKey: 'beverage',
          title: 'BEBIDAS',
          noneLabel: 'Sin bebida',
          hintText: 'Elige tus bebidas',
          options: [
            for (final beverage in item.beverages)
              _SelectableOption(
                id: beverage.id,
                name: beverage.name,
                price: beverage.price,
              ),
          ],
          selectedIds: _selectedBeverageIds,
          explicitlyNone: _explicitlyNoBeverages,
          groupRequired: item.beverageGroupRequired,
          groupMaxSelectable: item.beverageGroupMaxSelectable,
          allowWithout: item.beverageAllowWithout,
          isHighlighted: _highlightedViolation == 'beverage',
          onApply: (selected, none) => setState(() {
            _selectedBeverageIds
              ..clear()
              ..addAll(selected);
            _explicitlyNoBeverages = none;
          }),
        ),
      if (item.extraPortions.isNotEmpty)
        'extra': _OptionGroupDropdown(
          fieldKey: _extraFieldKey,
          testKey: 'extra',
          title: 'PORCIONES EXTRAS',
          noneLabel: 'Sin porciones extras',
          hintText: 'Elige tus porciones extras',
          options: [
            for (final extraPortion in item.extraPortions)
              _SelectableOption(
                id: extraPortion.id,
                name: extraPortion.name,
                price: extraPortion.price,
              ),
          ],
          selectedIds: _selectedExtraPortionIds,
          explicitlyNone: _explicitlyNoExtraPortions,
          groupRequired: item.extraPortionsGroupRequired,
          groupMaxSelectable: item.extraPortionsGroupMaxSelectable,
          allowWithout: item.extraPortionsAllowWithout,
          isHighlighted: _highlightedViolation == 'extra',
          onApply: (selected, none) => setState(() {
            _selectedExtraPortionIds
              ..clear()
              ..addAll(selected);
            _explicitlyNoExtraPortions = none;
          }),
        ),
    };

    return [
      for (final key in _sectionOrder) ...[
        const SizedBox(height: 20),
        sections[key]!,
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // Mismo cálculo que `CartItem.lineTotal`/el backend
    // (`OrdersService.buildItems`): `(unitPrice + extrasUnitPrice) *
    // quantity` — bebidas y porciones extras suman su precio una vez por
    // unidad, las salsas no.
    final totalPrice =
        (item.price + _selectedBeveragesUnitPrice + _selectedExtraPortionsUnitPrice) *
        _quantity;

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
                    ..._buildOptionSections(item),
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
                enabled:
                    _sauceChoiceViolation == null &&
                    _beverageChoiceViolation == null &&
                    _extraPortionChoiceViolation == null,
                onPressed: () {
                  // Mismo orden en que las secciones aparecen en pantalla
                  // (`_sectionOrder`: obligatorios primero). Con algo
                  // pendiente, `_handleValidationFailure` hace
                  // scroll/vibra/resalta el PRIMER grupo violado y muestra
                  // su mensaje en un SnackBar — ver `_violatedGroupKeys`.
                  final violatedGroups = _violatedGroupKeys;
                  if (violatedGroups.isNotEmpty) {
                    unawaited(_handleValidationFailure(violatedGroups.first));
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

/// Opción seleccionable dentro de un [_OptionGroupDropdown] — shape mínimo
/// común entre `SauceOption` (sin precio) y `BeverageOption`/
/// `ExtraPortionOption` (con precio), para que el dropdown/diálogo sea
/// genérico sobre las 3 categorías sin acoplarse a ninguno de los 3 modelos
/// reales de `home/data/models/`. `price == null` (caso salsas) omite el
/// precio del label dentro del diálogo.
class _SelectableOption {
  const _SelectableOption({required this.id, required this.name, this.price});

  final String id;
  final String name;
  final double? price;

  String get label =>
      price == null ? name : '$name — S/${price!.toStringAsFixed(2)}';
}

/// Selector de una categoría de opciones (salsas, bebidas o porciones
/// extras) como campo tipo "dropdown": un input de solo lectura que muestra
/// si la elección ya quedó resuelta ("Listo") o no (vacío) — ver
/// `_summaryText` — y, al tocarlo, abre un diálogo con checkboxes para
/// editarla — reemplaza el selector de chips horizontales usado en una
/// iteración anterior (ver doc de `_ProductDetailBody`).
///
/// Multi-selección real entre `options`, más un checkbox "Sin X"
/// (`noneLabel`) mutuamente excluyente con ellas, ofrecido solo si
/// `allowWithout` (dato por producto/categoría, ver su doc) lo permite. Con
/// `groupRequired: true` hace falta elegir al menos una opción real para
/// poder agregar/guardar ("Sin X" ni se ofrece ahí sin importar
/// `allowWithout`, ver `_openDialog` — elegir "ninguna" no es válido en un
/// grupo obligatorio, el backend lo rechaza igual). Con `groupRequired:
/// false` no hay ninguna elección forzada — el cliente puede dejarlo tal
/// cual y seguir de largo, "Sin X" (cuando `allowWithout` lo permite) es
/// solo una forma más de dejar constancia explícita de "no quiero nada de
/// esto", no una obligación.
///
/// El diálogo mantiene su propio estado temporal (`tempSelected`/
/// `tempExplicitlyNone`) hasta que se toca "ACEPTAR" — tocar "CANCELAR" o
/// cerrar el diálogo descarta los cambios sin tocar el estado real de
/// [_ProductDetailBodyState], mismo comportamiento esperable de cualquier
/// diálogo de confirmación.
class _OptionGroupDropdown extends StatelessWidget {
  const _OptionGroupDropdown({
    required this.fieldKey,
    required this.testKey,
    required this.title,
    required this.noneLabel,
    required this.hintText,
    required this.options,
    required this.selectedIds,
    required this.explicitlyNone,
    required this.groupRequired,
    required this.groupMaxSelectable,
    required this.allowWithout,
    required this.isHighlighted,
    required this.onApply,
  });

  /// `GlobalKey` del campo (Container) en sí — `_ProductDetailBodyState` la
  /// usa para `Scrollable.ensureVisible` cuando este grupo bloquea el
  /// "Agregar"/"Guardar cambios" (ver `_handleValidationFailure`).
  final GlobalKey fieldKey;

  /// Prefijo de los `ValueKey` de este grupo (`sauce`/`beverage`/`extra`).
  final String testKey;
  final String title;
  final String noneLabel;

  /// Placeholder mostrado en el campo cuando [_summaryText] está vacío —
  /// ocurre tanto en grupos opcionales sin selección como, por diseño, en
  /// grupos obligatorios (`_summaryText` ahí siempre es `''`, ver su doc).
  final String hintText;
  final List<_SelectableOption> options;
  final Set<String> selectedIds;
  final bool explicitlyNone;
  final bool groupRequired;
  final int groupMaxSelectable;

  /// Si el checkbox "Sin X" (`noneLabel`) debe ofrecerse — dato por producto
  /// y por categoría (`item.sauceAllowWithout`/`beverageAllowWithout`/
  /// `extraPortionsAllowWithout`, default `true`, ver doc de `PublicMenuItem`
  /// para el contrato real). Solo tiene efecto con el grupo OPCIONAL: con
  /// `groupRequired: true` el checkbox se sigue ocultando sin importar este
  /// valor (ver `_openDialog`) — el admin puede activarlo en un grupo
  /// obligatorio, pero "Sin X" ahí nunca sería una selección válida
  /// (`OrdersService.validateGroupSelection` en el backend exige al menos
  /// una opción real igual), así que ofrecerlo sería un callejón sin salida.
  final bool allowWithout;

  /// `true` mientras este es el grupo que acaba de bloquear un intento de
  /// "Agregar"/"Guardar cambios" — el campo se resalta con borde rojo por
  /// un momento (ver `_ProductDetailBodyState._handleValidationFailure`).
  final bool isHighlighted;

  final void Function(Set<String> selectedIds, bool explicitlyNone) onApply;

  /// "Elige las que quieras" cuando el máximo configurado cubre TODO el
  /// catálogo (caso salsas, que no tienen máximo real — ver
  /// `_ProductDetailBodyState._sauceChoiceViolation`) — sin esto, un
  /// catálogo de 2 salsas con `groupMaxSelectable: 2` diría "elige hasta 2",
  /// una distinción sin sentido para el cliente si de todas formas no hay
  /// más de 2 para elegir.
  ///
  /// Cuando el grupo es obligatorio, ya no repite la palabra "Obligatorio"
  /// acá — el campo la muestra como badge dentro de sí mismo, a la derecha
  /// (ver `build`/`_badge`), así que repetirla en el subtítulo sería ruido.
  /// Con `allowWithout: false` no menciona `noneLabel` — el checkbox "Sin X"
  /// no se ofrece acá (ver `_openDialog`), así que prometerlo en el
  /// subtítulo sería incorrecto.
  String get _subtitle {
    if (groupRequired) {
      return 'Elige entre 1 y $groupMaxSelectable';
    }
    final fitsWholeCatalog = groupMaxSelectable >= options.length;
    if (!allowWithout) {
      return fitsWholeCatalog
          ? 'Elige las que quieras'
          : 'Elige hasta $groupMaxSelectable';
    }
    if (fitsWholeCatalog) {
      return 'Elige las que quieras, o "$noneLabel"';
    }
    return 'Elige hasta $groupMaxSelectable, o "$noneLabel"';
  }

  /// "Sin X" es siempre información propia (no solo "ya elegiste algo"), así
  /// que se muestra igual sin importar `groupRequired`. Con una selección
  /// real, la señal depende del tipo de grupo — un grupo OBLIGATORIO ya
  /// tiene al badge ("Obligatorio"/"Listo", ver `_badge`) como única fuente
  /// de esa señal, así que acá queda en blanco para no duplicarla; un grupo
  /// OPCIONAL no tiene badge (`_badge` es `null` ahí), así que el resumen
  /// SÍ necesita decir algo — "✓ Seleccionado" en vez del detalle real (ese
  /// sigue disponible abriendo el diálogo, `_openDialog`).
  String get _summaryText {
    if (explicitlyNone) return noneLabel;
    if (groupRequired) return '';
    if (selectedIds.isEmpty) return '';
    return '✓ Seleccionado';
  }

  /// Badge dentro del campo, a la derecha (ver `build`). "Listo"
  /// (`CeltasColors.success`, ver justificación en `app_theme.dart`) se
  /// muestra apenas hay alguna opción REAL elegida, sea el grupo obligatorio
  /// u opcional — un grupo opcional con selección también merece esa señal
  /// positiva, no solo el resumen "✓ Seleccionado" del campo (`_summaryText`).
  /// "Obligatorio" (naranja) solo aplica al grupo obligatorio sin nada
  /// elegido todavía; un grupo opcional sin selección no muestra ningún
  /// badge (`null`) — el subtítulo ya cubre ese caso. `explicitlyNone` no
  /// cuenta para "Listo" acá a propósito: "Sin X" ya queda explícito en el
  /// resumen del campo (`noneLabel`), un badge adicional sería ruido.
  ({String label, Color color})? get _badge {
    if (selectedIds.isNotEmpty) {
      return (label: 'Listo', color: CeltasColors.success);
    }
    return groupRequired
        ? (label: 'Obligatorio', color: CeltasColors.orange)
        : null;
  }

  Future<void> _openDialog(BuildContext context) async {
    final tempSelected = Set<String>.from(selectedIds);
    var tempExplicitlyNone = explicitlyNone;
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: CeltasColors.surface,
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: CeltasColors.cream,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  CheckboxListTile(
                    key: ValueKey('detail-$testKey-option-${option.id}'),
                    value: tempSelected.contains(option.id),
                    dense: true,
                    activeColor: CeltasColors.orange,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      option.label,
                      style: const TextStyle(color: CeltasColors.cream),
                    ),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked ?? false) {
                          tempSelected.add(option.id);
                          // Mutuamente excluyente con "Sin X": elegir
                          // cualquier opción real desmarca ese checkbox si
                          // estaba activo.
                          tempExplicitlyNone = false;
                        } else {
                          tempSelected.remove(option.id);
                        }
                      });
                    },
                  ),
                if (!groupRequired && allowWithout)
                  CheckboxListTile(
                    key: ValueKey('detail-$testKey-option-none'),
                    value: tempExplicitlyNone,
                    dense: true,
                    activeColor: CeltasColors.orange,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      noneLabel,
                      style: const TextStyle(color: CeltasColors.cream),
                    ),
                    onChanged: (checked) {
                      setDialogState(() {
                        tempExplicitlyNone = checked ?? false;
                        // Mutuamente excluyente con las opciones reales:
                        // limpia cualquier selección previa.
                        if (tempExplicitlyNone) tempSelected.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: ValueKey('detail-$testKey-dialog-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: CeltasColors.textMuted),
              ),
            ),
            TextButton(
              key: ValueKey('detail-$testKey-dialog-ok'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'ACEPTAR',
                style: TextStyle(color: CeltasColors.orange),
              ),
            ),
          ],
        ),
      ),
    );
    if (applied == true) {
      onApply(tempSelected, tempExplicitlyNone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = explicitlyNone || selectedIds.isNotEmpty;
    final summaryText = _summaryText;
    final hasContent = summaryText.isNotEmpty;
    final displayText = hasContent ? summaryText : hintText;
    // El borde rojo de `isHighlighted` (violación recién resaltada por
    // `_handleValidationFailure`) manda sobre el naranja de "hay selección"
    // — son mutuamente excluyentes en la práctica (un campo resaltado
    // siempre está incompleto), pero el orden deja explícito cuál gana si
    // algún día dejaran de serlo.
    final borderColor = isHighlighted
        ? CeltasColors.redLight
        : hasSelection
        ? CeltasColors.orange
        : CeltasColors.border;
    final borderWidth = isHighlighted ? 2.0 : (hasSelection ? 1.5 : 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: CeltasColors.textLabel,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: CeltasColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: ValueKey('detail-$testKey-dropdown'),
          onTap: () => _openDialog(context),
          child: Container(
            // `fieldKey`, no el `ValueKey` de arriba — es el que
            // `_ProductDetailBodyState._handleValidationFailure` usa para
            // `Scrollable.ensureVisible` hacia este campo concreto.
            key: fieldKey,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: CeltasColors.surface,
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(CeltasRadii.input),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: hasContent
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: hasContent
                          ? CeltasColors.orange
                          : CeltasColors.textSubtle,
                    ),
                  ),
                ),
                // Badge "Obligatorio"/"Listo" dentro del campo, a la
                // derecha — reemplaza la etiqueta fija que antes vivía
                // afuera, a la izquierda del campo (ver `_badge`).
                if (_badge case final badge?) ...[
                  const SizedBox(width: 8),
                  _RequiredBadge(label: badge.label, color: badge.color),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: hasSelection
                      ? CeltasColors.orange
                      : CeltasColors.textSubtle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge inline "Obligatorio"/"Listo" dentro de [_OptionGroupDropdown] — ver
/// `_OptionGroupDropdown._badge`. Mismo lenguaje visual que
/// `OrderStatusBadge` (`lib/features/orders/presentation/widgets/
/// order_status_badge.dart`: pill + color de estado), pero con relleno
/// translúcido en vez de sólido y a menor escala, para caber dentro de un
/// campo de una sola línea sin competir visualmente con el texto del resumen.
class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(CeltasRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
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
