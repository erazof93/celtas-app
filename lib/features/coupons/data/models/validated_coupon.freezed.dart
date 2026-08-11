// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'validated_coupon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ValidatedCoupon {

 bool get valid; String get id; String get code; CouponDiscountType get discountType; double get discountValue; String get description; DateTime? get expiresAt;
/// Create a copy of ValidatedCoupon
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ValidatedCouponCopyWith<ValidatedCoupon> get copyWith => _$ValidatedCouponCopyWithImpl<ValidatedCoupon>(this as ValidatedCoupon, _$identity);

  /// Serializes this ValidatedCoupon to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ValidatedCoupon&&(identical(other.valid, valid) || other.valid == valid)&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.discountValue, discountValue) || other.discountValue == discountValue)&&(identical(other.description, description) || other.description == description)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,valid,id,code,discountType,discountValue,description,expiresAt);

@override
String toString() {
  return 'ValidatedCoupon(valid: $valid, id: $id, code: $code, discountType: $discountType, discountValue: $discountValue, description: $description, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $ValidatedCouponCopyWith<$Res>  {
  factory $ValidatedCouponCopyWith(ValidatedCoupon value, $Res Function(ValidatedCoupon) _then) = _$ValidatedCouponCopyWithImpl;
@useResult
$Res call({
 bool valid, String id, String code, CouponDiscountType discountType, double discountValue, String description, DateTime? expiresAt
});




}
/// @nodoc
class _$ValidatedCouponCopyWithImpl<$Res>
    implements $ValidatedCouponCopyWith<$Res> {
  _$ValidatedCouponCopyWithImpl(this._self, this._then);

  final ValidatedCoupon _self;
  final $Res Function(ValidatedCoupon) _then;

/// Create a copy of ValidatedCoupon
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? valid = null,Object? id = null,Object? code = null,Object? discountType = null,Object? discountValue = null,Object? description = null,Object? expiresAt = freezed,}) {
  return _then(_self.copyWith(
valid: null == valid ? _self.valid : valid // ignore: cast_nullable_to_non_nullable
as bool,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,discountType: null == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as CouponDiscountType,discountValue: null == discountValue ? _self.discountValue : discountValue // ignore: cast_nullable_to_non_nullable
as double,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ValidatedCoupon].
extension ValidatedCouponPatterns on ValidatedCoupon {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ValidatedCoupon value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ValidatedCoupon() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ValidatedCoupon value)  $default,){
final _that = this;
switch (_that) {
case _ValidatedCoupon():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ValidatedCoupon value)?  $default,){
final _that = this;
switch (_that) {
case _ValidatedCoupon() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool valid,  String id,  String code,  CouponDiscountType discountType,  double discountValue,  String description,  DateTime? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ValidatedCoupon() when $default != null:
return $default(_that.valid,_that.id,_that.code,_that.discountType,_that.discountValue,_that.description,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool valid,  String id,  String code,  CouponDiscountType discountType,  double discountValue,  String description,  DateTime? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _ValidatedCoupon():
return $default(_that.valid,_that.id,_that.code,_that.discountType,_that.discountValue,_that.description,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool valid,  String id,  String code,  CouponDiscountType discountType,  double discountValue,  String description,  DateTime? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _ValidatedCoupon() when $default != null:
return $default(_that.valid,_that.id,_that.code,_that.discountType,_that.discountValue,_that.description,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ValidatedCoupon implements ValidatedCoupon {
  const _ValidatedCoupon({required this.valid, required this.id, required this.code, required this.discountType, required this.discountValue, required this.description, this.expiresAt});
  factory _ValidatedCoupon.fromJson(Map<String, dynamic> json) => _$ValidatedCouponFromJson(json);

@override final  bool valid;
@override final  String id;
@override final  String code;
@override final  CouponDiscountType discountType;
@override final  double discountValue;
@override final  String description;
@override final  DateTime? expiresAt;

/// Create a copy of ValidatedCoupon
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ValidatedCouponCopyWith<_ValidatedCoupon> get copyWith => __$ValidatedCouponCopyWithImpl<_ValidatedCoupon>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ValidatedCouponToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ValidatedCoupon&&(identical(other.valid, valid) || other.valid == valid)&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.discountType, discountType) || other.discountType == discountType)&&(identical(other.discountValue, discountValue) || other.discountValue == discountValue)&&(identical(other.description, description) || other.description == description)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,valid,id,code,discountType,discountValue,description,expiresAt);

@override
String toString() {
  return 'ValidatedCoupon(valid: $valid, id: $id, code: $code, discountType: $discountType, discountValue: $discountValue, description: $description, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$ValidatedCouponCopyWith<$Res> implements $ValidatedCouponCopyWith<$Res> {
  factory _$ValidatedCouponCopyWith(_ValidatedCoupon value, $Res Function(_ValidatedCoupon) _then) = __$ValidatedCouponCopyWithImpl;
@override @useResult
$Res call({
 bool valid, String id, String code, CouponDiscountType discountType, double discountValue, String description, DateTime? expiresAt
});




}
/// @nodoc
class __$ValidatedCouponCopyWithImpl<$Res>
    implements _$ValidatedCouponCopyWith<$Res> {
  __$ValidatedCouponCopyWithImpl(this._self, this._then);

  final _ValidatedCoupon _self;
  final $Res Function(_ValidatedCoupon) _then;

/// Create a copy of ValidatedCoupon
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? valid = null,Object? id = null,Object? code = null,Object? discountType = null,Object? discountValue = null,Object? description = null,Object? expiresAt = freezed,}) {
  return _then(_ValidatedCoupon(
valid: null == valid ? _self.valid : valid // ignore: cast_nullable_to_non_nullable
as bool,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,discountType: null == discountType ? _self.discountType : discountType // ignore: cast_nullable_to_non_nullable
as CouponDiscountType,discountValue: null == discountValue ? _self.discountValue : discountValue // ignore: cast_nullable_to_non_nullable
as double,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
