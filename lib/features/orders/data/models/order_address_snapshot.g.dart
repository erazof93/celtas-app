// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_address_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrderAddressSnapshot _$OrderAddressSnapshotFromJson(
  Map<String, dynamic> json,
) => _OrderAddressSnapshot(
  alias: json['alias'] as String,
  fullAddress: json['fullAddress'] as String,
  reference: json['reference'] as String?,
  district: json['district'] as String,
);

Map<String, dynamic> _$OrderAddressSnapshotToJson(
  _OrderAddressSnapshot instance,
) => <String, dynamic>{
  'alias': instance.alias,
  'fullAddress': instance.fullAddress,
  'reference': instance.reference,
  'district': instance.district,
};
