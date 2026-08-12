// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_history_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationHistoryItem {

 String get title; String get body; DateTime get receivedAt; Map<String, dynamic> get data;
/// Create a copy of NotificationHistoryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationHistoryItemCopyWith<NotificationHistoryItem> get copyWith => _$NotificationHistoryItemCopyWithImpl<NotificationHistoryItem>(this as NotificationHistoryItem, _$identity);

  /// Serializes this NotificationHistoryItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationHistoryItem&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,body,receivedAt,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'NotificationHistoryItem(title: $title, body: $body, receivedAt: $receivedAt, data: $data)';
}


}

/// @nodoc
abstract mixin class $NotificationHistoryItemCopyWith<$Res>  {
  factory $NotificationHistoryItemCopyWith(NotificationHistoryItem value, $Res Function(NotificationHistoryItem) _then) = _$NotificationHistoryItemCopyWithImpl;
@useResult
$Res call({
 String title, String body, DateTime receivedAt, Map<String, dynamic> data
});




}
/// @nodoc
class _$NotificationHistoryItemCopyWithImpl<$Res>
    implements $NotificationHistoryItemCopyWith<$Res> {
  _$NotificationHistoryItemCopyWithImpl(this._self, this._then);

  final NotificationHistoryItem _self;
  final $Res Function(NotificationHistoryItem) _then;

/// Create a copy of NotificationHistoryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? body = null,Object? receivedAt = null,Object? data = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationHistoryItem].
extension NotificationHistoryItemPatterns on NotificationHistoryItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationHistoryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationHistoryItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationHistoryItem value)  $default,){
final _that = this;
switch (_that) {
case _NotificationHistoryItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationHistoryItem value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationHistoryItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String body,  DateTime receivedAt,  Map<String, dynamic> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationHistoryItem() when $default != null:
return $default(_that.title,_that.body,_that.receivedAt,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String body,  DateTime receivedAt,  Map<String, dynamic> data)  $default,) {final _that = this;
switch (_that) {
case _NotificationHistoryItem():
return $default(_that.title,_that.body,_that.receivedAt,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String body,  DateTime receivedAt,  Map<String, dynamic> data)?  $default,) {final _that = this;
switch (_that) {
case _NotificationHistoryItem() when $default != null:
return $default(_that.title,_that.body,_that.receivedAt,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationHistoryItem implements NotificationHistoryItem {
  const _NotificationHistoryItem({required this.title, required this.body, required this.receivedAt, required final  Map<String, dynamic> data}): _data = data;
  factory _NotificationHistoryItem.fromJson(Map<String, dynamic> json) => _$NotificationHistoryItemFromJson(json);

@override final  String title;
@override final  String body;
@override final  DateTime receivedAt;
 final  Map<String, dynamic> _data;
@override Map<String, dynamic> get data {
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_data);
}


/// Create a copy of NotificationHistoryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationHistoryItemCopyWith<_NotificationHistoryItem> get copyWith => __$NotificationHistoryItemCopyWithImpl<_NotificationHistoryItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationHistoryItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationHistoryItem&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,body,receivedAt,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'NotificationHistoryItem(title: $title, body: $body, receivedAt: $receivedAt, data: $data)';
}


}

/// @nodoc
abstract mixin class _$NotificationHistoryItemCopyWith<$Res> implements $NotificationHistoryItemCopyWith<$Res> {
  factory _$NotificationHistoryItemCopyWith(_NotificationHistoryItem value, $Res Function(_NotificationHistoryItem) _then) = __$NotificationHistoryItemCopyWithImpl;
@override @useResult
$Res call({
 String title, String body, DateTime receivedAt, Map<String, dynamic> data
});




}
/// @nodoc
class __$NotificationHistoryItemCopyWithImpl<$Res>
    implements _$NotificationHistoryItemCopyWith<$Res> {
  __$NotificationHistoryItemCopyWithImpl(this._self, this._then);

  final _NotificationHistoryItem _self;
  final $Res Function(_NotificationHistoryItem) _then;

/// Create a copy of NotificationHistoryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? body = null,Object? receivedAt = null,Object? data = null,}) {
  return _then(_NotificationHistoryItem(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
