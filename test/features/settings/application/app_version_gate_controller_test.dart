import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/data/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsRepository extends SettingsRepository {
  _SettingsRepository(this.fetch) : super(Dio());
  final Future<Map<String, dynamic>> Function() fetch;

  @override
  Future<Map<String, dynamic>> getPublicSettings({CancelToken? cancelToken}) =>
      fetch();
}

void main() {
  late ProviderContainer container;
  late Future<Map<String, dynamic>> Function() fetch;
  late String installed;
  late int versionReads;
  late int requests;

  setUp(() {
    installed = '1.0.1+16';
    versionReads = 0;
    requests = 0;
    fetch = () async => {'min_app_version': '1.0.1+17'};
    container = ProviderContainer(
      overrides: [
        currentAppVersionProvider.overrideWith((ref) async {
          versionReads++;
          return installed;
        }),
        settingsRepositoryProvider.overrideWithValue(
          _SettingsRepository(() {
            requests++;
            return fetch();
          }),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> settle() async {
    container.read(appVersionGateProvider);
    // El Future también se consume para observar el estado tras AsyncError.
    try {
      await container.read(appVersionCheckProvider.future);
    } catch (_) {}
    await container.pump();
  }

  test(
    'loading inicial bloquea; build inferior confirma UpdateRequired',
    () async {
      expect(
        container.read(appVersionGateProvider).status,
        AppVersionGateStatus.loading,
      );
      expect(container.read(appVersionGateProvider).blocksNavigation, isTrue);
      await settle();
      final gate = container.read(appVersionGateProvider);
      expect(gate.status, AppVersionGateStatus.updateRequired);
      expect(gate.minVersion, '1.0.1+17');
    },
  );

  for (final build in [17, 18]) {
    test('build $build igual/superior permite navegar', () async {
      installed = '1.0.1+$build';
      await settle();
      expect(
        container.read(appVersionGateProvider).status,
        AppVersionGateStatus.allowed,
      );
      expect(container.read(appVersionGateProvider).blocksNavigation, isFalse);
    });
  }

  test('error inicial de red permite continuar en Error', () async {
    fetch = () async => throw const ApiException('sin conexión');
    await settle();
    expect(
      container.read(appVersionGateProvider).status,
      AppVersionGateStatus.error,
    );
    expect(container.read(appVersionGateProvider).blocksNavigation, isFalse);
  });

  test('error de plataforma inicial permite continuar', () async {
    final platformContainer = ProviderContainer(
      overrides: [
        currentAppVersionProvider.overrideWith(
          (ref) async => throw StateError('plataforma'),
        ),
      ],
    );
    addTearDown(platformContainer.dispose);
    platformContainer.listen(appVersionGateProvider, (_, _) {});
    await expectLater(
      platformContainer.read(appVersionCheckProvider.future),
      throwsStateError,
    );
    await platformContainer.pump();
    expect(
      platformContainer.read(appVersionGateProvider).status,
      AppVersionGateStatus.error,
    );
  });

  test(
    'loading, red y datos inválidos posteriores conservan el bloqueo',
    () async {
      await settle();
      final pending = Completer<Map<String, dynamic>>();
      fetch = () => pending.future;
      container.read(appVersionGateProvider.notifier).recheck();
      await container.pump();
      expect(
        container.read(appVersionGateProvider).status,
        AppVersionGateStatus.updateRequired,
      );
      pending.completeError(const ApiException('timeout'));
      await settle();
      expect(
        container.read(appVersionGateProvider).status,
        AppVersionGateStatus.updateRequired,
      );

      for (final value in [null, '', '1.0.1', '1.0.1+abc', 17, <String>[]]) {
        fetch = () async => {'min_app_version': value};
        container.read(appVersionGateProvider.notifier).recheck();
        await settle();
        expect(
          container.read(appVersionGateProvider).status,
          AppVersionGateStatus.updateRequired,
        );
        expect(container.read(appVersionGateProvider).minVersion, '1.0.1+17');
      }
    },
  );

  test('solo una comparación compatible levanta el bloqueo', () async {
    await settle();
    installed = '1.0.1+17';
    container.read(appVersionGateProvider.notifier).recheck();
    await settle();
    expect(
      container.read(appVersionGateProvider).status,
      AppVersionGateStatus.allowed,
    );
    expect(versionReads, 2);
    expect(requests, 2);
  });

  test(
    'rechequeos simultáneos comparten una consulta y mantienen Allowed',
    () async {
      installed = '1.0.1+17';
      await settle();
      final pending = Completer<Map<String, dynamic>>();
      fetch = () => pending.future;
      final controller = container.read(appVersionGateProvider.notifier);
      controller.recheck();
      controller.recheck();
      controller.recheck();
      await container.pump();
      expect(requests, 2);
      expect(versionReads, 2);
      expect(
        container.read(appVersionGateProvider).status,
        AppVersionGateStatus.allowed,
      );
      pending.complete({'min_app_version': '1.0.1+18'});
      await settle();
      expect(
        container.read(appVersionGateProvider).status,
        AppVersionGateStatus.updateRequired,
      );
    },
  );
}
