import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_item.freezed.dart';

/// Ítem del carrito local (100% en memoria, Riverpod).
///
/// Snapshot al momento de agregar: `unitPrice` y `image` se copian del
/// producto del menú cuando se agrega, así el carrito no depende de que el
/// menú siga cargado ni de cambios de precio posteriores en el backend.
///
/// Es estado local: no se serializa a JSON (el backend nunca recibe el
/// carrito, solo `menuItemId` + `quantity` al crear el pedido), por eso no
/// tiene `fromJson`.
@freezed
abstract class CartItem with _$CartItem {
  const factory CartItem({
    required String menuItemId,
    required String name,
    required double unitPrice,
    required int quantity,
    String? image,
  }) = _CartItem;

  const CartItem._();

  /// Subtotal del ítem (precio unitario × cantidad).
  double get lineTotal => unitPrice * quantity;
}