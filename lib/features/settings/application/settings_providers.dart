import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:dio/dio.dart';
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
/// obligatorio de actualización cuando
/// `isUpdateRequired` es `true`.
///
/// Conserva los errores como AsyncError. El controlador del gate decide el
/// fail-open inicial y conserva cualquier bloqueo previamente confirmado.
final appVersionCheckProvider = FutureProvider<AppVersionCheck>((ref) async {
  final cancelToken = CancelToken();
  final result = Completer<AppVersionCheck>();
  Timer? deadline;
  var active = true;
  void cancel() {
    active = false;
    deadline?.cancel();
    cancelToken.cancel('Version check ended');
  }

  ref.onDispose(() {
    cancel();
    if (!result.isCompleted) {
      result.completeError(StateError('Obsolete version check'));
    }
  });
  // One budget for the complete attempt, including PackageInfo and settings.
  deadline = Timer(const Duration(seconds: 20), () {
    cancel();
    result.completeError(TimeoutException('Version check exceeded 20 seconds'));
  });
  // Late platform results must not read a disposed ref or start a request.
  final version = ref.watch(currentAppVersionProvider.future);
  Future<AppVersionCheck> check() async {
    final currentVersion = await version;
    if (!active) throw StateError('Obsolete version check');
    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.getPublicSettings(
      cancelToken: cancelToken,
    );
    if (!active) throw StateError('Obsolete version check');
    return evaluateAppVersion(
      currentVersion: currentVersion,
      minVersion: settings['min_app_version'] as String?,
    );
  }

  unawaited(
    check().then(
      (value) {
        if (!active) return;
        cancel();
        result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!active) return;
        cancel();
        result.completeError(error, stack);
      },
    ),
  );
  return result.future;
});
