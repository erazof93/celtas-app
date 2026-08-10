// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_menu_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicMenuCategory _$PublicMenuCategoryFromJson(Map<String, dynamic> json) =>
    _PublicMenuCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((e) => PublicMenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PublicMenuCategoryToJson(_PublicMenuCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'items': instance.items,
    };
