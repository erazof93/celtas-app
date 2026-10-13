import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppVersionGateStatus { loading, allowed, updateRequired, error }

class AppVersionGateState {
  const AppVersionGateState(this.status, {this.minVersion});

  final AppVersionGateStatus status;
  final String? minVersion;

  bool get blocksNavigation =>
      status == AppVersionGateStatus.loading ||
      status == AppVersionGateStatus.updateRequired;
}

final appVersionGateProvider =
    NotifierProvider<AppVersionGateController, AppVersionGateState>(
      AppVersionGateController.new,
    );

/// Estado persistente independiente del ciclo de vida de las rutas.
class AppVersionGateController extends Notifier<AppVersionGateState> {
  @override
  AppVersionGateState build() {
    ref.listen(appVersionCheckProvider, (_, next) {
      final updated = _resolve(state, next);
      if (updated.status != state.status ||
          updated.minVersion != state.minVersion) {
        state = updated;
      }
    });
    return _resolve(
      const AppVersionGateState(AppVersionGateStatus.loading),
      ref.read(appVersionCheckProvider),
    );
  }

  AppVersionGateState _resolve(
    AppVersionGateState previous,
    AsyncValue<AppVersionCheck> result,
  ) {
    // Un rechequeo no desmonta la app permitida ni retira el bloqueo.
    if (result.isLoading) return previous;
    final check = result.valueOrNull;
    if (result.hasError || check == null || !check.hasComparableVersions) {
      return previous.status == AppVersionGateStatus.updateRequired
          ? previous
          : const AppVersionGateState(AppVersionGateStatus.error);
    }
    return AppVersionGateState(
      check.isUpdateRequired
          ? AppVersionGateStatus.updateRequired
          : AppVersionGateStatus.allowed,
      minVersion: check.minVersion,
    );
  }

  /// Reevalúa al volver al foreground; reúne eventos mientras hay una consulta.
  void recheck() {
    if (ref.read(appVersionCheckProvider).isLoading) return;
    ref.invalidate(currentAppVersionProvider);
    ref.invalidate(appVersionCheckProvider);
    ref.read(appVersionCheckProvider);
  }
}
