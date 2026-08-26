import 'package:freezed_annotation/freezed_annotation.dart';

part 'reward_progress.freezed.dart';
part 'reward_progress.g.dart';

/// Premio ganado y todavía sin canjear, tal como lo devuelve
/// `GET /rewards/progress` dentro de `premiosDisponibles`.
///
/// Contrato verificado contra `RewardsService.getProgress`
/// (`backend-celtas/src/modules/rewards/rewards.service.ts`): el backend NO
/// expone nombre de producto ni precio acá — un premio ganado no está atado
/// a ningún producto hasta que se canjea (`RewardRedemption.menuItemId`
/// queda `null` hasta el canje). La UI nunca debe nombrar un producto
/// específico para un `RewardSlot`, solo copy genérico.
@freezed
abstract class RewardSlot with _$RewardSlot {
  const factory RewardSlot({
    required String id,
    required DateTime expiresAt,
  }) = _RewardSlot;

  factory RewardSlot.fromJson(Map<String, dynamic> json) =>
      _$RewardSlotFromJson(json);
}

/// Promoción de estrellas dobles vigente hoy (`StarPromotion` activa en el
/// backend). `endDate` se deja como string plano `YYYY-MM-DD` (NO se parsea
/// a `DateTime`) — mismo criterio que ya usa `celtas-admin` con las fechas de
/// `StarPromotion`, para no correr el día por zona horaria al formatear.
@freezed
abstract class RewardPromotion with _$RewardPromotion {
  const factory RewardPromotion({
    required String label,
    required double multiplier,
    required String endDate,
  }) = _RewardPromotion;

  factory RewardPromotion.fromJson(Map<String, dynamic> json) =>
      _$RewardPromotionFromJson(json);
}

/// Respuesta de `GET /rewards/progress` (JWT), contrato verificado contra
/// `RewardsService.getProgress`:
///
/// ```json
/// {
///   "estrellasParaProximoPremio": 4,
///   "estrellasPorPremio": 10,
///   "premiosDisponibles": [{ "id": "uuid", "expiresAt": "..." }],
///   "promocionActiva": { "label": "...", "multiplier": 2, "endDate": "..." }
/// }
/// ```
///
/// `estrellasParaProximoPremio` es el progreso YA ACUMULADO en el ciclo
/// actual (`estrellasDelMes % estrellasPorPremio` en el backend), NO lo que
/// falta — cuidado con el signo al calcular estrellas rellenas para la
/// grilla (ver `RewardsScreen`). `promocionActiva` es `null` si no hay
/// ninguna vigente hoy; `premiosDisponibles` puede ser `[]`.
@freezed
abstract class RewardProgress with _$RewardProgress {
  const factory RewardProgress({
    required int estrellasParaProximoPremio,
    required int estrellasPorPremio,
    required List<RewardSlot> premiosDisponibles,
    RewardPromotion? promocionActiva,
  }) = _RewardProgress;

  factory RewardProgress.fromJson(Map<String, dynamic> json) =>
      _$RewardProgressFromJson(json);
}
