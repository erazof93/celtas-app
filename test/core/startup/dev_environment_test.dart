import 'dart:io';

import 'package:celtas_mobile/core/config/app_environment.dart';
import 'package:celtas_mobile/core/startup/app_preparation_controller.dart';
import 'package:celtas_mobile/core/startup/dev_preparation.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/firebase_options.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, String> fixture() => {
  'ENVIRONMENT': 'dev',
  'DEV_SERVICES_AUTHORIZED': 'true',
  'API_BASE_URL': 'https://dev.example.invalid',
  'FIREBASE_PROJECT_ID': 'test-only-project',
  'FIREBASE_MESSAGING_SENDER_ID': '123456',
  'FIREBASE_APP_ID': '1:123456:android:test-only',
  'FIREBASE_API_KEY': 'not-a-real-key',
  'GOOGLE_SERVER_CLIENT_ID': '123456-test.apps.googleusercontent.com',
};

class _RecordingTransport implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'DEV prevents FCM registration and logout deletion before transport; ordinary clients remain unaffected',
    () async {
      final transport = _RecordingTransport();
      final dev = Dio()..httpClientAdapter = transport;
      restrictDevBackend(dev, 'https://dev.example.invalid');
      final repository = NotificationRepository(dev);
      await expectLater(
        repository.updateFcmToken('test-only-token'),
        throwsA(isA<Exception>()),
      );
      await expectLater(repository.clearFcmToken(), throwsA(isA<Exception>()));
      expect(transport.calls, 0);
      dev.close();

      final normal = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = transport;
      final ordinaryRepository = NotificationRepository(normal);
      await ordinaryRepository.updateFcmToken('test-only-token');
      await ordinaryRepository.clearFcmToken();
      expect(transport.calls, 2);
      normal.close();
    },
  );
  test(
    'DEV rejects another API origin and redirect overrides before transport',
    () async {
      final dio = Dio();
      restrictDevBackend(dio, 'https://dev.example.invalid');
      expect(dio.options.followRedirects, false);
      await expectLater(
        dio.get('https://backend-celtas.onrender.com/users/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await expectLater(
        dio.get('/users/me', options: Options(followRedirects: true)),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      dio.close(force: true);
    },
  );
  test(
    'production selection remains unflavored and explicit DEV requires both guards',
    () {
      expect(
        selectEnvironment(flavor: null, dev: false),
        AppEnvironment.production,
      );
      expect(selectEnvironment(flavor: 'dev', dev: true), AppEnvironment.dev);
      for (final choice in [(null, true), ('dev', false), ('qa', true)]) {
        expect(
          () => selectEnvironment(flavor: choice.$1, dev: choice.$2),
          throwsA(isA<ConfigurationException>()),
        );
      }
    },
  );

  test('valid DEV selects exclusively supplied Firebase options', () {
    final config = DevConfiguration(fixture());
    expect(config.firebase.projectId, 'test-only-project');
    expect(config.firebase.appId, '1:123456:android:test-only');
  });

  test('missing or incomplete DEV configuration fails closed', () {
    expect(() => DevConfiguration({}), throwsA(isA<ConfigurationException>()));
    for (final key in fixture().keys) {
      expect(
        () => DevConfiguration(fixture()..remove(key)),
        throwsA(isA<ConfigurationException>()),
        reason: key,
      );
    }
  });

  test('production endpoints and invalid URLs are rejected', () {
    for (final endpoint in [
      'https://backend-celtas.onrender.com',
      'https://BACKEND-CELTAS.ONRENDER.COM./api',
      'http://dev.example.invalid',
      'https://user:password@dev.example.invalid',
      'not a URL',
    ]) {
      expect(
        () => DevConfiguration(fixture()..['API_BASE_URL'] = endpoint),
        throwsA(isA<ConfigurationException>()),
      );
    }
  });

  test(
    'production Firebase project, sender and API key are rejected separately',
    () {
      for (final entry in {
        'FIREBASE_PROJECT_ID': DefaultFirebaseOptions.android.projectId,
        'FIREBASE_MESSAGING_SENDER_ID':
            DefaultFirebaseOptions.android.messagingSenderId,
        'FIREBASE_API_KEY': DefaultFirebaseOptions.android.apiKey,
      }.entries) {
        expect(
          () => DevConfiguration(fixture()..[entry.key] = entry.value),
          throwsA(isA<ConfigurationException>()),
        );
      }
      expect(
        () =>
            DevConfiguration(fixture()..['DEV_SERVICES_AUTHORIZED'] = 'false'),
        throwsA(isA<ConfigurationException>()),
      );
    },
  );

  testWidgets(
    'invalid DEV never initializes Firebase or mounts providers; retry is recoverable',
    (tester) async {
      for (final configuration in [
        '',
        'ENVIRONMENT=dev',
        fixture().entries
            .map(
              (e) =>
                  '${e.key}=${e.key == 'API_BASE_URL' ? 'https://backend-celtas.onrender.com' : e.value}',
            )
            .join('\n'),
      ]) {
        var remoteCalls = 0;
        var storageCalls = 0;
        final controller = devPreparation(
          flavor: 'dev',
          enabled: true,
          configuration: configuration,
          packageId: () async => 'com.celtas.celtas_mobile.dev',
          initializeFirebase: (_) async {
            remoteCalls++;
          },
          loadPreferences: () async {
            storageCalls++;
            return SharedPreferences.getInstance();
          },
        );
        await controller.prepare();
        expect(controller.status, AppPreparationStatus.error);
        expect(controller.errorMessage, contains('DEV'));
        expect(controller.container, isNull);
        expect(controller.notifications, isNull);
        await controller.prepare();
        expect(remoteCalls, 0);
        expect(storageCalls, 0);
        controller.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'validated DEV prepares real storage before explicit Firebase; repeated preparation is unique',
    (tester) async {
      SharedPreferences.setMockInitialValues({'cart_v1': 'retained-fixture'});
      var calls = 0;
      var reads = 0;
      final controller = devPreparation(
        flavor: 'dev',
        enabled: true,
        configuration: fixture().entries
            .map((e) => '${e.key}=${e.value}')
            .join('\n'),
        packageId: () async => 'com.celtas.celtas_mobile.dev',
        loadPreferences: () async {
          reads++;
          return SharedPreferences.getInstance();
        },
        initializeFirebase: (options) async {
          expect(reads, 1);
          expect(options.projectId, 'test-only-project');
          calls++;
        },
      );
      await Future.wait([controller.prepare(), controller.prepare()]);
      expect(controller.status, AppPreparationStatus.ready);
      expect(controller.container, isNotNull);
      expect(controller.notifications, isNull);
      await controller.prepare();
      expect(calls, 1);
      expect(reads, 1);
      expect(
        (await SharedPreferences.getInstance()).getString('cart_v1'),
        'retained-fixture',
      );
      controller.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('wrong native package stops DEV before Firebase', (tester) async {
    var calls = 0;
    final controller = devPreparation(
      flavor: 'dev',
      enabled: true,
      configuration: fixture().entries
          .map((e) => '${e.key}=${e.value}')
          .join('\n'),
      packageId: () async => 'com.celtas.celtas_mobile',
      initializeFirebase: (_) async {
        calls++;
      },
    );
    await controller.prepare();
    expect(controller.status, AppPreparationStatus.error);
    expect(calls, 0);
    controller.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test(
    'Android production identity and QA isolation guards remain present',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "com.celtas.celtas_mobile"'));
      expect(gradle, contains('applicationIdSuffix = ".qa"'));
      expect(
        gradle,
        contains('variant.buildType == "debug" && qaEnabled && qaTarget'),
      );
      expect(gradle, contains('versionCode = flutter.versionCode'));
      expect(gradle, contains('versionName = flutter.versionName'));
      final qa = File(
        'android/app/src/qaDebug/AndroidManifest.xml',
      ).readAsStringSync();
      expect(qa, contains('android.permission.INTERNET" tools:node="remove"'));
      expect(qa, contains('Celtas QA'));
      final dev = File(
        'android/app/src/devDebug/AndroidManifest.xml',
      ).readAsStringSync();
      expect(dev, contains('Celtas DEV'));
      expect(dev, contains('FirebaseInitProvider" tools:node="remove"'));
    },
  );
}
