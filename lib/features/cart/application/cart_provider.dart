import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_provider.freezed.dart';

/// Estado del carrito: 100% local (Riverpod), no existe en el backend hasta
/// que se confirma el pedido (`POST /orders`, módulo 5).
///
/// `coupon` guarda el cupón YA validado contra `POST /coupons/validate` — la
/// app muestra el descuento que aplicaría pero el canje real ocurre en el
/// backend al crear el pedido.
@freezed
abstract class CartState with _$CartState {
  const factory CartState({
    @Default(<CartItem>[]) List<CartItem> items,
    ValidatedCoupon? coupon,
    // Aviso de una sola vez cuando `CartNotifier` quita el cupón solo
    // (subtotal cayó por debajo del mínimo tras decrementar/quitar un
    // ítem). La UI lo muestra (SnackBar) y llama a `dismissCouponNotice()`.
    // No aplica cuando el cupón se limpia por carrito vacío: ahí no hay
    // ítems visibles para asociar el aviso.
    String? couponRemovedNotice,
  }) = _CartState;

  const CartState._();

  /// Cantidad total de unidades (suma de `quantity` de todos los ítems).
  int get totalCount =>
      items.fold(0, (sum, item) => sum + item.quantity);

  /// Subtotal sin descuento.
  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  /// Descuento que aplicaría el cupón validado, espejando la fórmula del
  /// backend (`CouponsService.applyDiscount`): porcentaje sobre el subtotal o
  /// monto fijo, nunca bajando el total de 0. Solo es una vista previa — el
  /// total real lo recalcula el backend al crear el pedido.
  double get discount {
    final coupon = this.coupon;
    if (coupon == null) return 0;
    final raw = coupon.discountType == CouponDiscountType.percentage
        ? subtotal * coupon.discountValue / 100
        : coupon.discountValue;
    return raw.clamp(0, subtotal);
  }

  /// Total con descuento aplicado (vista previa para la UI).
  double get total => subtotal - discount;
}

/// Notifier del carrito local.
///
/// Métodos: `addItem` (desde Home "+" o desde el detalle con cantidad y
/// salsas), `updateLine` (edición de una fila ya existente desde el ícono de
/// lápiz del carrito), `increment`/`decrement` (steppers del carrito),
/// `removeItem`, `clear` (tras confirmar el pedido),
/// `applyCoupon`/`removeCoupon`.
///
/// `increment`/`decrement`/`removeItem` identifican la fila por
/// `CartItem.lineKey` (no por `menuItemId` puro): un mismo producto puede
/// tener varias filas si el cliente lo agregó con distintas combinaciones
/// de salsas — ver el doc de `lineKey` en `cart_item.dart`. Sin salsas,
/// `lineKey == menuItemId`, así que todo lo que ya llamaba a estos métodos
/// con un `menuItemId` sigue funcionando igual.
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Agrega `quantity` unidades de un producto del menú, con la selección
  /// de salsas hecha en el detalle (vacía si el producto no ofrece salsas
  /// o el cliente no eligió ninguna). Si ya existe una fila con el mismo
  /// producto Y la misma combinación de salsas, suma a la cantidad
  /// existente (no duplica la fila); si las salsas son distintas, se agrega
  /// como una fila nueva.
  void addItem(
    PublicMenuItem item, {
    int quantity = 1,
    List<SauceOption> selectedSauces = const [],
    bool explicitlyNoSauces = false,
  }) {
    if (quantity <= 0) return;
    final newLine = CartItem(
      menuItemId: item.id,
      name: item.name,
      unitPrice: item.price,
      quantity: quantity,
      image: item.image,
      selectedSauces: selectedSauces,
      explicitlyNoSauces: explicitlyNoSauces,
    );
    final items = state.items;
    final index = items.indexWhere((i) => i.lineKey == newLine.lineKey);
    if (index >= 0) {
      state = state.copyWith(
        items: [
          for (var i = 0; i < items.length; i++)
            if (i == index)
              items[i].copyWith(
                quantity: items[i].quantity + quantity,
                explicitlyNoSauces:
                    items[i].explicitlyNoSauces || explicitlyNoSauces,
              )
            else
              items[i],
        ],
      );
    } else {
      state = state.copyWith(items: [...items, newLine]);
    }
  }

  /// Reemplaza la fila `oldLineKey` con la cantidad y salsas nuevas —
  /// edición desde el ícono de lápiz del carrito (`ProductDetailScreen` en
  /// modo edición). A diferencia de `addItem`, no suma a lo que ya había:
  /// la cantidad nueva REEMPLAZA la anterior (el detalle precarga el stepper
  /// con la cantidad actual de la fila, así que lo que confirma el usuario
  /// ya es el total final que quiere, no un incremento).
  ///
  /// Si la combinación nueva de salsas coincide con OTRA fila ya existente
  /// del mismo producto, se fusionan sumando cantidades y la fila vieja se
  /// descarta — mismo criterio de fusión por `lineKey` que ya usa `addItem`,
  /// para no terminar con dos filas duplicadas del mismo producto + misma
  /// combinación de salsas. Si `oldLineKey` no existe (fila ya eliminada por
  /// otra vía mientras se editaba), no hace nada.
  void updateLine(
    String oldLineKey, {
    required int quantity,
    required List<SauceOption> selectedSauces,
    bool explicitlyNoSauces = false,
  }) {
    if (quantity <= 0) return;
    final items = state.items;
    final oldIndex = items.indexWhere((i) => i.lineKey == oldLineKey);
    if (oldIndex < 0) return;
    final updated = items[oldIndex].copyWith(
      quantity: quantity,
      selectedSauces: selectedSauces,
      explicitlyNoSauces: explicitlyNoSauces,
    );
    final mergeIndex = items.indexWhere((i) => i.lineKey == updated.lineKey);
    if (mergeIndex >= 0 && mergeIndex != oldIndex) {
      state = state.copyWith(
        items: [
          for (var i = 0; i < items.length; i++)
            if (i == mergeIndex)
              items[i].copyWith(
                quantity: items[i].quantity + quantity,
                explicitlyNoSauces:
                    items[i].explicitlyNoSauces || explicitlyNoSauces,
              )
            else if (i != oldIndex)
              items[i],
        ],
      );
    } else {
      state = state.copyWith(
        items: [
          for (var i = 0; i < items.length; i++)
            if (i == oldIndex) updated else items[i],
        ],
      );
    }
  }

  /// Suma 1 unidad. Si la fila no existe, no hace nada.
  void increment(String lineKey) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.lineKey == lineKey)
            item.copyWith(quantity: item.quantity + 1)
          else
            item,
      ],
    );
  }

  /// Resta 1 unidad. Al llegar a 0 la fila se elimina del carrito.
  void decrement(String lineKey) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.lineKey == lineKey && item.quantity > 1)
            item.copyWith(quantity: item.quantity - 1)
          else if (item.lineKey == lineKey)
            // quantity == 1 → se elimina (filtrado abajo).
            item.copyWith(quantity: 0)
          else
            item,
      ].where((item) => item.quantity > 0).toList(),
    );
    _clearCouponIfInvalid();
  }

  /// Elimina la fila del carrito.
  void removeItem(String lineKey) {
    state = state.copyWith(
      items: state.items.where((item) => item.lineKey != lineKey).toList(),
    );
    _clearCouponIfInvalid();
  }

  /// Vacía el carrito (tras confirmar el pedido en el módulo 5).
  void clear() => state = const CartState();

  /// Guarda el cupón ya validado contra el backend (vista previa del
  /// descuento). El canje real ocurre al crear el pedido.
  ///
  /// Re-chequea el mínimo contra el subtotal ACTUAL (no el que existía
  /// cuando arrancó la validación): el carrito puede haber cambiado durante
  /// el `await` de `POST /coupons/validate` (el backend puede tardar 30-50s
  /// en despertar), y los steppers de cantidad no se bloquean mientras se
  /// espera esa respuesta. Sin este chequeo se mostraría un descuento de
  /// vista previa que ya no es válido. Devuelve `false` sin aplicar el
  /// cupón si eso pasó, para que la UI lo informe.
  bool applyCoupon(ValidatedCoupon coupon) {
    if (coupon.hasMinPurchase && state.subtotal < coupon.minPurchaseAmount!) {
      return false;
    }
    state = state.copyWith(coupon: coupon);
    return true;
  }

  /// Quita el cupón aplicado (el usuario decide no usarlo).
  void removeCoupon() => state = state.copyWith(coupon: null);

  /// Descarta el aviso de "cupón quitado" ya mostrado.
  void dismissCouponNotice() {
    if (state.couponRemovedNotice != null) {
      state = state.copyWith(couponRemovedNotice: null);
    }
  }

  /// Si el carrito quedó vacío, el cupón aplicado pierde sentido: se limpia
  /// (sin aviso, no hay ítems visibles para asociarlo). Si el carrito sigue
  /// con ítems pero el subtotal bajó del mínimo del cupón (`decrement`), se
  /// limpia también, esta vez con un aviso explícito — sin esto el usuario
  /// vería un descuento de vista previa que el backend igual rechazaría al
  /// confirmar el pedido.
  void _clearCouponIfInvalid() {
    final coupon = state.coupon;
    if (coupon == null) return;
    if (state.items.isEmpty) {
      state = state.copyWith(coupon: null);
      return;
    }
    if (coupon.hasMinPurchase && state.subtotal < coupon.minPurchaseAmount!) {
      state = state.copyWith(
        coupon: null,
        couponRemovedNotice: 'El cupón ${coupon.code} se quitó: el pedido ya '
            'no alcanza el mínimo de S/ '
            '${coupon.minPurchaseAmount!.toStringAsFixed(2)}',
      );
    }
  }
}

/// Provider del carrito local.
final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);