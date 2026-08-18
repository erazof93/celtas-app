// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_hours.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BusinessHours _$BusinessHoursFromJson(Map<String, dynamic> json) =>
    _BusinessHours(
      open: json['open'] as bool,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$BusinessHoursToJson(_BusinessHours instance) =>
    <String, dynamic>{'open': instance.open, 'message': instance.message};
