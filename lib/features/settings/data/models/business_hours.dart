import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_hours.freezed.dart';
part 'business_hours.g.dart';

/// Estado de apertura del local, tal como lo devuelve `GET
/// /settings/business-hours` (público, sin auth).
///
/// Contrato verificado contra `celtas-backend/src/modules/settings/
/// settings.controller.ts` (`businessHours()`): el endpoint también devuelve
/// `schedule`/`manualClosed`, que ni el checkout ni el Home necesitan — no se
/// modelan acá (extra keys en el JSON se ignoran sin problema). NO es la
/// fuente de verdad del bloqueo real: eso lo decide el 409 de `POST /orders`
/// en el momento de confirmar, porque el local puede cerrar mientras el
/// cliente tiene el checkout abierto.
///
/// `nextChangeAt` (ISO 8601 UTC, parseado a un `DateTime` UTC real — nunca
/// dejar como `String` suelto) es el instante exacto en que `open` va a
/// cambiar, calculado por el backend a partir del horario programado. Es
/// `null` cuando el cierre manual está activo (puede levantarse en cualquier
/// momento, no es predecible) o cuando el horario configurado nunca abre. El
/// Home lo usa para autoprogramar un único refresco en vez de hacer polling
/// — ver `HomeScreen`/`_HomeScreenState`.
@freezed
abstract class BusinessHours with _$BusinessHours {
  const factory BusinessHours({
    required bool open,
    required String? message,
    required DateTime? nextChangeAt,
  }) = _BusinessHours;

  factory BusinessHours.fromJson(Map<String, dynamic> json) =>
      _$BusinessHoursFromJson(json);
}
