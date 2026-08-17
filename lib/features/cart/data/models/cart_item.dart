import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_item.freezed.dart';

/// Ítem del carrito local (100% en memoria, Riverpod).
///
/// Snapshot al momento de agregar: `unitPrice`, `image` y `selectedSauces`
/// se copian del producto del menú y de la selección hecha en el detalle
/// cuando se agrega, así el carrito no depende de que el menú siga cargado
/// ni de cambios posteriores en el backend (mismo criterio "snapshot" que
/// ya usa el resto del proyecto, ej. `OrderItem.selectedSauces` en el
/// backend).
///
/// Es estado local: no se serializa a JSON (el backend nunca recibe el
/// carrito completo, solo `menuItemId` + `quantity` + `sauceIds` al crear
/// el pedido — ver `order_repository.dart`), por eso no tiene `fromJson`.
@freezed
abstract class CartItem with _$CartItem {
  const factory CartItem({
    required String menuItemId,
    required String name,
    required double unitPrice,
    required int quantity,
    String? image,
    @Default(<SauceOption>[]) List<SauceOption> selectedSauces,
    // Tri-state real junto con `selectedSauces`: SOLO puede ser `true`
    // cuando el producto ofrece salsas (`PublicMenuItem.sauces.isNotEmpty`)
    // Y el cliente tocó explícitamente el chip "Sin salsas" del selector —
    // distingue "no aplica" (producto sin catálogo, este campo se queda en
    // `false` siempre) de "el cliente eligió deliberadamente ninguna". Ver
    // `order_repository.dart`: con `selectedSauces` vacío, este campo decide
    // si `sauceIds` se manda como `[]` explícito o se omite del todo.
    @Default(false) bool explicitlyNoSauces,
  }) = _CartItem;

  const CartItem._();

  /// Subtotal del ítem (precio unitario × cantidad).
  double get lineTotal => unitPrice * quantity;

  /// Identifica una fila única del carrito. El mismo producto CON la misma
  /// combinación de salsas se fusiona en una sola fila (suma cantidad); el
  /// mismo producto con OTRA combinación queda en una fila aparte — ej. una
  /// Celtas Burguesa con mayonesa y otra sin nada son dos líneas distintas
  /// del carrito, cada una con su propio stepper de cantidad.
  ///
  /// Sin salsas seleccionadas, la key es igual al `menuItemId` puro — mismo
  /// valor que ya usaban `increment`/`decrement`/`removeItem` y los
  /// `ValueKey` del carrito antes de que existieran las salsas, así ningún
  /// producto sin salsas cambia de comportamiento con este agregado.
  String get lineKey {
    if (selectedSauces.isEmpty) return menuItemId;
    final sortedIds = selectedSauces.map((sauce) => sauce.id).toList()
      ..sort();
    return '$menuItemId::${sortedIds.join(',')}';
  }
}