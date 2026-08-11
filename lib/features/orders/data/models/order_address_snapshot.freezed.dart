// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_address_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrderAddressSnapshot {

 String get alias; String get fullAddress; String? get reference; String get district;
/// Create a copy of OrderAddressSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderAddressSnapshotCopyWith<OrderAddressSnapshot> get copyWith => _$OrderAddressSnapshotCopyWithImpl<OrderAddressSnapshot>(this as OrderAddressSnapshot, _$identity);

  /// Serializes this OrderAddressSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderAddressSnapshot&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.fullAddress, fullAddress) || other.fullAddress == fullAddress)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.district, district) || other.district == district));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alias,fullAddress,reference,district);

@override
String toString() {
  return 'OrderAddressSnapshot(alias: $alias, fullAddress: $fullAddress, reference: $reference, district: $district)';
}


}

/// @nodoc
abstract mixin class $OrderAddressSnapshotCopyWith<$Res>  {
  factory $OrderAddressSnapshotCopyWith(OrderAddressSnapshot value, $Res Function(OrderAddressSnapshot) _then) = _$OrderAddressSnapshotCopyWithImpl;
@useResult
$Res call({
 String alias, String fullAddress, String? reference, String district
});




}
/// @nodoc
class _$OrderAddressSnapshotCopyWithImpl<$Res>
    implements $OrderAddressSnapshotCopyWith<$Res> {
  _$OrderAddressSnapshotCopyWithImpl(this._self, this._then);

  final OrderAddressSnapshot _self;
  final $Res Function(OrderAddressSnapshot) _then;

/// Create a copy of OrderAddressSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? alias = null,Object? fullAddress = null,Object? reference = freezed,Object? district = null,}) {
  return _then(_self.copyWith(
alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,fullAddress: null == fullAddress ? _self.fullAddress : fullAddress // ignore: cast_nullable_to_non_nullable
as String,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderAddressSnapshot].
extension OrderAddressSnapshotPatterns on OrderAddressSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderAddressSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderAddressSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderAddressSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _OrderAddressSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderAddressSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _OrderAddressSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String alias,  String fullAddress,  String? reference,  String district)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderAddressSnapshot() when $default != null:
return $default(_that.alias,_that.fullAddress,_that.reference,_that.district);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String alias,  String fullAddress,  String? reference,  String district)  $default,) {final _that = this;
switch (_that) {
case _OrderAddressSnapshot():
return $default(_that.alias,_that.fullAddress,_that.reference,_that.district);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String alias,  String fullAddress,  String? reference,  String district)?  $default,) {final _that = this;
switch (_that) {
case _OrderAddressSnapshot() when $default != null:
return $default(_that.alias,_that.fullAddress,_that.reference,_that.district);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderAddressSnapshot implements OrderAddressSnapshot {
  const _OrderAddressSnapshot({required this.alias, required this.fullAddress, this.reference, required this.district});
  factory _OrderAddressSnapshot.fromJson(Map<String, dynamic> json) => _$OrderAddressSnapshotFromJson(json);

@override final  String alias;
@override final  String fullAddress;
@override final  String? reference;
@override final  String district;

/// Create a copy of OrderAddressSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderAddressSnapshotCopyWith<_OrderAddressSnapshot> get copyWith => __$OrderAddressSnapshotCopyWithImpl<_OrderAddressSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderAddressSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderAddressSnapshot&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.fullAddress, fullAddress) || other.fullAddress == fullAddress)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.district, district) || other.district == district));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alias,fullAddress,reference,district);

@override
String toString() {
  return 'OrderAddressSnapshot(alias: $alias, fullAddress: $fullAddress, reference: $reference, district: $district)';
}


}

/// @nodoc
abstract mixin class _$OrderAddressSnapshotCopyWith<$Res> implements $OrderAddressSnapshotCopyWith<$Res> {
  factory _$OrderAddressSnapshotCopyWith(_OrderAddressSnapshot value, $Res Function(_OrderAddressSnapshot) _then) = __$OrderAddressSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String alias, String fullAddress, String? reference, String district
});




}
/// @nodoc
class __$OrderAddressSnapshotCopyWithImpl<$Res>
    implements _$OrderAddressSnapshotCopyWith<$Res> {
  __$OrderAddressSnapshotCopyWithImpl(this._self, this._then);

  final _OrderAddressSnapshot _self;
  final $Res Function(_OrderAddressSnapshot) _then;

/// Create a copy of OrderAddressSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? alias = null,Object? fullAddress = null,Object? reference = freezed,Object? district = null,}) {
  return _then(_OrderAddressSnapshot(
alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,fullAddress: null == fullAddress ? _self.fullAddress : fullAddress // ignore: cast_nullable_to_non_nullable
as String,reference: freezed == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String?,district: null == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
