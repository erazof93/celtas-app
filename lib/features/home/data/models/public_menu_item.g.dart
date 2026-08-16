// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_menu_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicMenuItem _$PublicMenuItemFromJson(Map<String, dynamic> json) =>
    _PublicMenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
      sauces:
          (json['sauces'] as List<dynamic>?)
              ?.map((e) => SauceOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PublicMenuItemToJson(_PublicMenuItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'image': instance.image,
      'sauces': instance.sauces,
    };
