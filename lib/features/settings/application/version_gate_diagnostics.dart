import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Closed event vocabulary: no URLs, tokens, session data or response bodies.
enum VersionGateEvent {
  appStarted,
  validationStarted,
  validationAllowed,
  validationRequired,
  validationError,
  gateLoading,
  gateAllowed,
  gateRequired,
  gateError,
  bootstrapCompleted,
  navigationGo,
  navigationPush,
  homeMounted,
  storeOpening,
  storeOpened,
  storeFailed,
  resumed,
  backBlocked,
  networkDenied,
  frameworkError,
  unhandledError,
}

final versionGateDiagnosticsProvider =
    Provider<void Function(VersionGateEvent)>((ref) => (_) {});
