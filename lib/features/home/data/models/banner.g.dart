// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Banner _$BannerFromJson(Map<String, dynamic> json) => _Banner(
  id: json['id'] as String,
  title: json['title'] as String,
  imageUrl: json['imageUrl'] as String?,
  actionType: $enumDecode(_$BannerActionTypeEnumMap, json['actionType']),
  actionValue: json['actionValue'] as String?,
  startDate: json['startDate'] == null
      ? null
      : DateTime.parse(json['startDate'] as String),
  endDate: json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String),
  active: json['active'] as bool,
  order: (json['order'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$BannerToJson(_Banner instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'imageUrl': instance.imageUrl,
  'actionType': _$BannerActionTypeEnumMap[instance.actionType]!,
  'actionValue': instance.actionValue,
  'startDate': instance.startDate?.toIso8601String(),
  'endDate': instance.endDate?.toIso8601String(),
  'active': instance.active,
  'order': instance.order,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$BannerActionTypeEnumMap = {
  BannerActionType.none: 'none',
  BannerActionType.category: 'category',
  BannerActionType.menuItem: 'menuItem',
  BannerActionType.externalUrl: 'external_url',
};
