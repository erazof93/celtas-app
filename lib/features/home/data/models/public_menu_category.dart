import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_menu_category.freezed.dart';
part 'public_menu_category.g.dart';

/// Categoría del menú público con sus productos, tal como la devuelve
/// `GET /menu`.
///
/// Contrato verificado contra `celtas-backend/src/modules/menu/menu.service.ts`
/// (interfaz `PublicMenuCategory`): el endpoint público NO expone `image`,
/// `active` ni `sortOrder` de la categoría — solo `id`, `name`, `description`
/// e `items` (productos disponibles, ordenados por nombre).
@freezed
abstract class PublicMenuCategory with _$PublicMenuCategory {
  const factory PublicMenuCategory({
    required String id,
    required String name,
    String? description,
    required List<PublicMenuItem> items,
  }) = _PublicMenuCategory;

  factory PublicMenuCategory.fromJson(Map<String, dynamic> json) =>
      _$PublicMenuCategoryFromJson(json);
}