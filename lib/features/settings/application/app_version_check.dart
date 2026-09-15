/// Resultado de comparar la versión instalada de la app contra
/// `min_app_version` (`GET /settings/public`).
class AppVersionCheck {
  const AppVersionCheck({required this.isUpdateRequired, required this.minVersion});

  /// Sin bloqueo: falta `min_app_version` en el backend, viene mal formado,
  /// o no se pudo consultar (ver [evaluateAppVersion] y
  /// `appVersionCheckProvider`) — fail-open a propósito.
  static const AppVersionCheck noBlock = AppVersionCheck(
    isUpdateRequired: false,
    minVersion: null,
  );

  final bool isUpdateRequired;

  /// `min_app_version` tal como la devolvió el backend (`X.Y.Z+BB`), o
  /// `null` si no hay bloqueo. La UI la usa solo para mostrar el "X.Y.Z" al
  /// usuario (ver `ForceUpdateDialog`).
  final String? minVersion;
}

/// Compara el **build number** (la parte después del `+`) de
/// `currentVersion` contra `minVersion` — NUNCA el semver `X.Y.Z` solo.
///
/// El backend puede publicar el mismo `X.Y.Z` con un build number mayor (ej.
/// `1.0.1+16` → `1.0.1+17`, mismo caso que sembró `SettingsService` como
/// baseline en el backend) y el build number es lo único monótono y
/// confiable acá — mismo criterio que `versionCode` de Android /
/// `CFBundleVersion` de iOS.
///
/// Fail-open: si `minVersion` es `null`/vacío, no trae `+`, o la parte del
/// build no es un entero, devuelve [AppVersionCheck.noBlock] en vez de
/// lanzar — un dato mal cargado en el panel admin no debe trabar a todos los
/// usuarios. Pura y testeable en aislamiento, sin red ni Riverpod (mismo
/// criterio que `actionForAuthorizationStatus`).
AppVersionCheck evaluateAppVersion({
  required String currentVersion,
  String? minVersion,
}) {
  if (minVersion == null || minVersion.isEmpty) {
    return AppVersionCheck.noBlock;
  }
  final currentBuild = _buildNumberOf(currentVersion);
  final minBuild = _buildNumberOf(minVersion);
  if (currentBuild == null || minBuild == null) {
    return AppVersionCheck.noBlock;
  }
  return AppVersionCheck(
    isUpdateRequired: currentBuild < minBuild,
    minVersion: minVersion,
  );
}

int? _buildNumberOf(String version) {
  final parts = version.split('+');
  if (parts.length != 2) return null;
  return int.tryParse(parts[1]);
}
