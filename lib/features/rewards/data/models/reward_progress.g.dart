// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RewardSlot _$RewardSlotFromJson(Map<String, dynamic> json) => _RewardSlot(
  id: json['id'] as String,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  esEspecial: json['esEspecial'] as bool,
);

Map<String, dynamic> _$RewardSlotToJson(_RewardSlot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'esEspecial': instance.esEspecial,
    };

_RewardPromotion _$RewardPromotionFromJson(Map<String, dynamic> json) =>
    _RewardPromotion(
      label: json['label'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      endDate: json['endDate'] as String,
    );

Map<String, dynamic> _$RewardPromotionToJson(_RewardPromotion instance) =>
    <String, dynamic>{
      'label': instance.label,
      'multiplier': instance.multiplier,
      'endDate': instance.endDate,
    };

_RewardMilestoneProgress _$RewardMilestoneProgressFromJson(
  Map<String, dynamic> json,
) => _RewardMilestoneProgress(
  estrellasRequeridas: (json['estrellasRequeridas'] as num).toInt(),
  alcanzado: json['alcanzado'] as bool,
  esEspecial: json['esEspecial'] as bool,
);

Map<String, dynamic> _$RewardMilestoneProgressToJson(
  _RewardMilestoneProgress instance,
) => <String, dynamic>{
  'estrellasRequeridas': instance.estrellasRequeridas,
  'alcanzado': instance.alcanzado,
  'esEspecial': instance.esEspecial,
};

_RewardProgress _$RewardProgressFromJson(Map<String, dynamic> json) =>
    _RewardProgress(
      estrellasDelMes: (json['estrellasDelMes'] as num).toInt(),
      hitos: (json['hitos'] as List<dynamic>)
          .map(
            (e) => RewardMilestoneProgress.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      premiosDisponibles: (json['premiosDisponibles'] as List<dynamic>)
          .map((e) => RewardSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      promocionActiva: json['promocionActiva'] == null
          ? null
          : RewardPromotion.fromJson(
              json['promocionActiva'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$RewardProgressToJson(_RewardProgress instance) =>
    <String, dynamic>{
      'estrellasDelMes': instance.estrellasDelMes,
      'hitos': instance.hitos,
      'premiosDisponibles': instance.premiosDisponibles,
      'promocionActiva': instance.promocionActiva,
    };
