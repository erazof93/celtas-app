import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_menu_item.freezed.dart';
part 'public_menu_item.g.dart';

/// Producto del menú público, tal como lo devuelve `GET /menu`.
///
/// Contrato verificado contra `celtas-backend/src/modules/menu/menu.service.ts`
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
@freezed
abstract class PublicMenuItem with _$PublicMenuItem {
  const factory PublicMenuItem({
    required String id,
    required String name,
    String? description,
    required double price,
    String? image,
    @Default(<SauceOption>[]) List<SauceOption> sauces,
  }) = _PublicMenuItem;

  factory PublicMenuItem.fromJson(Map<String, dynamic> json) =>
      _$PublicMenuItemFromJson(json);
}