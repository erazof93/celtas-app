import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_hours.freezed.dart';
part 'business_hours.g.dart';

/// Estado de apertura del local, tal como lo devuelve `GET
/// /settings/business-hours` (público, sin auth).
///
/// Contrato verificado contra `celtas-backend/src/modules/settings/
/// settings.controller.ts` (`businessHours()`): el endpoint también devuelve
/// `schedule`/`manualClosed`, pero el checkout solo necesita `open`/`message`
/// para el aviso preventivo — no se modelan acá (extra keys en el JSON se
/// ignoran sin problema). NO es la fuente de verdad del bloqueo real: eso lo
/// decide el 409 de `POST /orders` en el momento de confirmar, porque el
/// local puede cerrar mientras el cliente tiene el checkout abierto.
@freezed
abstract class BusinessHours with _$BusinessHours {
  const factory BusinessHours({
    required bool open,
    required String? message,
  }) = _BusinessHours;

  factory BusinessHours.fromJson(Map<String, dynamic> json) =>
      _$BusinessHoursFromJson(json);
}
