// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extra_portion_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExtraPortionOption _$ExtraPortionOptionFromJson(Map<String, dynamic> json) =>
    _ExtraPortionOption(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );

Map<String, dynamic> _$ExtraPortionOptionToJson(_ExtraPortionOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
    };
