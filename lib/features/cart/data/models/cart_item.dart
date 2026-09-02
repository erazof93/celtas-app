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
/// El backend nunca recibe el carrito completo (solo `menuItemId` +
/// `quantity` + `sauceIds` al crear el pedido — ver `order_repository.dart`).
/// `toStorageJson`/`fromStorageJson` existen SOLO para la caché local del
/// carrito en `SharedPreferences` (ver `CartStorage`): serialización manual,
/// sin `.g.dart` propio (nombres deliberadamente distintos de `toJson`/
/// `fromJson` para no activar la generación de json_serializable de
/// freezed). Se reusa el `toJson`/`fromJson` que `SauceOption` ya genera
/// para las salsas anidadas.
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
    // Nota libre opcional del cliente para este ítem (ej. "sin cebolla"),
    // espejo de `OrderItem.comment` en el backend. `null`/vacío = sin
    // comentario — se normaliza a `null` al agregar/editar la fila (ver
    // `CartNotifier`), nunca se guarda como string vacío o solo espacios.
    String? comment,
    // `id` del `RewardRedemption` que este ítem canjea, si es un premio del
    // programa de Estrellas agregado desde `RewardRedeemScreen`
    // (`CartNotifier.addRewardItem`). `null` = ítem normal del menú. Se manda
    // tal cual al backend en `POST /orders` (ver `order_repository.dart`), que
    // fuerza `unitPrice` a 0 y exige `quantity == 1` para estos ítems.
    String? rewardRedemptionId,
  }) = _CartItem;

  const CartItem._();

  /// Reconstruye un ítem desde la caché local (`CartStorage`). Serialización
  /// manual, tolerante: los campos opcionales que falten caen a su default
  /// (mismo criterio que el `@Default` del `factory`). Los ítems de premio
  /// nunca se persisten, pero `rewardRedemptionId` se lee igual por
  /// simetría con `toStorageJson`.
  factory CartItem.fromStorageJson(Map<String, dynamic> json) => CartItem(
        menuItemId: json['menuItemId'] as String,
        name: json['name'] as String,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        quantity: json['quantity'] as int,
        image: json['image'] as String?,
        selectedSauces: (json['selectedSauces'] as List<dynamic>? ?? const [])
            .map((e) => SauceOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        explicitlyNoSauces: json['explicitlyNoSauces'] as bool? ?? false,
        comment: json['comment'] as String?,
        rewardRedemptionId: json['rewardRedemptionId'] as String?,
      );

  /// Serializa el ítem para la caché local. Omite los campos en su valor
  /// por defecto para no engordar el JSON guardado.
  Map<String, dynamic> toStorageJson() => {
        'menuItemId': menuItemId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
        if (image != null) 'image': image,
        if (selectedSauces.isNotEmpty)
          'selectedSauces': [
            for (final sauce in selectedSauces) sauce.toJson(),
          ],
        if (explicitlyNoSauces) 'explicitlyNoSauces': true,
        if (comment != null) 'comment': comment,
        if (rewardRedemptionId != null)
          'rewardRedemptionId': rewardRedemptionId,
      };

  /// Subtotal del ítem (precio unitario × cantidad).
  double get lineTotal => unitPrice * quantity;

  /// Identifica una fila única del carrito. El mismo producto CON la misma
  /// combinación de salsas Y el mismo comentario se fusiona en una sola fila
  /// (suma cantidad); si cualquiera de los dos difiere, queda en una fila
  /// aparte — ej. una Celtas Burguesa con mayonesa y otra sin nada son dos
  /// líneas distintas del carrito, igual que una Celtas Burguesa con nota
  /// "sin cebolla" y otra sin nota, cada una con su propio stepper de
  /// cantidad.
  ///
  /// Sin salsas ni comentario, la key es igual al `menuItemId` puro — mismo
  /// valor que ya usaban `increment`/`decrement`/`removeItem` y los
  /// `ValueKey` del carrito antes de que existieran las salsas/el
  /// comentario, así ningún producto sin ninguno de los dos cambia de
  /// comportamiento con este agregado. Con solo salsas (sin comentario) la
  /// key tampoco cambia respecto a antes de este agregado (`menuItemId::
  /// idsOrdenados`) — el comentario solo agrega un segmento extra cuando
  /// hay uno, en vez de ensuciar la key con un separador vacío de más.
  ///
  /// Un ítem de premio (`rewardRedemptionId != null`) corta ANTES de esta
  /// lógica: cada `RewardRedemption` es una entidad real separada, así que
  /// nunca se fusiona con una fila normal del mismo producto (aunque
  /// coincidan `menuItemId`/salsas/comentario) ni con otro premio distinto —
  /// la cantidad de su fila queda siempre en 1.
  String get lineKey {
    if (rewardRedemptionId != null) return 'reward::$rewardRedemptionId';
    if (selectedSauces.isEmpty && comment == null) return menuItemId;
    final parts = [menuItemId];
    if (selectedSauces.isNotEmpty) {
      final sortedIds = selectedSauces.map((sauce) => sauce.id).toList()
        ..sort();
      parts.add(sortedIds.join(','));
    }
    if (comment != null) parts.add(comment!);
    return parts.join('::');
  }
}