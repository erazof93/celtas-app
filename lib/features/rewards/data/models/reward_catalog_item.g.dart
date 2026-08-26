// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_catalog_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RewardCatalogItem _$RewardCatalogItemFromJson(Map<String, dynamic> json) =>
    _RewardCatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
    );

Map<String, dynamic> _$RewardCatalogItemToJson(_RewardCatalogItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'image': instance.image,
    };
