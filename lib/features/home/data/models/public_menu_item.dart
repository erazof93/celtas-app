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
/// ítem (ver `OrdersService.buildItems` en el backend). `beverageGroupRequired`/
/// `beverageGroupMaxSelectable` y `extraPortionsGroupRequired`/
/// `extraPortionsGroupMaxSelectable` viajan SIEMPRE (aunque el array
/// correspondiente esté vacío) — el backend los valida en
/// `OrdersService.validateGroupSelection` al crear el pedido, así que la app
/// debe espejar la misma validación localmente (UX) pero nunca confiar solo
/// en ella (el backend rechaza con 400 igual si se le manda algo inválido).
@freezed
abstract class PublicMenuItem with _$PublicMenuItem {
  const factory PublicMenuItem({
    required String id,
    required String name,
    String? description,
    required double price,
    String? image,
    @Default(<SauceOption>[]) List<SauceOption> sauces,
    @Default(<BeverageOption>[]) List<BeverageOption> beverages,
    @Default(false) bool beverageGroupRequired,
    @Default(0) int beverageGroupMaxSelectable,
    @Default(<ExtraPortionOption>[]) List<ExtraPortionOption> extraPortions,
    @Default(false) bool extraPortionsGroupRequired,
    @Default(0) int extraPortionsGroupMaxSelectable,
  }) = _PublicMenuItem;

  factory PublicMenuItem.fromJson(Map<String, dynamic> json) =>
      _$PublicMenuItemFromJson(json);
}