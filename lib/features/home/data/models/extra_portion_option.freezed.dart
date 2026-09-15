// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'extra_portion_option.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExtraPortionOption {

 String get id; String get name; double get price;
/// Create a copy of ExtraPortionOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExtraPortionOptionCopyWith<ExtraPortionOption> get copyWith => _$ExtraPortionOptionCopyWithImpl<ExtraPortionOption>(this as ExtraPortionOption, _$identity);

  /// Serializes this ExtraPortionOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExtraPortionOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,price);

@override
String toString() {
  return 'ExtraPortionOption(id: $id, name: $name, price: $price)';
}


}

/// @nodoc
abstract mixin class $ExtraPortionOptionCopyWith<$Res>  {
  factory $ExtraPortionOptionCopyWith(ExtraPortionOption value, $Res Function(ExtraPortionOption) _then) = _$ExtraPortionOptionCopyWithImpl;
@useResult
$Res call({
 String id, String name, double price
});




}
/// @nodoc
class _$ExtraPortionOptionCopyWithImpl<$Res>
    implements $ExtraPortionOptionCopyWith<$Res> {
  _$ExtraPortionOptionCopyWithImpl(this._self, this._then);

  final ExtraPortionOption _self;
  final $Res Function(ExtraPortionOption) _then;

/// Create a copy of ExtraPortionOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? price = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ExtraPortionOption].
extension ExtraPortionOptionPatterns on ExtraPortionOption {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExtraPortionOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExtraPortionOption() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExtraPortionOption value)  $default,){
final _that = this;
switch (_that) {
case _ExtraPortionOption():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExtraPortionOption value)?  $default,){
final _that = this;
switch (_that) {
case _ExtraPortionOption() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double price)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExtraPortionOption() when $default != null:
return $default(_that.id,_that.name,_that.price);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double price)  $default,) {final _that = this;
switch (_that) {
case _ExtraPortionOption():
return $default(_that.id,_that.name,_that.price);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double price)?  $default,) {final _that = this;
switch (_that) {
case _ExtraPortionOption() when $default != null:
return $default(_that.id,_that.name,_that.price);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExtraPortionOption implements ExtraPortionOption {
  const _ExtraPortionOption({required this.id, required this.name, required this.price});
  factory _ExtraPortionOption.fromJson(Map<String, dynamic> json) => _$ExtraPortionOptionFromJson(json);

@override final  String id;
@override final  String name;
@override final  double price;

/// Create a copy of ExtraPortionOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExtraPortionOptionCopyWith<_ExtraPortionOption> get copyWith => __$ExtraPortionOptionCopyWithImpl<_ExtraPortionOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExtraPortionOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExtraPortionOption&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,price);

@override
String toString() {
  return 'ExtraPortionOption(id: $id, name: $name, price: $price)';
}


}

/// @nodoc
abstract mixin class _$ExtraPortionOptionCopyWith<$Res> implements $ExtraPortionOptionCopyWith<$Res> {
  factory _$ExtraPortionOptionCopyWith(_ExtraPortionOption value, $Res Function(_ExtraPortionOption) _then) = __$ExtraPortionOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double price
});




}
/// @nodoc
class __$ExtraPortionOptionCopyWithImpl<$Res>
    implements _$ExtraPortionOptionCopyWith<$Res> {
  __$ExtraPortionOptionCopyWithImpl(this._self, this._then);

  final _ExtraPortionOption _self;
  final $Res Function(_ExtraPortionOption) _then;

/// Create a copy of ExtraPortionOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? price = null,}) {
  return _then(_ExtraPortionOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
