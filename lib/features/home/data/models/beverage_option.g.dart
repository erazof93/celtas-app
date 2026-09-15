// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'beverage_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BeverageOption _$BeverageOptionFromJson(Map<String, dynamic> json) =>
    _BeverageOption(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );

Map<String, dynamic> _$BeverageOptionToJson(_BeverageOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
    };
