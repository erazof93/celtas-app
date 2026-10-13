import 'dart:async';

import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends SettingsRepository {
  _Repository() : super(Dio());
  final responses = <Completer<Map<String, dynamic>>>[];
  final tokens = <CancelToken>[];

  @override
  Future<Map<String, dynamic>> getPublicSettings({CancelToken? cancelToken}) {
    tokens.add(cancelToken!);
    final response = Completer<Map<String, dynamic>>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  late _Repository repository;
  late ProviderContainer container;
  late Completer<String> version;

  void initialize() {
    repository = _Repository();
    version = Completer<String>();
    container = ProviderContainer(
      overrides: [
        currentAppVersionProvider.overrideWith((ref) => version.future),
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.read(appVersionGateProvider);
  }

  tearDown(() => container.dispose());

  AppVersionGateState gate() => container.read(appVersionGateProvider);

  testWidgets('disposing never completing platform cancels deadline', (
    tester,
  ) async {
    initialize();
    container.dispose();
    container = ProviderContainer();
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.responses, isEmpty);
    // No platform completion or advance to the 20-second deadline is needed.
    // The test binding checks that no timer remains pending.
  });

  testWidgets('late platform error after timeout is consumed', (tester) async {
    initialize();
    await tester.pump(const Duration(seconds: 20));
    version.completeError(StateError('late platform error'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(gate().status, AppVersionGateStatus.error);
    expect(repository.responses, isEmpty);
  });

  testWidgets('success before deadline cancels timer and makes one request', (
    tester,
  ) async {
    initialize();
    version.complete('1.0.1+17');
    await tester.pump(const Duration(milliseconds: 1));
    repository.responses.single.complete({'min_app_version': '1.0.1+17'});
    await tester.pump(const Duration(milliseconds: 1));
    expect(gate().status, AppVersionGateStatus.allowed);
    await tester.pump(const Duration(seconds: 20));
    expect(gate().status, AppVersionGateStatus.allowed);
    expect(repository.responses, hasLength(1));
  });

  testWidgets('never completing platform future fails open at 20 seconds', (
    tester,
  ) async {
    initialize();
    await tester.pump(const Duration(seconds: 19));
    expect(gate().status, AppVersionGateStatus.loading);
    await tester.pump(const Duration(seconds: 1));
    expect(gate().status, AppVersionGateStatus.error);
    expect(gate().blocksNavigation, isFalse);
    version.complete('1.0.1+16');
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.responses, isEmpty);
    expect(gate().status, AppVersionGateStatus.error);
  });

  testWidgets('global budget includes platform time; late settings ignored', (
    tester,
  ) async {
    initialize();
    await tester.pump(const Duration(seconds: 15));
    version.complete('1.0.1+16');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(gate().blocksNavigation, isFalse);
    expect(repository.tokens.single.isCancelled, isTrue);
    repository.responses.single.complete({'min_app_version': '1.0.1+99'});
    await tester.pump(const Duration(milliseconds: 1));
    expect(gate().status, AppVersionGateStatus.error);
    expect(repository.responses, hasLength(1));
  });

  testWidgets('confirmed block survives timeout and late compatible result', (
    tester,
  ) async {
    initialize();
    version.complete('1.0.1+16');
    await tester.pump(const Duration(milliseconds: 1));
    repository.responses.single.complete({'min_app_version': '1.0.1+17'});
    await tester.pump(const Duration(milliseconds: 1));
    container.read(appVersionGateProvider.notifier).recheck();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(seconds: 20));
    expect(gate().status, AppVersionGateStatus.updateRequired);
    expect(gate().blocksNavigation, isTrue);
    expect(repository.tokens.last.isCancelled, isTrue);
    repository.responses.last.complete({'min_app_version': '1.0.1+16'});
    await tester.pump(const Duration(milliseconds: 1));
    expect(gate().status, AppVersionGateStatus.updateRequired);
    expect(gate().minVersion, '1.0.1+17');
  });

  testWidgets(
    'concurrent checks share attempt; old result cannot overwrite new',
    (tester) async {
      initialize();
      version.complete('1.0.1+16');
      await tester.pump(const Duration(milliseconds: 1));
      final controller = container.read(appVersionGateProvider.notifier);
      controller.recheck();
      controller.recheck();
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.responses, hasLength(1));
      await tester.pump(const Duration(seconds: 20));
      controller.recheck();
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.responses, hasLength(2));
      repository.responses.last.complete({'min_app_version': '1.0.1+17'});
      await tester.pump(const Duration(milliseconds: 1));
      repository.responses.first.complete({'min_app_version': '1.0.1+16'});
      await tester.pump(const Duration(milliseconds: 1));
      expect(gate().status, AppVersionGateStatus.updateRequired);
      expect(repository.responses, hasLength(2));
    },
  );

  testWidgets('disposing pending attempt cancels and ignores platform result', (
    tester,
  ) async {
    initialize();
    container.invalidate(appVersionCheckProvider);
    version.complete('1.0.1+16');
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.responses, hasLength(1));
    container.dispose();
    expect(repository.tokens.single.isCancelled, isTrue);
    repository.responses.single.complete({'min_app_version': '1.0.1+17'});
    await tester.pump(const Duration(milliseconds: 1));
    // Replace disposed container so teardown remains safe.
    container = ProviderContainer();
  });
}
