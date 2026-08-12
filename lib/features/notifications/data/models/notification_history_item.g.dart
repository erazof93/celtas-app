// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_history_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationHistoryItem _$NotificationHistoryItemFromJson(
  Map<String, dynamic> json,
) => _NotificationHistoryItem(
  title: json['title'] as String,
  body: json['body'] as String,
  receivedAt: DateTime.parse(json['receivedAt'] as String),
  data: json['data'] as Map<String, dynamic>,
);

Map<String, dynamic> _$NotificationHistoryItemToJson(
  _NotificationHistoryItem instance,
) => <String, dynamic>{
  'title': instance.title,
  'body': instance.body,
  'receivedAt': instance.receivedAt.toIso8601String(),
  'data': instance.data,
};
