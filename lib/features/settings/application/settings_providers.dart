import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repositorio de settings públicas contra el backend real.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ApiClient.instance.dio),
);

/// Estado de apertura del local (`GET /settings/business-hours`), para el
/// aviso preventivo del checkout. NO es la fuente de verdad del bloqueo real
/// — ver doc de [BusinessHours].
final businessHoursProvider = FutureProvider<BusinessHours>(
  (ref) => ref.watch(settingsRepositoryProvider).getBusinessHours(),
);
