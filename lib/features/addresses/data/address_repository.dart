import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:dio/dio.dart';

/// Repositorio de direcciones contra el backend real.
///
/// Endpoints (contrato verificado contra `celtas-backend/src/modules/users/
/// users.controller.ts` + `dto/create-address.dto.ts`):
///   - `GET /users/me/addresses` → lista de direcciones (principal primero).
///   - `POST /users/me/addresses` con `{ alias, fullAddress, reference?,
///     district, isDefault? }` → 201 con la dirección creada.
///
/// Este repositorio cubre solo lo que necesita el checkout (módulo 5): listar
/// y crear. El CRUD completo (editar/eliminar) es del módulo 6.
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
        },
      );
      return Address.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      throw apiExceptionFromDio(e);
    }
  }
}
