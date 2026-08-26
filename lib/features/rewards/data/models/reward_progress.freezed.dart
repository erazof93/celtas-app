// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reward_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RewardSlot {

 String get id; DateTime get expiresAt;
/// Create a copy of RewardSlot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardSlotCopyWith<RewardSlot> get copyWith => _$RewardSlotCopyWithImpl<RewardSlot>(this as RewardSlot, _$identity);

  /// Serializes this RewardSlot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,expiresAt);

@override
String toString() {
  return 'RewardSlot(id: $id, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class $RewardSlotCopyWith<$Res>  {
  factory $RewardSlotCopyWith(RewardSlot value, $Res Function(RewardSlot) _then) = _$RewardSlotCopyWithImpl;
@useResult
$Res call({
 String id, DateTime expiresAt
});




}
/// @nodoc
class _$RewardSlotCopyWithImpl<$Res>
    implements $RewardSlotCopyWith<$Res> {
  _$RewardSlotCopyWithImpl(this._self, this._then);

  final RewardSlot _self;
  final $Res Function(RewardSlot) _then;

/// Create a copy of RewardSlot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? expiresAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardSlot].
extension RewardSlotPatterns on RewardSlot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardSlot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardSlot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardSlot value)  $default,){
final _that = this;
switch (_that) {
case _RewardSlot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardSlot value)?  $default,){
final _that = this;
switch (_that) {
case _RewardSlot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardSlot() when $default != null:
return $default(_that.id,_that.expiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime expiresAt)  $default,) {final _that = this;
switch (_that) {
case _RewardSlot():
return $default(_that.id,_that.expiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _RewardSlot() when $default != null:
return $default(_that.id,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RewardSlot implements RewardSlot {
  const _RewardSlot({required this.id, required this.expiresAt});
  factory _RewardSlot.fromJson(Map<String, dynamic> json) => _$RewardSlotFromJson(json);

@override final  String id;
@override final  DateTime expiresAt;

/// Create a copy of RewardSlot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardSlotCopyWith<_RewardSlot> get copyWith => __$RewardSlotCopyWithImpl<_RewardSlot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RewardSlotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,expiresAt);

@override
String toString() {
  return 'RewardSlot(id: $id, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$RewardSlotCopyWith<$Res> implements $RewardSlotCopyWith<$Res> {
  factory _$RewardSlotCopyWith(_RewardSlot value, $Res Function(_RewardSlot) _then) = __$RewardSlotCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime expiresAt
});




}
/// @nodoc
class __$RewardSlotCopyWithImpl<$Res>
    implements _$RewardSlotCopyWith<$Res> {
  __$RewardSlotCopyWithImpl(this._self, this._then);

  final _RewardSlot _self;
  final $Res Function(_RewardSlot) _then;

/// Create a copy of RewardSlot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? expiresAt = null,}) {
  return _then(_RewardSlot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$RewardPromotion {

 String get label; double get multiplier; String get endDate;
/// Create a copy of RewardPromotion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardPromotionCopyWith<RewardPromotion> get copyWith => _$RewardPromotionCopyWithImpl<RewardPromotion>(this as RewardPromotion, _$identity);

  /// Serializes this RewardPromotion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardPromotion&&(identical(other.label, label) || other.label == label)&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier)&&(identical(other.endDate, endDate) || other.endDate == endDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,multiplier,endDate);

@override
String toString() {
  return 'RewardPromotion(label: $label, multiplier: $multiplier, endDate: $endDate)';
}


}

/// @nodoc
abstract mixin class $RewardPromotionCopyWith<$Res>  {
  factory $RewardPromotionCopyWith(RewardPromotion value, $Res Function(RewardPromotion) _then) = _$RewardPromotionCopyWithImpl;
@useResult
$Res call({
 String label, double multiplier, String endDate
});




}
/// @nodoc
class _$RewardPromotionCopyWithImpl<$Res>
    implements $RewardPromotionCopyWith<$Res> {
  _$RewardPromotionCopyWithImpl(this._self, this._then);

  final RewardPromotion _self;
  final $Res Function(RewardPromotion) _then;

/// Create a copy of RewardPromotion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? multiplier = null,Object? endDate = null,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as double,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardPromotion].
extension RewardPromotionPatterns on RewardPromotion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardPromotion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardPromotion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardPromotion value)  $default,){
final _that = this;
switch (_that) {
case _RewardPromotion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardPromotion value)?  $default,){
final _that = this;
switch (_that) {
case _RewardPromotion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  double multiplier,  String endDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardPromotion() when $default != null:
return $default(_that.label,_that.multiplier,_that.endDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  double multiplier,  String endDate)  $default,) {final _that = this;
switch (_that) {
case _RewardPromotion():
return $default(_that.label,_that.multiplier,_that.endDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  double multiplier,  String endDate)?  $default,) {final _that = this;
switch (_that) {
case _RewardPromotion() when $default != null:
return $default(_that.label,_that.multiplier,_that.endDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RewardPromotion implements RewardPromotion {
  const _RewardPromotion({required this.label, required this.multiplier, required this.endDate});
  factory _RewardPromotion.fromJson(Map<String, dynamic> json) => _$RewardPromotionFromJson(json);

@override final  String label;
@override final  double multiplier;
@override final  String endDate;

/// Create a copy of RewardPromotion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardPromotionCopyWith<_RewardPromotion> get copyWith => __$RewardPromotionCopyWithImpl<_RewardPromotion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RewardPromotionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardPromotion&&(identical(other.label, label) || other.label == label)&&(identical(other.multiplier, multiplier) || other.multiplier == multiplier)&&(identical(other.endDate, endDate) || other.endDate == endDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,multiplier,endDate);

@override
String toString() {
  return 'RewardPromotion(label: $label, multiplier: $multiplier, endDate: $endDate)';
}


}

/// @nodoc
abstract mixin class _$RewardPromotionCopyWith<$Res> implements $RewardPromotionCopyWith<$Res> {
  factory _$RewardPromotionCopyWith(_RewardPromotion value, $Res Function(_RewardPromotion) _then) = __$RewardPromotionCopyWithImpl;
@override @useResult
$Res call({
 String label, double multiplier, String endDate
});




}
/// @nodoc
class __$RewardPromotionCopyWithImpl<$Res>
    implements _$RewardPromotionCopyWith<$Res> {
  __$RewardPromotionCopyWithImpl(this._self, this._then);

  final _RewardPromotion _self;
  final $Res Function(_RewardPromotion) _then;

/// Create a copy of RewardPromotion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? multiplier = null,Object? endDate = null,}) {
  return _then(_RewardPromotion(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,multiplier: null == multiplier ? _self.multiplier : multiplier // ignore: cast_nullable_to_non_nullable
as double,endDate: null == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RewardProgress {

 int get estrellasParaProximoPremio; int get estrellasPorPremio; List<RewardSlot> get premiosDisponibles; RewardPromotion? get promocionActiva;
/// Create a copy of RewardProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardProgressCopyWith<RewardProgress> get copyWith => _$RewardProgressCopyWithImpl<RewardProgress>(this as RewardProgress, _$identity);

  /// Serializes this RewardProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardProgress&&(identical(other.estrellasParaProximoPremio, estrellasParaProximoPremio) || other.estrellasParaProximoPremio == estrellasParaProximoPremio)&&(identical(other.estrellasPorPremio, estrellasPorPremio) || other.estrellasPorPremio == estrellasPorPremio)&&const DeepCollectionEquality().equals(other.premiosDisponibles, premiosDisponibles)&&(identical(other.promocionActiva, promocionActiva) || other.promocionActiva == promocionActiva));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,estrellasParaProximoPremio,estrellasPorPremio,const DeepCollectionEquality().hash(premiosDisponibles),promocionActiva);

@override
String toString() {
  return 'RewardProgress(estrellasParaProximoPremio: $estrellasParaProximoPremio, estrellasPorPremio: $estrellasPorPremio, premiosDisponibles: $premiosDisponibles, promocionActiva: $promocionActiva)';
}


}

/// @nodoc
abstract mixin class $RewardProgressCopyWith<$Res>  {
  factory $RewardProgressCopyWith(RewardProgress value, $Res Function(RewardProgress) _then) = _$RewardProgressCopyWithImpl;
@useResult
$Res call({
 int estrellasParaProximoPremio, int estrellasPorPremio, List<RewardSlot> premiosDisponibles, RewardPromotion? promocionActiva
});


$RewardPromotionCopyWith<$Res>? get promocionActiva;

}
/// @nodoc
class _$RewardProgressCopyWithImpl<$Res>
    implements $RewardProgressCopyWith<$Res> {
  _$RewardProgressCopyWithImpl(this._self, this._then);

  final RewardProgress _self;
  final $Res Function(RewardProgress) _then;

/// Create a copy of RewardProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? estrellasParaProximoPremio = null,Object? estrellasPorPremio = null,Object? premiosDisponibles = null,Object? promocionActiva = freezed,}) {
  return _then(_self.copyWith(
estrellasParaProximoPremio: null == estrellasParaProximoPremio ? _self.estrellasParaProximoPremio : estrellasParaProximoPremio // ignore: cast_nullable_to_non_nullable
as int,estrellasPorPremio: null == estrellasPorPremio ? _self.estrellasPorPremio : estrellasPorPremio // ignore: cast_nullable_to_non_nullable
as int,premiosDisponibles: null == premiosDisponibles ? _self.premiosDisponibles : premiosDisponibles // ignore: cast_nullable_to_non_nullable
as List<RewardSlot>,promocionActiva: freezed == promocionActiva ? _self.promocionActiva : promocionActiva // ignore: cast_nullable_to_non_nullable
as RewardPromotion?,
  ));
}
/// Create a copy of RewardProgress
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RewardPromotionCopyWith<$Res>? get promocionActiva {
    if (_self.promocionActiva == null) {
    return null;
  }

  return $RewardPromotionCopyWith<$Res>(_self.promocionActiva!, (value) {
    return _then(_self.copyWith(promocionActiva: value));
  });
}
}


/// Adds pattern-matching-related methods to [RewardProgress].
extension RewardProgressPatterns on RewardProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardProgress value)  $default,){
final _that = this;
switch (_that) {
case _RewardProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardProgress value)?  $default,){
final _that = this;
switch (_that) {
case _RewardProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int estrellasParaProximoPremio,  int estrellasPorPremio,  List<RewardSlot> premiosDisponibles,  RewardPromotion? promocionActiva)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardProgress() when $default != null:
return $default(_that.estrellasParaProximoPremio,_that.estrellasPorPremio,_that.premiosDisponibles,_that.promocionActiva);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int estrellasParaProximoPremio,  int estrellasPorPremio,  List<RewardSlot> premiosDisponibles,  RewardPromotion? promocionActiva)  $default,) {final _that = this;
switch (_that) {
case _RewardProgress():
return $default(_that.estrellasParaProximoPremio,_that.estrellasPorPremio,_that.premiosDisponibles,_that.promocionActiva);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int estrellasParaProximoPremio,  int estrellasPorPremio,  List<RewardSlot> premiosDisponibles,  RewardPromotion? promocionActiva)?  $default,) {final _that = this;
switch (_that) {
case _RewardProgress() when $default != null:
return $default(_that.estrellasParaProximoPremio,_that.estrellasPorPremio,_that.premiosDisponibles,_that.promocionActiva);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RewardProgress implements RewardProgress {
  const _RewardProgress({required this.estrellasParaProximoPremio, required this.estrellasPorPremio, required final  List<RewardSlot> premiosDisponibles, this.promocionActiva}): _premiosDisponibles = premiosDisponibles;
  factory _RewardProgress.fromJson(Map<String, dynamic> json) => _$RewardProgressFromJson(json);

@override final  int estrellasParaProximoPremio;
@override final  int estrellasPorPremio;
 final  List<RewardSlot> _premiosDisponibles;
@override List<RewardSlot> get premiosDisponibles {
  if (_premiosDisponibles is EqualUnmodifiableListView) return _premiosDisponibles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_premiosDisponibles);
}

@override final  RewardPromotion? promocionActiva;

/// Create a copy of RewardProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardProgressCopyWith<_RewardProgress> get copyWith => __$RewardProgressCopyWithImpl<_RewardProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RewardProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardProgress&&(identical(other.estrellasParaProximoPremio, estrellasParaProximoPremio) || other.estrellasParaProximoPremio == estrellasParaProximoPremio)&&(identical(other.estrellasPorPremio, estrellasPorPremio) || other.estrellasPorPremio == estrellasPorPremio)&&const DeepCollectionEquality().equals(other._premiosDisponibles, _premiosDisponibles)&&(identical(other.promocionActiva, promocionActiva) || other.promocionActiva == promocionActiva));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,estrellasParaProximoPremio,estrellasPorPremio,const DeepCollectionEquality().hash(_premiosDisponibles),promocionActiva);

@override
String toString() {
  return 'RewardProgress(estrellasParaProximoPremio: $estrellasParaProximoPremio, estrellasPorPremio: $estrellasPorPremio, premiosDisponibles: $premiosDisponibles, promocionActiva: $promocionActiva)';
}


}

/// @nodoc
abstract mixin class _$RewardProgressCopyWith<$Res> implements $RewardProgressCopyWith<$Res> {
  factory _$RewardProgressCopyWith(_RewardProgress value, $Res Function(_RewardProgress) _then) = __$RewardProgressCopyWithImpl;
@override @useResult
$Res call({
 int estrellasParaProximoPremio, int estrellasPorPremio, List<RewardSlot> premiosDisponibles, RewardPromotion? promocionActiva
});


@override $RewardPromotionCopyWith<$Res>? get promocionActiva;

}
/// @nodoc
class __$RewardProgressCopyWithImpl<$Res>
    implements _$RewardProgressCopyWith<$Res> {
  __$RewardProgressCopyWithImpl(this._self, this._then);

  final _RewardProgress _self;
  final $Res Function(_RewardProgress) _then;

/// Create a copy of RewardProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? estrellasParaProximoPremio = null,Object? estrellasPorPremio = null,Object? premiosDisponibles = null,Object? promocionActiva = freezed,}) {
  return _then(_RewardProgress(
estrellasParaProximoPremio: null == estrellasParaProximoPremio ? _self.estrellasParaProximoPremio : estrellasParaProximoPremio // ignore: cast_nullable_to_non_nullable
as int,estrellasPorPremio: null == estrellasPorPremio ? _self.estrellasPorPremio : estrellasPorPremio // ignore: cast_nullable_to_non_nullable
as int,premiosDisponibles: null == premiosDisponibles ? _self._premiosDisponibles : premiosDisponibles // ignore: cast_nullable_to_non_nullable
as List<RewardSlot>,promocionActiva: freezed == promocionActiva ? _self.promocionActiva : promocionActiva // ignore: cast_nullable_to_non_nullable
as RewardPromotion?,
  ));
}

/// Create a copy of RewardProgress
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RewardPromotionCopyWith<$Res>? get promocionActiva {
    if (_self.promocionActiva == null) {
    return null;
  }

  return $RewardPromotionCopyWith<$Res>(_self.promocionActiva!, (value) {
    return _then(_self.copyWith(promocionActiva: value));
  });
}
}

// dart format on
