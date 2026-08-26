// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reward_catalog_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RewardCatalogItem {

 String get id; String get name; String? get description; double get price; String? get image;
/// Create a copy of RewardCatalogItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RewardCatalogItemCopyWith<RewardCatalogItem> get copyWith => _$RewardCatalogItemCopyWithImpl<RewardCatalogItem>(this as RewardCatalogItem, _$identity);

  /// Serializes this RewardCatalogItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RewardCatalogItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.image, image) || other.image == image));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,price,image);

@override
String toString() {
  return 'RewardCatalogItem(id: $id, name: $name, description: $description, price: $price, image: $image)';
}


}

/// @nodoc
abstract mixin class $RewardCatalogItemCopyWith<$Res>  {
  factory $RewardCatalogItemCopyWith(RewardCatalogItem value, $Res Function(RewardCatalogItem) _then) = _$RewardCatalogItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, double price, String? image
});




}
/// @nodoc
class _$RewardCatalogItemCopyWithImpl<$Res>
    implements $RewardCatalogItemCopyWith<$Res> {
  _$RewardCatalogItemCopyWithImpl(this._self, this._then);

  final RewardCatalogItem _self;
  final $Res Function(RewardCatalogItem) _then;

/// Create a copy of RewardCatalogItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? price = null,Object? image = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RewardCatalogItem].
extension RewardCatalogItemPatterns on RewardCatalogItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RewardCatalogItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RewardCatalogItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RewardCatalogItem value)  $default,){
final _that = this;
switch (_that) {
case _RewardCatalogItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RewardCatalogItem value)?  $default,){
final _that = this;
switch (_that) {
case _RewardCatalogItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  double price,  String? image)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RewardCatalogItem() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.price,_that.image);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  double price,  String? image)  $default,) {final _that = this;
switch (_that) {
case _RewardCatalogItem():
return $default(_that.id,_that.name,_that.description,_that.price,_that.image);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  double price,  String? image)?  $default,) {final _that = this;
switch (_that) {
case _RewardCatalogItem() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.price,_that.image);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RewardCatalogItem implements RewardCatalogItem {
  const _RewardCatalogItem({required this.id, required this.name, this.description, required this.price, this.image});
  factory _RewardCatalogItem.fromJson(Map<String, dynamic> json) => _$RewardCatalogItemFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  double price;
@override final  String? image;

/// Create a copy of RewardCatalogItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RewardCatalogItemCopyWith<_RewardCatalogItem> get copyWith => __$RewardCatalogItemCopyWithImpl<_RewardCatalogItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RewardCatalogItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RewardCatalogItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.image, image) || other.image == image));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,price,image);

@override
String toString() {
  return 'RewardCatalogItem(id: $id, name: $name, description: $description, price: $price, image: $image)';
}


}

/// @nodoc
abstract mixin class _$RewardCatalogItemCopyWith<$Res> implements $RewardCatalogItemCopyWith<$Res> {
  factory _$RewardCatalogItemCopyWith(_RewardCatalogItem value, $Res Function(_RewardCatalogItem) _then) = __$RewardCatalogItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, double price, String? image
});




}
/// @nodoc
class __$RewardCatalogItemCopyWithImpl<$Res>
    implements _$RewardCatalogItemCopyWith<$Res> {
  __$RewardCatalogItemCopyWithImpl(this._self, this._then);

  final _RewardCatalogItem _self;
  final $Res Function(_RewardCatalogItem) _then;

/// Create a copy of RewardCatalogItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? price = null,Object? image = freezed,}) {
  return _then(_RewardCatalogItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
