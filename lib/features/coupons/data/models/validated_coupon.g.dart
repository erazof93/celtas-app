// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validated_coupon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ValidatedCoupon _$ValidatedCouponFromJson(Map<String, dynamic> json) =>
    _ValidatedCoupon(
      valid: json['valid'] as bool,
      id: json['id'] as String,
      code: json['code'] as String,
      discountType: $enumDecode(
        _$CouponDiscountTypeEnumMap,
        json['discountType'],
      ),
      discountValue: (json['discountValue'] as num).toDouble(),
      description: json['description'] as String,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$ValidatedCouponToJson(_ValidatedCoupon instance) =>
    <String, dynamic>{
      'valid': instance.valid,
      'id': instance.id,
      'code': instance.code,
      'discountType': _$CouponDiscountTypeEnumMap[instance.discountType]!,
      'discountValue': instance.discountValue,
      'description': instance.description,
      'expiresAt': instance.expiresAt?.toIso8601String(),
    };

const _$CouponDiscountTypeEnumMap = {
  CouponDiscountType.percentage: 'percentage',
  CouponDiscountType.fixedAmount: 'fixed_amount',
};
