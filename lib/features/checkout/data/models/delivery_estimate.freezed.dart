// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery_estimate.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeliveryZone {

 String get id; String get name;
/// Create a copy of DeliveryZone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryZoneCopyWith<DeliveryZone> get copyWith => _$DeliveryZoneCopyWithImpl<DeliveryZone>(this as DeliveryZone, _$identity);

  /// Serializes this DeliveryZone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryZone&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'DeliveryZone(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $DeliveryZoneCopyWith<$Res>  {
  factory $DeliveryZoneCopyWith(DeliveryZone value, $Res Function(DeliveryZone) _then) = _$DeliveryZoneCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$DeliveryZoneCopyWithImpl<$Res>
    implements $DeliveryZoneCopyWith<$Res> {
  _$DeliveryZoneCopyWithImpl(this._self, this._then);

  final DeliveryZone _self;
  final $Res Function(DeliveryZone) _then;

/// Create a copy of DeliveryZone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliveryZone].
extension DeliveryZonePatterns on DeliveryZone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryZone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryZone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryZone value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryZone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryZone value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryZone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryZone() when $default != null:
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name)  $default,) {final _that = this;
switch (_that) {
case _DeliveryZone():
return $default(_that.id,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryZone() when $default != null:
return $default(_that.id,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryZone implements DeliveryZone {
  const _DeliveryZone({required this.id, required this.name});
  factory _DeliveryZone.fromJson(Map<String, dynamic> json) => _$DeliveryZoneFromJson(json);

@override final  String id;
@override final  String name;

/// Create a copy of DeliveryZone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryZoneCopyWith<_DeliveryZone> get copyWith => __$DeliveryZoneCopyWithImpl<_DeliveryZone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryZoneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryZone&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'DeliveryZone(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class _$DeliveryZoneCopyWith<$Res> implements $DeliveryZoneCopyWith<$Res> {
  factory _$DeliveryZoneCopyWith(_DeliveryZone value, $Res Function(_DeliveryZone) _then) = __$DeliveryZoneCopyWithImpl;
@override @useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class __$DeliveryZoneCopyWithImpl<$Res>
    implements _$DeliveryZoneCopyWith<$Res> {
  __$DeliveryZoneCopyWithImpl(this._self, this._then);

  final _DeliveryZone _self;
  final $Res Function(_DeliveryZone) _then;

/// Create a copy of DeliveryZone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(_DeliveryZone(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeliveryEstimate {

 double get deliveryFee; bool get isFarOrder;@JsonKey(required: true) double? get distanceMeters; bool get isCovered; DeliveryMode get deliveryMode;@JsonKey(required: true) DeliveryZone? get zone;
/// Create a copy of DeliveryEstimate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryEstimateCopyWith<DeliveryEstimate> get copyWith => _$DeliveryEstimateCopyWithImpl<DeliveryEstimate>(this as DeliveryEstimate, _$identity);

  /// Serializes this DeliveryEstimate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryEstimate&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.isFarOrder, isFarOrder) || other.isFarOrder == isFarOrder)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.isCovered, isCovered) || other.isCovered == isCovered)&&(identical(other.deliveryMode, deliveryMode) || other.deliveryMode == deliveryMode)&&(identical(other.zone, zone) || other.zone == zone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deliveryFee,isFarOrder,distanceMeters,isCovered,deliveryMode,zone);

@override
String toString() {
  return 'DeliveryEstimate(deliveryFee: $deliveryFee, isFarOrder: $isFarOrder, distanceMeters: $distanceMeters, isCovered: $isCovered, deliveryMode: $deliveryMode, zone: $zone)';
}


}

/// @nodoc
abstract mixin class $DeliveryEstimateCopyWith<$Res>  {
  factory $DeliveryEstimateCopyWith(DeliveryEstimate value, $Res Function(DeliveryEstimate) _then) = _$DeliveryEstimateCopyWithImpl;
@useResult
$Res call({
 double deliveryFee, bool isFarOrder,@JsonKey(required: true) double? distanceMeters, bool isCovered, DeliveryMode deliveryMode,@JsonKey(required: true) DeliveryZone? zone
});


$DeliveryZoneCopyWith<$Res>? get zone;

}
/// @nodoc
class _$DeliveryEstimateCopyWithImpl<$Res>
    implements $DeliveryEstimateCopyWith<$Res> {
  _$DeliveryEstimateCopyWithImpl(this._self, this._then);

  final DeliveryEstimate _self;
  final $Res Function(DeliveryEstimate) _then;

/// Create a copy of DeliveryEstimate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deliveryFee = null,Object? isFarOrder = null,Object? distanceMeters = freezed,Object? isCovered = null,Object? deliveryMode = null,Object? zone = freezed,}) {
  return _then(_self.copyWith(
deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double,isFarOrder: null == isFarOrder ? _self.isFarOrder : isFarOrder // ignore: cast_nullable_to_non_nullable
as bool,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double?,isCovered: null == isCovered ? _self.isCovered : isCovered // ignore: cast_nullable_to_non_nullable
as bool,deliveryMode: null == deliveryMode ? _self.deliveryMode : deliveryMode // ignore: cast_nullable_to_non_nullable
as DeliveryMode,zone: freezed == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as DeliveryZone?,
  ));
}
/// Create a copy of DeliveryEstimate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliveryZoneCopyWith<$Res>? get zone {
    if (_self.zone == null) {
    return null;
  }

  return $DeliveryZoneCopyWith<$Res>(_self.zone!, (value) {
    return _then(_self.copyWith(zone: value));
  });
}
}


/// Adds pattern-matching-related methods to [DeliveryEstimate].
extension DeliveryEstimatePatterns on DeliveryEstimate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryEstimate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryEstimate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryEstimate value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryEstimate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryEstimate value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryEstimate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double deliveryFee,  bool isFarOrder, @JsonKey(required: true)  double? distanceMeters,  bool isCovered,  DeliveryMode deliveryMode, @JsonKey(required: true)  DeliveryZone? zone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryEstimate() when $default != null:
return $default(_that.deliveryFee,_that.isFarOrder,_that.distanceMeters,_that.isCovered,_that.deliveryMode,_that.zone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double deliveryFee,  bool isFarOrder, @JsonKey(required: true)  double? distanceMeters,  bool isCovered,  DeliveryMode deliveryMode, @JsonKey(required: true)  DeliveryZone? zone)  $default,) {final _that = this;
switch (_that) {
case _DeliveryEstimate():
return $default(_that.deliveryFee,_that.isFarOrder,_that.distanceMeters,_that.isCovered,_that.deliveryMode,_that.zone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double deliveryFee,  bool isFarOrder, @JsonKey(required: true)  double? distanceMeters,  bool isCovered,  DeliveryMode deliveryMode, @JsonKey(required: true)  DeliveryZone? zone)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryEstimate() when $default != null:
return $default(_that.deliveryFee,_that.isFarOrder,_that.distanceMeters,_that.isCovered,_that.deliveryMode,_that.zone);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _DeliveryEstimate implements DeliveryEstimate {
  const _DeliveryEstimate({required this.deliveryFee, required this.isFarOrder, @JsonKey(required: true) required this.distanceMeters, required this.isCovered, required this.deliveryMode, @JsonKey(required: true) required this.zone});
  factory _DeliveryEstimate.fromJson(Map<String, dynamic> json) => _$DeliveryEstimateFromJson(json);

@override final  double deliveryFee;
@override final  bool isFarOrder;
@override@JsonKey(required: true) final  double? distanceMeters;
@override final  bool isCovered;
@override final  DeliveryMode deliveryMode;
@override@JsonKey(required: true) final  DeliveryZone? zone;

/// Create a copy of DeliveryEstimate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryEstimateCopyWith<_DeliveryEstimate> get copyWith => __$DeliveryEstimateCopyWithImpl<_DeliveryEstimate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryEstimateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryEstimate&&(identical(other.deliveryFee, deliveryFee) || other.deliveryFee == deliveryFee)&&(identical(other.isFarOrder, isFarOrder) || other.isFarOrder == isFarOrder)&&(identical(other.distanceMeters, distanceMeters) || other.distanceMeters == distanceMeters)&&(identical(other.isCovered, isCovered) || other.isCovered == isCovered)&&(identical(other.deliveryMode, deliveryMode) || other.deliveryMode == deliveryMode)&&(identical(other.zone, zone) || other.zone == zone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deliveryFee,isFarOrder,distanceMeters,isCovered,deliveryMode,zone);

@override
String toString() {
  return 'DeliveryEstimate(deliveryFee: $deliveryFee, isFarOrder: $isFarOrder, distanceMeters: $distanceMeters, isCovered: $isCovered, deliveryMode: $deliveryMode, zone: $zone)';
}


}

/// @nodoc
abstract mixin class _$DeliveryEstimateCopyWith<$Res> implements $DeliveryEstimateCopyWith<$Res> {
  factory _$DeliveryEstimateCopyWith(_DeliveryEstimate value, $Res Function(_DeliveryEstimate) _then) = __$DeliveryEstimateCopyWithImpl;
@override @useResult
$Res call({
 double deliveryFee, bool isFarOrder,@JsonKey(required: true) double? distanceMeters, bool isCovered, DeliveryMode deliveryMode,@JsonKey(required: true) DeliveryZone? zone
});


@override $DeliveryZoneCopyWith<$Res>? get zone;

}
/// @nodoc
class __$DeliveryEstimateCopyWithImpl<$Res>
    implements _$DeliveryEstimateCopyWith<$Res> {
  __$DeliveryEstimateCopyWithImpl(this._self, this._then);

  final _DeliveryEstimate _self;
  final $Res Function(_DeliveryEstimate) _then;

/// Create a copy of DeliveryEstimate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deliveryFee = null,Object? isFarOrder = null,Object? distanceMeters = freezed,Object? isCovered = null,Object? deliveryMode = null,Object? zone = freezed,}) {
  return _then(_DeliveryEstimate(
deliveryFee: null == deliveryFee ? _self.deliveryFee : deliveryFee // ignore: cast_nullable_to_non_nullable
as double,isFarOrder: null == isFarOrder ? _self.isFarOrder : isFarOrder // ignore: cast_nullable_to_non_nullable
as bool,distanceMeters: freezed == distanceMeters ? _self.distanceMeters : distanceMeters // ignore: cast_nullable_to_non_nullable
as double?,isCovered: null == isCovered ? _self.isCovered : isCovered // ignore: cast_nullable_to_non_nullable
as bool,deliveryMode: null == deliveryMode ? _self.deliveryMode : deliveryMode // ignore: cast_nullable_to_non_nullable
as DeliveryMode,zone: freezed == zone ? _self.zone : zone // ignore: cast_nullable_to_non_nullable
as DeliveryZone?,
  ));
}

/// Create a copy of DeliveryEstimate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliveryZoneCopyWith<$Res>? get zone {
    if (_self.zone == null) {
    return null;
  }

  return $DeliveryZoneCopyWith<$Res>(_self.zone!, (value) {
    return _then(_self.copyWith(zone: value));
  });
}
}

// dart format on
