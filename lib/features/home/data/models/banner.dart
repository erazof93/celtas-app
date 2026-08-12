import 'package:freezed_annotation/freezed_annotation.dart';

part 'banner.freezed.dart';
part 'banner.g.dart';

/// A dónde lleva el banner al tocarlo (contrato real del backend:
/// `BannerActionType` en `banners/entities/banner.entity.ts`).
enum BannerActionType {
  /// Sin acción: el banner es solo informativo.
  @JsonValue('none')
  none,

  /// Lleva a una categoría del menú (`actionValue` = id real de la
  /// categoría, NO un slug — el Swagger del backend lo describe como "slug"
  /// pero el panel admin (`BannerForm.tsx`) guarda el `id` real; algunos
  /// banners creados antes del selector pudieron quedar con un valor escrito
  /// a mano que no matchea ningún id real, mismo caso que una categoría
  /// borrada: el estado vacío del menú ya lo cubre).
  @JsonValue('category')
  category,

  /// Lleva al detalle de un producto (`actionValue` = id del producto).
  @JsonValue('menuItem')
  menuItem,

  /// Abre una URL externa (`actionValue` = URL).
  @JsonValue('external_url')
  externalUrl,
}

/// Banner de promoción mostrado en el carrusel del Home.
///
/// Contrato verificado contra `celtas-backend/src/modules/banners/entities/
/// banner.entity.ts` y la respuesta real de `GET /banners/active`:
/// `{ success, data: Banner[] }`, ordenados por `order` ascendente y ya
/// filtrados por `active` + rango de fechas en el backend.
@freezed
abstract class Banner with _$Banner {
  const factory Banner({
    required String id,
    required String title,
    String? imageUrl,
    required BannerActionType actionType,
    String? actionValue,
    DateTime? startDate,
    DateTime? endDate,
    required bool active,
    required int order,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Banner;

  factory Banner.fromJson(Map<String, dynamic> json) => _$BannerFromJson(json);
}
