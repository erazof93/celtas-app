import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_menu_item.freezed.dart';
part 'public_menu_item.g.dart';

/// Producto del menú público, tal como lo devuelve `GET /menu`.
///
/// Contrato verificado contra `celtas-backend/src/modules/menu/menu.service.ts`
/// (interfaz `PublicMenuCategory['items']`): el endpoint público NO expone
/// `available`, `categoryId` ni `createdAt`/`updatedAt` — solo los campos que
/// le interesan a la app.
@freezed
abstract class PublicMenuItem with _$PublicMenuItem {
  const factory PublicMenuItem({
    required String id,
    required String name,
    String? description,
    required double price,
    String? image,
  }) = _PublicMenuItem;

  factory PublicMenuItem.fromJson(Map<String, dynamic> json) =>
      _$PublicMenuItemFromJson(json);
}