// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'banner.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Banner {

 String get id; String get title; String? get imageUrl; BannerActionType get actionType; String? get actionValue; DateTime? get startDate; DateTime? get endDate; bool get active; int get order; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Banner
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BannerCopyWith<Banner> get copyWith => _$BannerCopyWithImpl<Banner>(this as Banner, _$identity);

  /// Serializes this Banner to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Banner&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.actionType, actionType) || other.actionType == actionType)&&(identical(other.actionValue, actionValue) || other.actionValue == actionValue)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.active, active) || other.active == active)&&(identical(other.order, order) || other.order == order)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,imageUrl,actionType,actionValue,startDate,endDate,active,order,createdAt,updatedAt);

@override
String toString() {
  return 'Banner(id: $id, title: $title, imageUrl: $imageUrl, actionType: $actionType, actionValue: $actionValue, startDate: $startDate, endDate: $endDate, active: $active, order: $order, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $BannerCopyWith<$Res>  {
  factory $BannerCopyWith(Banner value, $Res Function(Banner) _then) = _$BannerCopyWithImpl;
@useResult
$Res call({
 String id, String title, String? imageUrl, BannerActionType actionType, String? actionValue, DateTime? startDate, DateTime? endDate, bool active, int order, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$BannerCopyWithImpl<$Res>
    implements $BannerCopyWith<$Res> {
  _$BannerCopyWithImpl(this._self, this._then);

  final Banner _self;
  final $Res Function(Banner) _then;

/// Create a copy of Banner
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? imageUrl = freezed,Object? actionType = null,Object? actionValue = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? active = null,Object? order = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,actionType: null == actionType ? _self.actionType : actionType // ignore: cast_nullable_to_non_nullable
as BannerActionType,actionValue: freezed == actionValue ? _self.actionValue : actionValue // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Banner].
extension BannerPatterns on Banner {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Banner value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Banner() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Banner value)  $default,){
final _that = this;
switch (_that) {
case _Banner():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Banner value)?  $default,){
final _that = this;
switch (_that) {
case _Banner() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String? imageUrl,  BannerActionType actionType,  String? actionValue,  DateTime? startDate,  DateTime? endDate,  bool active,  int order,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Banner() when $default != null:
return $default(_that.id,_that.title,_that.imageUrl,_that.actionType,_that.actionValue,_that.startDate,_that.endDate,_that.active,_that.order,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String? imageUrl,  BannerActionType actionType,  String? actionValue,  DateTime? startDate,  DateTime? endDate,  bool active,  int order,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Banner():
return $default(_that.id,_that.title,_that.imageUrl,_that.actionType,_that.actionValue,_that.startDate,_that.endDate,_that.active,_that.order,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String? imageUrl,  BannerActionType actionType,  String? actionValue,  DateTime? startDate,  DateTime? endDate,  bool active,  int order,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Banner() when $default != null:
return $default(_that.id,_that.title,_that.imageUrl,_that.actionType,_that.actionValue,_that.startDate,_that.endDate,_that.active,_that.order,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Banner implements Banner {
  const _Banner({required this.id, required this.title, this.imageUrl, required this.actionType, this.actionValue, this.startDate, this.endDate, required this.active, required this.order, required this.createdAt, required this.updatedAt});
  factory _Banner.fromJson(Map<String, dynamic> json) => _$BannerFromJson(json);

@override final  String id;
@override final  String title;
@override final  String? imageUrl;
@override final  BannerActionType actionType;
@override final  String? actionValue;
@override final  DateTime? startDate;
@override final  DateTime? endDate;
@override final  bool active;
@override final  int order;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Banner
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BannerCopyWith<_Banner> get copyWith => __$BannerCopyWithImpl<_Banner>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BannerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Banner&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.actionType, actionType) || other.actionType == actionType)&&(identical(other.actionValue, actionValue) || other.actionValue == actionValue)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.active, active) || other.active == active)&&(identical(other.order, order) || other.order == order)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,imageUrl,actionType,actionValue,startDate,endDate,active,order,createdAt,updatedAt);

@override
String toString() {
  return 'Banner(id: $id, title: $title, imageUrl: $imageUrl, actionType: $actionType, actionValue: $actionValue, startDate: $startDate, endDate: $endDate, active: $active, order: $order, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BannerCopyWith<$Res> implements $BannerCopyWith<$Res> {
  factory _$BannerCopyWith(_Banner value, $Res Function(_Banner) _then) = __$BannerCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String? imageUrl, BannerActionType actionType, String? actionValue, DateTime? startDate, DateTime? endDate, bool active, int order, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$BannerCopyWithImpl<$Res>
    implements _$BannerCopyWith<$Res> {
  __$BannerCopyWithImpl(this._self, this._then);

  final _Banner _self;
  final $Res Function(_Banner) _then;

/// Create a copy of Banner
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? imageUrl = freezed,Object? actionType = null,Object? actionValue = freezed,Object? startDate = freezed,Object? endDate = freezed,Object? active = null,Object? order = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Banner(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,actionType: null == actionType ? _self.actionType : actionType // ignore: cast_nullable_to_non_nullable
as BannerActionType,actionValue: freezed == actionValue ? _self.actionValue : actionValue // ignore: cast_nullable_to_non_nullable
as String?,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,order: null == order ? _self.order : order // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
