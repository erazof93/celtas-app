import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';
part 'address.g.dart';

/// Dirección guardada del usuario (contrato verificado contra
/// `celtas-backend/src/modules/users/entities/address.entity.ts` y
/// `dto/create-address.dto.ts`).
///
/// `GET /users/me/addresses` devuelve la lista (principal primero);
/// `POST /users/me/addresses` devuelve la dirección recién creada con el
/// mismo shape.
@freezed
abstract class Address with _$Address {
  const factory Address({
    required String id,
    required String alias,
    required String fullAddress,
    String? reference,
    required String district,
    @Default(false) bool isDefault,
  }) = _Address;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
}
