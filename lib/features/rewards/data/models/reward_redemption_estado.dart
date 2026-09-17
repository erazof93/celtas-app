import 'package:freezed_annotation/freezed_annotation.dart';

/// Estado de un `RewardSlot` (contrato real: `RewardRedemption.usedAt` en
/// `backend-celtas/src/modules/rewards/entities/reward-redemption.entity.ts`
/// — el backend deriva este campo, no es una columna propia: `redeemed` si
/// `usedAt != null`, `pending` si no).
///
/// Un premio `redeemed` YA NO desaparece de `premiosDisponibles` — sigue
/// devolviéndose hasta que vence (`expiresAt`), para que la app lo muestre
/// marcado como reclamado en vez de hacerlo desaparecer sin explicación.
enum RewardRedemptionEstado {
  @JsonValue('pending')
  pending,

  @JsonValue('redeemed')
  redeemed,
}
