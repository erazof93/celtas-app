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
/// específico para un `RewardSlot`, solo copy genérico. `esEspecial` indica
/// si este premio reparte del catálogo especial (`GET /rewards/catalog?
/// especial=true`) o del normal.
@freezed
abstract class RewardSlot with _$RewardSlot {
  const factory RewardSlot({
    required String id,
    required DateTime expiresAt,
    required bool esEspecial,
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

/// Progreso de un hito individual del tablero del mes, tal como lo devuelve
/// `GET /rewards/progress` dentro de `hitos`. `estrellasRequeridas`,
/// `alcanzado` y `esEspecial` los configura el admin — la cantidad de hitos,
/// sus umbrales y cuál es el especial son 100% dinámicos, nunca hardcodear
/// 3 hitos ni los valores 5/8/15 (son solo el ejemplo vigente hoy).
@freezed
abstract class RewardMilestoneProgress with _$RewardMilestoneProgress {
  const factory RewardMilestoneProgress({
    required int estrellasRequeridas,
    required bool alcanzado,
    required bool esEspecial,
  }) = _RewardMilestoneProgress;

  factory RewardMilestoneProgress.fromJson(Map<String, dynamic> json) =>
      _$RewardMilestoneProgressFromJson(json);
}

/// Respuesta de `GET /rewards/progress` (JWT), contrato verificado contra
/// `RewardsService.getProgress`:
///
/// ```json
/// {
///   "estrellasDelMes": 9,
///   "hitos": [
///     { "estrellasRequeridas": 5, "alcanzado": true, "esEspecial": false },
///     { "estrellasRequeridas": 8, "alcanzado": true, "esEspecial": false },
///     { "estrellasRequeridas": 15, "alcanzado": false, "esEspecial": true }
///   ],
///   "premiosDisponibles": [{ "id": "uuid", "expiresAt": "...", "esEspecial": false }],
///   "promocionActiva": { "label": "...", "multiplier": 2, "endDate": "..." }
/// }
/// ```
///
/// Esquema de HITOS irregulares (reemplaza el viejo "cada N estrellas = 1
/// premio"): `estrellasDelMes` es el total acumulado este mes SIN módulo — el
/// backend ya no hace `% estrellasPorPremio`, la lógica de "cuáles premios ya
/// se alcanzaron" vive enteramente en `hitos` (`alcanzado = estrellasDelMes
/// >= estrellasRequeridas` de cada hito, ya resuelto por el backend). `hitos`
/// puede venir `[]` en un caso borde (admin sin hitos configurados todavía) —
/// la UI debe manejarlo sin crashear. `promocionActiva` es `null` si no hay
/// ninguna vigente hoy; `premiosDisponibles` puede ser `[]`.
@freezed
abstract class RewardProgress with _$RewardProgress {
  const factory RewardProgress({
    required int estrellasDelMes,
    required List<RewardMilestoneProgress> hitos,
    required List<RewardSlot> premiosDisponibles,
    RewardPromotion? promocionActiva,
  }) = _RewardProgress;

  factory RewardProgress.fromJson(Map<String, dynamic> json) =>
      _$RewardProgressFromJson(json);
}
