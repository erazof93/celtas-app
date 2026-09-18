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
/// `sauceAllowWithout`/`beverageAllowWithout`/`extraPortionsAllowWithout`
/// (default `true`, viajan SIEMPRE igual que los `GroupRequired`/`Max` de
/// arriba — ver `MenuService.findPublicMenu` en el backend, columnas NOT
/// NULL DEFAULT true): si la app debe ofrecer el checkbox "Sin X" para esa
/// categoría. Nombre real del tercer campo es `extraPortionsAllowWithout`
/// (plural "Portions", igual que `extraPortionsGroupRequired`/`Max`), NO
/// `extraPortionAllowWithout` — confirmado contra
/// `backend-celtas/src/modules/menu/entities/menu-item.entity.ts` y
/// `celtas-admin/src/features/menu/types.ts`. El admin puede activar este
/// flag en un grupo obligatorio sin que tenga ningún efecto real: el checkbox
/// solo se ofrece con el grupo OPCIONAL (`!groupRequired`) — con
/// `groupRequired: true`, "Sin X" nunca es una selección válida
/// (`OrdersService.validateGroupSelection` en el backend rechaza
/// `selected.length === 0` igual, sin importar `AllowWithout`), así que
/// ofrecerlo ahí sería un callejón sin salida para el cliente (ver
/// `_OptionGroupDropdown._openDialog` en `product_detail_screen.dart`).
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
    @Default(0) int sauceGroupMaxSelectable,
    @Default(true) bool sauceAllowWithout,
    @Default(<BeverageOption>[]) List<BeverageOption> beverages,
    @Default(false) bool beverageGroupRequired,
    @Default(0) int beverageGroupMaxSelectable,
    @Default(true) bool beverageAllowWithout,
    @Default(<ExtraPortionOption>[]) List<ExtraPortionOption> extraPortions,
    @Default(false) bool extraPortionsGroupRequired,
    @Default(0) int extraPortionsGroupMaxSelectable,
    @Default(true) bool extraPortionsAllowWithout,
  }) = _PublicMenuItem;

  factory PublicMenuItem.fromJson(Map<String, dynamic> json) =>
      _$PublicMenuItemFromJson(json);
}