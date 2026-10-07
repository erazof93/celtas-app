// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_estimate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeliveryZone _$DeliveryZoneFromJson(Map<String, dynamic> json) =>
    _DeliveryZone(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$DeliveryZoneToJson(_DeliveryZone instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_DeliveryEstimate _$DeliveryEstimateFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['distanceMeters', 'zone']);
  return _DeliveryEstimate(
    deliveryFee: (json['deliveryFee'] as num).toDouble(),
    isFarOrder: json['isFarOrder'] as bool,
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    isCovered: json['isCovered'] as bool,
    deliveryMode: $enumDecode(_$DeliveryModeEnumMap, json['deliveryMode']),
    zone: json['zone'] == null
        ? null
        : DeliveryZone.fromJson(json['zone'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$DeliveryEstimateToJson(_DeliveryEstimate instance) =>
    <String, dynamic>{
      'deliveryFee': instance.deliveryFee,
      'isFarOrder': instance.isFarOrder,
      'distanceMeters': instance.distanceMeters,
      'isCovered': instance.isCovered,
      'deliveryMode': _$DeliveryModeEnumMap[instance.deliveryMode]!,
      'zone': instance.zone?.toJson(),
    };

const _$DeliveryModeEnumMap = {
  DeliveryMode.distance: 'DISTANCE',
  DeliveryMode.zones: 'ZONES',
};
