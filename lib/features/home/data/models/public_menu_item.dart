import 'package:celtas_mobile/features/home/data/models/beverage_option.dart';
import 'package:celtas_mobile/features/home/data/models/extra_portion_option.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_menu_item.freezed.dart';
part 'public_menu_item.g.dart';

/// Producto del menú público, tal como lo devuelve `GET /menu`.
///
/// Contrato verificado contra `backend-celtas/src/modules/menu/menu.service.ts`
/// (interfaz `PublicMenuCategory['items']`): el endpoint público NO expone
/// `available`, `categoryId` ni `createdAt`/`updatedAt` — solo los campos que
/// le interesan a la app.
///
/// `sauces`: salsas/cremas que el producto ofrece para elegir (Mayonesa,
/// Mostaza, Ketchup...), ya filtradas a `active: true` y ordenadas por el
/// backend. Lista vacía = el producto no ofrece selector de salsas en el
/// detalle (ej. arroz chaufa) — es el mismo criterio que ya usa
/// `celtas-admin` para decidir si un producto muestra el checklist de
/// salsas en su formulario.
///
/// `beverages`/`extraPortions`: mismo criterio que `sauces` (activas,
/// ordenadas, vacío = sin selector), pero SÍ suman precio — a diferencia de
/// las salsas, cada opción elegida suma su `price` una vez por unidad del
/// ítem (ver `OrdersService.buildItems` en el backend). `sauceGroupRequired`/
/// `sauceGroupMaxSelectable`, `beverageGroupRequired`/
/// `beverageGroupMaxSelectable` y `extraPortionsGroupRequired`/
/// `extraPortionsGroupMaxSelectable` viajan SIEMPRE (aunque el array
/// correspondiente esté vacío) — el backend los valida en
/// `OrdersService.validateGroupSelection` al crear el pedido, así que la app
/// debe espejar la misma validación localmente (UX) pero nunca confiar solo
/// en ella (el backend rechaza con 400 igual si se le manda algo inválido).
///
/// `sauceGroupMaxSelectable` es el ÚNICO máximo nullable: `null` = sin límite
/// de salsas (columna nullable, default NULL — migración
/// `MakeSauceGroupMaxSelectableNullable` en el backend, que espeja
/// `validateGroupSelection` con `groupMaxSelectable !== null`). Por eso NO
/// lleva `@Default`: un `null` (o el campo ausente) debe llegar como `null`,
/// no como `0` — con `0` la app bloquearía todas las salsas del producto.
/// `beverageGroupMaxSelectable`/`extraPortionsGroupMaxSelectable` siguen NOT
/// NULL default 1 en el backend, así que siguen siendo `int`.
///
/// `sauceAllowWithout`/`beverageAllowWithout`/`extraPortionsAllowWithout`
/// (default `true`, viajan SIEMPRE igual que los `GroupRequired`/`Max` de
/// arriba — ver `MenuService.findPublicMenu` en el backend, columnas NOT
/// NULL DEFAULT true): si la app debe ofrecer el checkbox "Sin X" para esa
/// categoría. Nombre real del tercer campo es `extraPortionsAllowWithout`
/// (plural "Portions", igual que `extraPortionsGroupRequired`/`Max`), NO
/// `extraPortionAllowWithout` — confirmado contra
/// `backend-celtas/src/modules/menu/entities/menu-item.entity.ts` y
/// `celtas-admin/src/features/menu/types.ts`. Aplica también con el grupo
/// obligatorio: ahí "Sin X" es una elección válida que resuelve el grupo
/// (`OrdersService.validateGroupSelection` en el backend acepta `[]` con
/// `allowWithout: true`, pero sigue rechazando el campo omitido — ver
/// `_sauceChoiceViolation` y hermanos en `product_detail_screen.dart`).
@freezed
abstract class PublicMenuItem with _$PublicMenuItem {
  const factory PublicMenuItem({
    required String id,
    required String name,
    String? description,
    required double price,
    String? image,
    @Default(<SauceOption>[]) List<SauceOption> sauces,
    @Default(false) bool sauceGroupRequired,
    int? sauceGroupMaxSelectable,
    @Default(true) bool sauceAllowWithout,
    @Default(<BeverageOption>[]) List<BeverageOption> beverages,
    @Default(false) bool beverageGroupRequired,
    @Default(0) int beverageGroupMaxSelectable,
    @Default(true) bool beverageAllowWithout,
    @Default(<ExtraPortionOption>[]) List<ExtraPortionOption> extraPortions,
    @Default(false) bool extraPortionsGroupRequired,
    @Default(0) int extraPortionsGroupMaxSelectable,
    @Default(true) bool extraPortionsAllowWithout,
    @Default(<FriesType>[]) List<FriesType> friesTypes,
    @Default(false) bool friesTypeGroupRequired,
    @Default(1) int friesTypeGroupMaxSelectable,
  }) = _PublicMenuItem;

  factory PublicMenuItem.fromJson(Map<String, dynamic> json) =>
      _$PublicMenuItemFromJson(json);
}

/// Tipo de papas que un producto ofrece (ej. "Papas fritas", "Papas al
/// hilo"), tal como lo devuelve `GET /menu` dentro de cada ítem en
/// `friesTypes`.
///
/// Contrato verificado contra `backend-celtas/src/modules/menu/menu.service.ts`
/// (`findPublicMenu`): cada tipo expone `id`, `name` e `isDefault`, ordenados
/// con el default primero y luego alfabético. Vacío = el producto no muestra
/// selector de papas. `friesTypeGroupRequired` (default `false`) y
/// `friesTypeGroupMaxSelectable` (NOT NULL default 1) viajan SIEMPRE, igual
/// que los de bebidas/extras — ver `menu-item.entity.ts`. No suman precio y no
/// hay flag `AllowWithout`: la app nunca ofrece "Sin papas".
///
/// Se reusa el mismo shape para `CartItem.selectedFriesTypes`.
@freezed
abstract class FriesType with _$FriesType {
  const factory FriesType({
    required String id,
    required String name,
    @Default(false) bool isDefault,
  }) = _FriesType;

  factory FriesType.fromJson(Map<String, dynamic> json) =>
      _$FriesTypeFromJson(json);
}