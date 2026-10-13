import 'package:celtas_mobile/features/settings/application/version_gate_diagnostics.dart';
import 'package:celtas_mobile/qa/version_gate_qa.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Separate entry point: never imports/runs the production bootstrap.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !const bool.fromEnvironment('CELTAS_QA')) {
    throw StateError('QA is available only in explicitly enabled debug builds');
  }
  final info = await PackageInfo.fromPlatform();
  const selected = String.fromEnvironment('CELTAS_QA_SCENARIO');
  final scenario = switch (selected) {
    'compatible' => QaScenario.compatible,
    'required' => QaScenario.required,
    'initial_error' => QaScenario.initialError,
    'blocked_error' => QaScenario.blockedError,
    _ => throw StateError('Select an explicit CELTAS_QA_SCENARIO'),
  };
  void record(VersionGateEvent event) =>
      debugPrint('[CELTAS_QA] ${event.name}');
  isolateQaNetwork(info.packageName, record);
  record(VersionGateEvent.appStarted);
  final runtime = VersionGateQa(
    packageName: info.packageName,
    version: '${info.version}+${info.buildNumber}',
    scenario: scenario,
    onEvent: record,
  );
  // Framework exceptions omit exception text/stack: no accidental payload logging.
  FlutterError.onError = (_) => record(VersionGateEvent.frameworkError);
  PlatformDispatcher.instance.onError = (_, _) {
    record(VersionGateEvent.unhandledError);
    return true;
  };
  runApp(VersionGateQaApp(runtime: runtime));
}
