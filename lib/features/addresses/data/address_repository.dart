import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:dio/dio.dart';

/// Repositorio de direcciones contra el backend real.
///
/// Endpoints (contrato verificado contra `backend-celtas/src/modules/users/
/// users.controller.ts` + `addresses.service.ts` + DTOs de create/update,
/// rama `feature/direcciones-geoapify`):
///   - `GET /users/me/addresses` → lista de direcciones (principal primero,
///     el backend ordena `isDefault DESC, createdAt ASC`).
///   - `POST /users/me/addresses` con `{ alias, fullAddress, reference?,
///     district, isDefault?, latitude?, longitude? }` → 201 con la dirección
///     creada. `latitude`/`longitude` son opcionales y nullable — el backend
///     las valida con `@IsLatitude`/`@IsLongitude` solo si vienen presentes.
///   - `PATCH /users/me/addresses/:id` (el `id` va en la URL, nunca en el
///     body) con cualquier subconjunto de esos mismos campos → 200 con la
///     dirección actualizada.
///   - `DELETE /users/me/addresses/:id` → 200. El backend NO reasigna
///     automáticamente otra dirección como principal si se borra la que
///     tenía `isDefault: true` (confirmado en `addresses.service.ts`:
///     `remove()` no toca `isDefault` de las demás) — esa reasignación, si
///     se quiere, es responsabilidad del cliente (ver `AddressListNotifier`).
class AddressRepository {
  AddressRepository(this._dio);

  final Dio _dio;

  Future<List<Address>> getAddresses() async {
    try {
      final response = await _dio.get<List<dynamic>>('/users/me/addresses');
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Address.fromJson)
          .toList();
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<Address> createAddress({
    required String alias,
    required String fullAddress,
    String? reference,
    required String district,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/users/me/addresses',
        data: {
          'alias': alias,
          'fullAddress': fullAddress,
          if (reference != null && reference.isNotEmpty)
            'reference': reference,
          'district': district,
          if (isDefault) 'isDefault': isDefault,
          'latitude': ?latitude,
          'longitude': ?longitude,
        },
      );
      return Address.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  /// Actualización parcial: solo se manda lo que viene no-nulo. El `id` va en
  /// el path, nunca en el body.
  ///
  /// No parsea la respuesta a `Address`: verificado en dispositivo real que
  /// un PATCH parcial (ej. solo `{isDefault: true}`) devuelve un body
  /// incompleto (bug del backend en `AddressesService.update()` — usa
  /// `Object.assign(address, dto)`, y como `dto` es una instancia de
  /// `UpdateAddressDto` con TODOS sus campos declarados como propiedad propia
  /// aunque no se hayan enviado, los campos ausentes llegan como `undefined`
  /// y sobrescriben los del entity en memoria antes de serializar la
  /// respuesta — el registro en la base de datos queda íntegro porque
  /// TypeORM ignora columnas `undefined` al armar el `UPDATE`, pero la
  /// respuesta HTTP sí pierde esos campos). Ningún caller de este método usa
  /// el valor de retorno (ambos vuelven a pedir la lista completa después),
  /// así que evitamos depender de un shape de respuesta que el backend no
  /// garantiza.
  Future<void> updateAddress(
    String id, {
    String? alias,
    String? fullAddress,
    String? reference,
    String? district,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _dio.patch<void>(
        '/users/me/addresses/$id',
        data: {
          'alias': ?alias,
          'fullAddress': ?fullAddress,
          'reference': ?reference,
          'district': ?district,
          'isDefault': ?isDefault,
          'latitude': ?latitude,
          'longitude': ?longitude,
        },
      );
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _dio.delete<void>('/users/me/addresses/$id');
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
