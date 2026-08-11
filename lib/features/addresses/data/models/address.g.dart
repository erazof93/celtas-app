// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Address _$AddressFromJson(Map<String, dynamic> json) => _Address(
  id: json['id'] as String,
  alias: json['alias'] as String,
  fullAddress: json['fullAddress'] as String,
  reference: json['reference'] as String?,
  district: json['district'] as String,
  isDefault: json['isDefault'] as bool? ?? false,
);

Map<String, dynamic> _$AddressToJson(_Address instance) => <String, dynamic>{
  'id': instance.id,
  'alias': instance.alias,
  'fullAddress': instance.fullAddress,
  'reference': instance.reference,
  'district': instance.district,
  'isDefault': instance.isDefault,
};
