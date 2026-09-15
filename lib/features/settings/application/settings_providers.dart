import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

/// Versión instalada real de la app (`X.Y.Z+BB`), vía `package_info_plus`.
/// Provider propio (en vez de llamar `PackageInfo.fromPlatform()` directo
/// desde [appVersionCheckProvider]) para poder overridearlo en tests sin
/// depender del method channel real del plugin.
final currentAppVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// Compara la versión instalada contra `min_app_version` (`GET
/// /settings/public`). `CeltasApp` lo observa para mostrar el overlay
/// obligatorio de actualización (`ForceUpdateDialog`) cuando
/// `isUpdateRequired` es `true`.
///
/// Fail-open ante cualquier falla de red (timeout, sin conexión, backend
/// dormido de Render): un usuario no debe quedar bloqueado fuera de la app
/// porque el chequeo de versión no pudo completarse — ver
/// `ApiClient`/`apiExceptionFromDio` para los timeouts configurados.
final appVersionCheckProvider = FutureProvider<AppVersionCheck>((ref) async {
  final currentVersion = await ref.watch(currentAppVersionProvider.future);
  try {
    final settings = await ref.watch(settingsRepositoryProvider).getPublicSettings();
    return evaluateAppVersion(
      currentVersion: currentVersion,
      minVersion: settings['min_app_version'] as String?,
    );
  } on ApiException {
    return AppVersionCheck.noBlock;
  }
});
