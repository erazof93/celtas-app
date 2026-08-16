import 'package:freezed_annotation/freezed_annotation.dart';

part 'sauce_option.freezed.dart';
part 'sauce_option.g.dart';

/// Salsa/crema que un producto ofrece para elegir (ej. Mayonesa, Mostaza,
/// Ketchup), tal como la devuelve `GET /menu` dentro de cada ítem.
///
/// Contrato verificado contra `celtas-backend/src/modules/menu/menu.service.ts`
/// (`findPublicMenu`): el endpoint público solo expone `id` y `name` de cada
/// salsa — ya viene filtrado a `active: true` y ordenado por `sortOrder`/
/// `name`, la app no repite ese criterio.
///
/// Se reusa el mismo shape para `CartItem.selectedSauces` (lo que el cliente
/// eligió en el detalle de producto): ahí no viene de un `fromJson`, se arma
/// a mano a partir de las opciones ya cargadas en `PublicMenuItem.sauces`.
@freezed
abstract class SauceOption with _$SauceOption {
  const factory SauceOption({required String id, required String name}) =
      _SauceOption;

  factory SauceOption.fromJson(Map<String, dynamic> json) =>
      _$SauceOptionFromJson(json);
}
