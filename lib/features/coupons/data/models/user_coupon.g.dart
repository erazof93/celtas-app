// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_coupon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserCoupon _$UserCouponFromJson(Map<String, dynamic> json) => _UserCoupon(
  id: json['id'] as String,
  code: json['code'] as String,
  discountType: $enumDecode(_$CouponDiscountTypeEnumMap, json['discountType']),
  discountValue: (json['discountValue'] as num).toDouble(),
  status: $enumDecode(_$CouponStatusEnumMap, json['status']),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  usedAt: json['usedAt'] == null
      ? null
      : DateTime.parse(json['usedAt'] as String),
);

Map<String, dynamic> _$UserCouponToJson(_UserCoupon instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'discountType': _$CouponDiscountTypeEnumMap[instance.discountType]!,
      'discountValue': instance.discountValue,
      'status': _$CouponStatusEnumMap[instance.status]!,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'usedAt': instance.usedAt?.toIso8601String(),
    };

const _$CouponDiscountTypeEnumMap = {
  CouponDiscountType.percentage: 'percentage',
  CouponDiscountType.fixedAmount: 'fixed_amount',
};

const _$CouponStatusEnumMap = {
  CouponStatus.active: 'active',
  CouponStatus.used: 'used',
  CouponStatus.expired: 'expired',
};
