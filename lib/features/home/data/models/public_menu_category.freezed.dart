// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_menu_category.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicMenuCategory {

 String get id; String get name; String? get description; List<PublicMenuItem> get items;
/// Create a copy of PublicMenuCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicMenuCategoryCopyWith<PublicMenuCategory> get copyWith => _$PublicMenuCategoryCopyWithImpl<PublicMenuCategory>(this as PublicMenuCategory, _$identity);

  /// Serializes this PublicMenuCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicMenuCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'PublicMenuCategory(id: $id, name: $name, description: $description, items: $items)';
}


}

/// @nodoc
abstract mixin class $PublicMenuCategoryCopyWith<$Res>  {
  factory $PublicMenuCategoryCopyWith(PublicMenuCategory value, $Res Function(PublicMenuCategory) _then) = _$PublicMenuCategoryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, List<PublicMenuItem> items
});




}
/// @nodoc
class _$PublicMenuCategoryCopyWithImpl<$Res>
    implements $PublicMenuCategoryCopyWith<$Res> {
  _$PublicMenuCategoryCopyWithImpl(this._self, this._then);

  final PublicMenuCategory _self;
  final $Res Function(PublicMenuCategory) _then;

/// Create a copy of PublicMenuCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? items = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<PublicMenuItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicMenuCategory].
extension PublicMenuCategoryPatterns on PublicMenuCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicMenuCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicMenuCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicMenuCategory value)  $default,){
final _that = this;
switch (_that) {
case _PublicMenuCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicMenuCategory value)?  $default,){
final _that = this;
switch (_that) {
case _PublicMenuCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  List<PublicMenuItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicMenuCategory() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  List<PublicMenuItem> items)  $default,) {final _that = this;
switch (_that) {
case _PublicMenuCategory():
return $default(_that.id,_that.name,_that.description,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  List<PublicMenuItem> items)?  $default,) {final _that = this;
switch (_that) {
case _PublicMenuCategory() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicMenuCategory implements PublicMenuCategory {
  const _PublicMenuCategory({required this.id, required this.name, this.description, required final  List<PublicMenuItem> items}): _items = items;
  factory _PublicMenuCategory.fromJson(Map<String, dynamic> json) => _$PublicMenuCategoryFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
 final  List<PublicMenuItem> _items;
@override List<PublicMenuItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of PublicMenuCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicMenuCategoryCopyWith<_PublicMenuCategory> get copyWith => __$PublicMenuCategoryCopyWithImpl<_PublicMenuCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicMenuCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicMenuCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'PublicMenuCategory(id: $id, name: $name, description: $description, items: $items)';
}


}

/// @nodoc
abstract mixin class _$PublicMenuCategoryCopyWith<$Res> implements $PublicMenuCategoryCopyWith<$Res> {
  factory _$PublicMenuCategoryCopyWith(_PublicMenuCategory value, $Res Function(_PublicMenuCategory) _then) = __$PublicMenuCategoryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, List<PublicMenuItem> items
});




}
/// @nodoc
class __$PublicMenuCategoryCopyWithImpl<$Res>
    implements _$PublicMenuCategoryCopyWith<$Res> {
  __$PublicMenuCategoryCopyWithImpl(this._self, this._then);

  final _PublicMenuCategory _self;
  final $Res Function(_PublicMenuCategory) _then;

/// Create a copy of PublicMenuCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? items = null,}) {
  return _then(_PublicMenuCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<PublicMenuItem>,
  ));
}


}

// dart format on
