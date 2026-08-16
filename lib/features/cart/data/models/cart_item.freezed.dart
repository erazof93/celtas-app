// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cart_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CartItem {

 String get menuItemId; String get name; double get unitPrice; int get quantity; String? get image; List<SauceOption> get selectedSauces;
/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CartItemCopyWith<CartItem> get copyWith => _$CartItemCopyWithImpl<CartItem>(this as CartItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CartItem&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.image, image) || other.image == image)&&const DeepCollectionEquality().equals(other.selectedSauces, selectedSauces));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,name,unitPrice,quantity,image,const DeepCollectionEquality().hash(selectedSauces));

@override
String toString() {
  return 'CartItem(menuItemId: $menuItemId, name: $name, unitPrice: $unitPrice, quantity: $quantity, image: $image, selectedSauces: $selectedSauces)';
}


}

/// @nodoc
abstract mixin class $CartItemCopyWith<$Res>  {
  factory $CartItemCopyWith(CartItem value, $Res Function(CartItem) _then) = _$CartItemCopyWithImpl;
@useResult
$Res call({
 String menuItemId, String name, double unitPrice, int quantity, String? image, List<SauceOption> selectedSauces
});




}
/// @nodoc
class _$CartItemCopyWithImpl<$Res>
    implements $CartItemCopyWith<$Res> {
  _$CartItemCopyWithImpl(this._self, this._then);

  final CartItem _self;
  final $Res Function(CartItem) _then;

/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? menuItemId = null,Object? name = null,Object? unitPrice = null,Object? quantity = null,Object? image = freezed,Object? selectedSauces = null,}) {
  return _then(_self.copyWith(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,selectedSauces: null == selectedSauces ? _self.selectedSauces : selectedSauces // ignore: cast_nullable_to_non_nullable
as List<SauceOption>,
  ));
}

}


/// Adds pattern-matching-related methods to [CartItem].
extension CartItemPatterns on CartItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CartItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CartItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CartItem value)  $default,){
final _that = this;
switch (_that) {
case _CartItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CartItem value)?  $default,){
final _that = this;
switch (_that) {
case _CartItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String menuItemId,  String name,  double unitPrice,  int quantity,  String? image,  List<SauceOption> selectedSauces)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CartItem() when $default != null:
return $default(_that.menuItemId,_that.name,_that.unitPrice,_that.quantity,_that.image,_that.selectedSauces);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String menuItemId,  String name,  double unitPrice,  int quantity,  String? image,  List<SauceOption> selectedSauces)  $default,) {final _that = this;
switch (_that) {
case _CartItem():
return $default(_that.menuItemId,_that.name,_that.unitPrice,_that.quantity,_that.image,_that.selectedSauces);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String menuItemId,  String name,  double unitPrice,  int quantity,  String? image,  List<SauceOption> selectedSauces)?  $default,) {final _that = this;
switch (_that) {
case _CartItem() when $default != null:
return $default(_that.menuItemId,_that.name,_that.unitPrice,_that.quantity,_that.image,_that.selectedSauces);case _:
  return null;

}
}

}

/// @nodoc


class _CartItem extends CartItem {
  const _CartItem({required this.menuItemId, required this.name, required this.unitPrice, required this.quantity, this.image, final  List<SauceOption> selectedSauces = const <SauceOption>[]}): _selectedSauces = selectedSauces,super._();


@override final  String menuItemId;
@override final  String name;
@override final  double unitPrice;
@override final  int quantity;
@override final  String? image;
 final  List<SauceOption> _selectedSauces;
@override@JsonKey() List<SauceOption> get selectedSauces {
  if (_selectedSauces is EqualUnmodifiableListView) return _selectedSauces;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedSauces);
}


/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CartItemCopyWith<_CartItem> get copyWith => __$CartItemCopyWithImpl<_CartItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CartItem&&(identical(other.menuItemId, menuItemId) || other.menuItemId == menuItemId)&&(identical(other.name, name) || other.name == name)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.image, image) || other.image == image)&&const DeepCollectionEquality().equals(other._selectedSauces, _selectedSauces));
}


@override
int get hashCode => Object.hash(runtimeType,menuItemId,name,unitPrice,quantity,image,const DeepCollectionEquality().hash(_selectedSauces));

@override
String toString() {
  return 'CartItem(menuItemId: $menuItemId, name: $name, unitPrice: $unitPrice, quantity: $quantity, image: $image, selectedSauces: $selectedSauces)';
}


}

/// @nodoc
abstract mixin class _$CartItemCopyWith<$Res> implements $CartItemCopyWith<$Res> {
  factory _$CartItemCopyWith(_CartItem value, $Res Function(_CartItem) _then) = __$CartItemCopyWithImpl;
@override @useResult
$Res call({
 String menuItemId, String name, double unitPrice, int quantity, String? image, List<SauceOption> selectedSauces
});




}
/// @nodoc
class __$CartItemCopyWithImpl<$Res>
    implements _$CartItemCopyWith<$Res> {
  __$CartItemCopyWithImpl(this._self, this._then);

  final _CartItem _self;
  final $Res Function(_CartItem) _then;

/// Create a copy of CartItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? menuItemId = null,Object? name = null,Object? unitPrice = null,Object? quantity = null,Object? image = freezed,Object? selectedSauces = null,}) {
  return _then(_CartItem(
menuItemId: null == menuItemId ? _self.menuItemId : menuItemId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as double,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,selectedSauces: null == selectedSauces ? _self._selectedSauces : selectedSauces // ignore: cast_nullable_to_non_nullable
as List<SauceOption>,
  ));
}


}

// dart format on
