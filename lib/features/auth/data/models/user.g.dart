// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  email: json['email'] as String,
  fullName: json['fullName'] as String,
  provider: $enumDecode(_$UserProviderEnumMap, json['provider']),
  googleId: json['googleId'] as String?,
  phone: json['phone'] as String?,
  fcmToken: json['fcmToken'] as String?,
  totalSpent: (json['totalSpent'] as num).toDouble(),
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'fullName': instance.fullName,
  'provider': _$UserProviderEnumMap[instance.provider]!,
  'googleId': instance.googleId,
  'phone': instance.phone,
  'fcmToken': instance.fcmToken,
  'totalSpent': instance.totalSpent,
  'role': _$UserRoleEnumMap[instance.role]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$UserProviderEnumMap = {
  UserProvider.local: 'local',
  UserProvider.google: 'google',
};

const _$UserRoleEnumMap = {
  UserRole.cliente: 'cliente',
  UserRole.admin: 'admin',
};
