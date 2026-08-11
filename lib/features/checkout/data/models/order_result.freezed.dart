// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrderResult {

 String get id; double get total; String get whatsappUrl;
/// Create a copy of OrderResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrderResultCopyWith<OrderResult> get copyWith => _$OrderResultCopyWithImpl<OrderResult>(this as OrderResult, _$identity);

  /// Serializes this OrderResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrderResult&&(identical(other.id, id) || other.id == id)&&(identical(other.total, total) || other.total == total)&&(identical(other.whatsappUrl, whatsappUrl) || other.whatsappUrl == whatsappUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,total,whatsappUrl);

@override
String toString() {
  return 'OrderResult(id: $id, total: $total, whatsappUrl: $whatsappUrl)';
}


}

/// @nodoc
abstract mixin class $OrderResultCopyWith<$Res>  {
  factory $OrderResultCopyWith(OrderResult value, $Res Function(OrderResult) _then) = _$OrderResultCopyWithImpl;
@useResult
$Res call({
 String id, double total, String whatsappUrl
});




}
/// @nodoc
class _$OrderResultCopyWithImpl<$Res>
    implements $OrderResultCopyWith<$Res> {
  _$OrderResultCopyWithImpl(this._self, this._then);

  final OrderResult _self;
  final $Res Function(OrderResult) _then;

/// Create a copy of OrderResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? total = null,Object? whatsappUrl = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,whatsappUrl: null == whatsappUrl ? _self.whatsappUrl : whatsappUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OrderResult].
extension OrderResultPatterns on OrderResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrderResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrderResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrderResult value)  $default,){
final _that = this;
switch (_that) {
case _OrderResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrderResult value)?  $default,){
final _that = this;
switch (_that) {
case _OrderResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  double total,  String whatsappUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrderResult() when $default != null:
return $default(_that.id,_that.total,_that.whatsappUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  double total,  String whatsappUrl)  $default,) {final _that = this;
switch (_that) {
case _OrderResult():
return $default(_that.id,_that.total,_that.whatsappUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  double total,  String whatsappUrl)?  $default,) {final _that = this;
switch (_that) {
case _OrderResult() when $default != null:
return $default(_that.id,_that.total,_that.whatsappUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrderResult implements OrderResult {
  const _OrderResult({required this.id, required this.total, required this.whatsappUrl});
  factory _OrderResult.fromJson(Map<String, dynamic> json) => _$OrderResultFromJson(json);

@override final  String id;
@override final  double total;
@override final  String whatsappUrl;

/// Create a copy of OrderResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrderResultCopyWith<_OrderResult> get copyWith => __$OrderResultCopyWithImpl<_OrderResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrderResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderResult&&(identical(other.id, id) || other.id == id)&&(identical(other.total, total) || other.total == total)&&(identical(other.whatsappUrl, whatsappUrl) || other.whatsappUrl == whatsappUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,total,whatsappUrl);

@override
String toString() {
  return 'OrderResult(id: $id, total: $total, whatsappUrl: $whatsappUrl)';
}


}

/// @nodoc
abstract mixin class _$OrderResultCopyWith<$Res> implements $OrderResultCopyWith<$Res> {
  factory _$OrderResultCopyWith(_OrderResult value, $Res Function(_OrderResult) _then) = __$OrderResultCopyWithImpl;
@override @useResult
$Res call({
 String id, double total, String whatsappUrl
});




}
/// @nodoc
class __$OrderResultCopyWithImpl<$Res>
    implements _$OrderResultCopyWith<$Res> {
  __$OrderResultCopyWithImpl(this._self, this._then);

  final _OrderResult _self;
  final $Res Function(_OrderResult) _then;

/// Create a copy of OrderResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? total = null,Object? whatsappUrl = null,}) {
  return _then(_OrderResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,whatsappUrl: null == whatsappUrl ? _self.whatsappUrl : whatsappUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
