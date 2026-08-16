// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_menu_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicMenuItem {

 String get id; String get name; String? get description; double get price; String? get image; List<SauceOption> get sauces;
/// Create a copy of PublicMenuItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicMenuItemCopyWith<PublicMenuItem> get copyWith => _$PublicMenuItemCopyWithImpl<PublicMenuItem>(this as PublicMenuItem, _$identity);

  /// Serializes this PublicMenuItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicMenuItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.image, image) || other.image == image)&&const DeepCollectionEquality().equals(other.sauces, sauces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,price,image,const DeepCollectionEquality().hash(sauces));

@override
String toString() {
  return 'PublicMenuItem(id: $id, name: $name, description: $description, price: $price, image: $image, sauces: $sauces)';
}


}

/// @nodoc
abstract mixin class $PublicMenuItemCopyWith<$Res>  {
  factory $PublicMenuItemCopyWith(PublicMenuItem value, $Res Function(PublicMenuItem) _then) = _$PublicMenuItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? description, double price, String? image, List<SauceOption> sauces
});




}
/// @nodoc
class _$PublicMenuItemCopyWithImpl<$Res>
    implements $PublicMenuItemCopyWith<$Res> {
  _$PublicMenuItemCopyWithImpl(this._self, this._then);

  final PublicMenuItem _self;
  final $Res Function(PublicMenuItem) _then;

/// Create a copy of PublicMenuItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? price = null,Object? image = freezed,Object? sauces = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,sauces: null == sauces ? _self.sauces : sauces // ignore: cast_nullable_to_non_nullable
as List<SauceOption>,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicMenuItem].
extension PublicMenuItemPatterns on PublicMenuItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicMenuItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicMenuItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicMenuItem value)  $default,){
final _that = this;
switch (_that) {
case _PublicMenuItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicMenuItem value)?  $default,){
final _that = this;
switch (_that) {
case _PublicMenuItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  double price,  String? image,  List<SauceOption> sauces)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicMenuItem() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.price,_that.image,_that.sauces);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? description,  double price,  String? image,  List<SauceOption> sauces)  $default,) {final _that = this;
switch (_that) {
case _PublicMenuItem():
return $default(_that.id,_that.name,_that.description,_that.price,_that.image,_that.sauces);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? description,  double price,  String? image,  List<SauceOption> sauces)?  $default,) {final _that = this;
switch (_that) {
case _PublicMenuItem() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.price,_that.image,_that.sauces);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicMenuItem implements PublicMenuItem {
  const _PublicMenuItem({required this.id, required this.name, this.description, required this.price, this.image, final  List<SauceOption> sauces = const <SauceOption>[]}): _sauces = sauces;
  factory _PublicMenuItem.fromJson(Map<String, dynamic> json) => _$PublicMenuItemFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? description;
@override final  double price;
@override final  String? image;
 final  List<SauceOption> _sauces;
@override@JsonKey() List<SauceOption> get sauces {
  if (_sauces is EqualUnmodifiableListView) return _sauces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sauces);
}


/// Create a copy of PublicMenuItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicMenuItemCopyWith<_PublicMenuItem> get copyWith => __$PublicMenuItemCopyWithImpl<_PublicMenuItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicMenuItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicMenuItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&(identical(other.image, image) || other.image == image)&&const DeepCollectionEquality().equals(other._sauces, _sauces));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,price,image,const DeepCollectionEquality().hash(_sauces));

@override
String toString() {
  return 'PublicMenuItem(id: $id, name: $name, description: $description, price: $price, image: $image, sauces: $sauces)';
}


}

/// @nodoc
abstract mixin class _$PublicMenuItemCopyWith<$Res> implements $PublicMenuItemCopyWith<$Res> {
  factory _$PublicMenuItemCopyWith(_PublicMenuItem value, $Res Function(_PublicMenuItem) _then) = __$PublicMenuItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? description, double price, String? image, List<SauceOption> sauces
});




}
/// @nodoc
class __$PublicMenuItemCopyWithImpl<$Res>
    implements _$PublicMenuItemCopyWith<$Res> {
  __$PublicMenuItemCopyWithImpl(this._self, this._then);

  final _PublicMenuItem _self;
  final $Res Function(_PublicMenuItem) _then;

/// Create a copy of PublicMenuItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = freezed,Object? price = null,Object? image = freezed,Object? sauces = null,}) {
  return _then(_PublicMenuItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,sauces: null == sauces ? _self._sauces : sauces // ignore: cast_nullable_to_non_nullable
as List<SauceOption>,
  ));
}


}

// dart format on
