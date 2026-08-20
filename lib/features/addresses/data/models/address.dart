import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';
part 'address.g.dart';

/// Dirección guardada del usuario (contrato verificado contra
/// `backend-celtas/src/modules/users/entities/address.entity.ts` y
/// `dto/create-address.dto.ts`/`update-address.dto.ts`, rama
/// `feature/direcciones-geoapify`, ya auditada del lado del backend).
///
/// `GET /users/me/addresses` devuelve la lista (principal primero);
/// `POST /users/me/addresses` devuelve la dirección recién creada con el
/// mismo shape.
///
/// `latitude`/`longitude`: `double | null`, resueltas client-side vía
/// Geoapify (autocompletado, GPS o el pin del mapa) — nunca calculadas por
/// el backend. `null` es un valor válido: direcciones creadas antes de esta
/// feature, o guardadas sin pasar por el mapa (ej. solo edición de alias),
/// siguen siendo direcciones válidas (ver skill `geoapify-direcciones`).
@freezed
abstract class Address with _$Address {
  const factory Address({
    required String id,
    required String alias,
    required String fullAddress,
    String? reference,
    required String district,
    @Default(false) bool isDefault,
    double? latitude,
    double? longitude,
  }) = _Address;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
}
