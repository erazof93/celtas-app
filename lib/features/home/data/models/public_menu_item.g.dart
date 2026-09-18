// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_menu_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicMenuItem _$PublicMenuItemFromJson(
  Map<String, dynamic> json,
) => _PublicMenuItem(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  price: (json['price'] as num).toDouble(),
  image: json['image'] as String?,
  sauces:
      (json['sauces'] as List<dynamic>?)
          ?.map((e) => SauceOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SauceOption>[],
  sauceGroupRequired: json['sauceGroupRequired'] as bool? ?? false,
  sauceGroupMaxSelectable:
      (json['sauceGroupMaxSelectable'] as num?)?.toInt() ?? 0,
  sauceAllowWithout: json['sauceAllowWithout'] as bool? ?? true,
  beverages:
      (json['beverages'] as List<dynamic>?)
          ?.map((e) => BeverageOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <BeverageOption>[],
  beverageGroupRequired: json['beverageGroupRequired'] as bool? ?? false,
  beverageGroupMaxSelectable:
      (json['beverageGroupMaxSelectable'] as num?)?.toInt() ?? 0,
  beverageAllowWithout: json['beverageAllowWithout'] as bool? ?? true,
  extraPortions:
      (json['extraPortions'] as List<dynamic>?)
          ?.map((e) => ExtraPortionOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ExtraPortionOption>[],
  extraPortionsGroupRequired:
      json['extraPortionsGroupRequired'] as bool? ?? false,
  extraPortionsGroupMaxSelectable:
      (json['extraPortionsGroupMaxSelectable'] as num?)?.toInt() ?? 0,
  extraPortionsAllowWithout: json['extraPortionsAllowWithout'] as bool? ?? true,
);

Map<String, dynamic> _$PublicMenuItemToJson(
  _PublicMenuItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'price': instance.price,
  'image': instance.image,
  'sauces': instance.sauces,
  'sauceGroupRequired': instance.sauceGroupRequired,
  'sauceGroupMaxSelectable': instance.sauceGroupMaxSelectable,
  'sauceAllowWithout': instance.sauceAllowWithout,
  'beverages': instance.beverages,
  'beverageGroupRequired': instance.beverageGroupRequired,
  'beverageGroupMaxSelectable': instance.beverageGroupMaxSelectable,
  'beverageAllowWithout': instance.beverageAllowWithout,
  'extraPortions': instance.extraPortions,
  'extraPortionsGroupRequired': instance.extraPortionsGroupRequired,
  'extraPortionsGroupMaxSelectable': instance.extraPortionsGroupMaxSelectable,
  'extraPortionsAllowWithout': instance.extraPortionsAllowWithout,
};
