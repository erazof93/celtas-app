// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Order _$OrderFromJson(Map<String, dynamic> json) => _Order(
  id: json['id'] as String,
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  addressSnapshot: json['addressSnapshot'] as String,
  total: (json['total'] as num).toDouble(),
  whatsappUrl: json['whatsappUrl'] as String,
  deliveredAt: json['deliveredAt'] == null
      ? null
      : DateTime.parse(json['deliveredAt'] as String),
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$OrderToJson(_Order instance) => <String, dynamic>{
  'id': instance.id,
  'status': _$OrderStatusEnumMap[instance.status]!,
  'addressSnapshot': instance.addressSnapshot,
  'total': instance.total,
  'whatsappUrl': instance.whatsappUrl,
  'deliveredAt': instance.deliveredAt?.toIso8601String(),
  'items': instance.items,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$OrderStatusEnumMap = {
  OrderStatus.pendiente: 'pendiente',
  OrderStatus.confirmado: 'confirmado',
  OrderStatus.enCamino: 'en_camino',
  OrderStatus.entregado: 'entregado',
  OrderStatus.cancelado: 'cancelado',
};
