// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrderResult _$OrderResultFromJson(Map<String, dynamic> json) => _OrderResult(
  id: json['id'] as String,
  total: (json['total'] as num).toDouble(),
  whatsappUrl: json['whatsappUrl'] as String,
);

Map<String, dynamic> _$OrderResultToJson(_OrderResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'total': instance.total,
      'whatsappUrl': instance.whatsappUrl,
    };
