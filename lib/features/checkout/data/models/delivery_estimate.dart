import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery_estimate.freezed.dart';
part 'delivery_estimate.g.dart';

enum DeliveryMode {
  @JsonValue('DISTANCE')
  distance,
  @JsonValue('ZONES')
  zones,
}

@freezed
abstract class DeliveryZone with _$DeliveryZone {
  const factory DeliveryZone({required String id, required String name}) =
      _DeliveryZone;

  factory DeliveryZone.fromJson(Map<String, dynamic> json) =>
      _$DeliveryZoneFromJson(json);
}

/// Cotización del servidor. Una tarifa cero solo es válida si hay cobertura.
@freezed
abstract class DeliveryEstimate with _$DeliveryEstimate {
  // Freezed copia esta anotación del constructor a la clase generada.
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory DeliveryEstimate({
    required double deliveryFee,
    required bool isFarOrder,
    @JsonKey(required: true) required double? distanceMeters,
    required bool isCovered,
    required DeliveryMode deliveryMode,
    @JsonKey(required: true) required DeliveryZone? zone,
  }) = _DeliveryEstimate;

  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) =>
      _validateDeliveryEstimate(_$DeliveryEstimateFromJson(json));
}

DeliveryEstimate _validateDeliveryEstimate(DeliveryEstimate estimate) {
  if (!estimate.deliveryFee.isFinite ||
      estimate.deliveryFee < 0 ||
      (estimate.distanceMeters != null &&
          (!estimate.distanceMeters!.isFinite ||
              estimate.distanceMeters! < 0)) ||
      (estimate.deliveryMode == DeliveryMode.distance &&
          (!estimate.isCovered || estimate.zone != null)) ||
      (estimate.deliveryMode == DeliveryMode.zones &&
          (estimate.isCovered != (estimate.zone != null) ||
              (!estimate.isCovered && estimate.deliveryFee != 0)))) {
    throw const FormatException('Respuesta de delivery inválida');
  }
  return estimate;
}
