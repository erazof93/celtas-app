// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_coupon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserCoupon {

 String get id; String get code; CouponDiscountType get discountType; double get discountValue; CouponStatus get status; DateTime get expiresAt; DateTime? get usedAt;// Monto mínimo de compra del cupón (`Coupon.minPurchaseAmount` en el
// backend: decimal nullable). `0` se trata igual que `null` ("sin
// mínimo") — mismo criterio ya aplicado en el panel admin.
 double? get minPurchaseAmount;
/// Create a copy of UserCoupon
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCouponCopyWith<UserCoupon> get copyWith => _$UserCouponCopyWithImpl<UserCoupon>(this as UserCoupon, _$identity);

  /// Serializes this UserCoupon to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserCoupon&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.discountValue, discountValue) || other.discountValue == discountValue)&&(identical(other.status, status) || other.status == status)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.usedAt, usedAt) || other.usedAt == usedAt)&&(identical(other.minPurchaseAmount, minPurchaseAmount) || other.minPurchaseAmount == minPurchaseAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,discountType,discountValue,status,expiresAt,usedAt,minPurchaseAmount);

@override
String toString() {
  return 'UserCoupon(id: $id, code: $code, discountType: $discountType, discountValue: $discountValue, status: $status, expiresAt: $expiresAt, usedAt: $usedAt, minPurchaseAmount: $minPurchaseAmount)';
}


}

/// @nodoc
abstract mixin class $UserCouponCopyWith<$Res>  {
  factory $UserCouponCopyWith(UserCoupon value, $Res Function(UserCoupon) _then) = _$UserCouponCopyWithImpl;
@useResult
$Res call({
 String id, String code, CouponDiscountType discountType, double discountValue, CouponStatus status, DateTime expiresAt, DateTime? usedAt, double? minPurchaseAmount
});




}
/// @nodoc
class _$UserCouponCopyWithImpl<$Res>
    implements $UserCouponCopyWith<$Res> {
  _$UserCouponCopyWithImpl(this._self, this._then);

  final UserCoupon _self;
  final $Res Function(UserCoupon) _then;

/// Create a copy of UserCoupon
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? discountType = null,Object? discountValue = null,Object? status = null,Object? expiresAt = null,Object? usedAt = freezed,Object? minPurchaseAmount = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,discountType: null == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as CouponDiscountType,discountValue: null == discountValue ? _self.discountValue : discountValue // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CouponStatus,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,usedAt: freezed == usedAt ? _self.usedAt : usedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,minPurchaseAmount: freezed == minPurchaseAmount ? _self.minPurchaseAmount : minPurchaseAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserCoupon].
extension UserCouponPatterns on UserCoupon {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserCoupon value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserCoupon() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserCoupon value)  $default,){
final _that = this;
switch (_that) {
case _UserCoupon():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserCoupon value)?  $default,){
final _that = this;
switch (_that) {
case _UserCoupon() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code,  CouponDiscountType discountType,  double discountValue,  CouponStatus status,  DateTime expiresAt,  DateTime? usedAt,  double? minPurchaseAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserCoupon() when $default != null:
return $default(_that.id,_that.code,_that.discountType,_that.discountValue,_that.status,_that.expiresAt,_that.usedAt,_that.minPurchaseAmount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code,  CouponDiscountType discountType,  double discountValue,  CouponStatus status,  DateTime expiresAt,  DateTime? usedAt,  double? minPurchaseAmount)  $default,) {final _that = this;
switch (_that) {
case _UserCoupon():
return $default(_that.id,_that.code,_that.discountType,_that.discountValue,_that.status,_that.expiresAt,_that.usedAt,_that.minPurchaseAmount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code,  CouponDiscountType discountType,  double discountValue,  CouponStatus status,  DateTime expiresAt,  DateTime? usedAt,  double? minPurchaseAmount)?  $default,) {final _that = this;
switch (_that) {
case _UserCoupon() when $default != null:
return $default(_that.id,_that.code,_that.discountType,_that.discountValue,_that.status,_that.expiresAt,_that.usedAt,_that.minPurchaseAmount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserCoupon extends UserCoupon {
  const _UserCoupon({required this.id, required this.code, required this.discountType, required this.discountValue, required this.status, required this.expiresAt, this.usedAt, this.minPurchaseAmount}): super._();
  factory _UserCoupon.fromJson(Map<String, dynamic> json) => _$UserCouponFromJson(json);

@override final  String id;
@override final  String code;
@override final  CouponDiscountType discountType;
@override final  double discountValue;
@override final  CouponStatus status;
@override final  DateTime expiresAt;
@override final  DateTime? usedAt;
// Monto mínimo de compra del cupón (`Coupon.minPurchaseAmount` en el
// backend: decimal nullable). `0` se trata igual que `null` ("sin
// mínimo") — mismo criterio ya aplicado en el panel admin.
@override final  double? minPurchaseAmount;

/// Create a copy of UserCoupon
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCouponCopyWith<_UserCoupon> get copyWith => __$UserCouponCopyWithImpl<_UserCoupon>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserCouponToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserCoupon&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.discountValue, discountValue) || other.discountValue == discountValue)&&(identical(other.status, status) || other.status == status)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.usedAt, usedAt) || other.usedAt == usedAt)&&(identical(other.minPurchaseAmount, minPurchaseAmount) || other.minPurchaseAmount == minPurchaseAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,discountType,discountValue,status,expiresAt,usedAt,minPurchaseAmount);

@override
String toString() {
  return 'UserCoupon(id: $id, code: $code, discountType: $discountType, discountValue: $discountValue, status: $status, expiresAt: $expiresAt, usedAt: $usedAt, minPurchaseAmount: $minPurchaseAmount)';
}


}

/// @nodoc
abstract mixin class _$UserCouponCopyWith<$Res> implements $UserCouponCopyWith<$Res> {
  factory _$UserCouponCopyWith(_UserCoupon value, $Res Function(_UserCoupon) _then) = __$UserCouponCopyWithImpl;
@override @useResult
$Res call({
 String id, String code, CouponDiscountType discountType, double discountValue, CouponStatus status, DateTime expiresAt, DateTime? usedAt, double? minPurchaseAmount
});




}
/// @nodoc
class __$UserCouponCopyWithImpl<$Res>
    implements _$UserCouponCopyWith<$Res> {
  __$UserCouponCopyWithImpl(this._self, this._then);

  final _UserCoupon _self;
  final $Res Function(_UserCoupon) _then;

/// Create a copy of UserCoupon
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? discountType = null,Object? discountValue = null,Object? status = null,Object? expiresAt = null,Object? usedAt = freezed,Object? minPurchaseAmount = freezed,}) {
  return _then(_UserCoupon(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,discountType: null == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as CouponDiscountType,discountValue: null == discountValue ? _self.discountValue : discountValue // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CouponStatus,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,usedAt: freezed == usedAt ? _self.usedAt : usedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,minPurchaseAmount: freezed == minPurchaseAmount ? _self.minPurchaseAmount : minPurchaseAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
