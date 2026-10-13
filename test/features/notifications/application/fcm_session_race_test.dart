import 'dart:async';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/features/addresses/data/address_selection_storage.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/auth_repository.dart';
import 'package:celtas_mobile/features/auth/data/models/auth_tokens.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/application/notification_service.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'notification_service_test.dart' show FakeNotificationPlatform;

class _Storage extends Mock implements FlutterSecureStorage {}

AuthTokens _tokens(String id) => AuthTokens(
  accessToken: id,
  refreshToken: 'refresh-$id',
  user: User(
    id: id,
    email: '$id@example.invalid',
    fullName: id,
    provider: UserProvider.local,
    totalSpent: 0,
    role: UserRole.cliente,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
);

class _AuthRepository extends AuthRepository {
  _AuthRepository(super.dio, super.storage);
  Completer<AuthTokens>? loginPending;
  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async =>
      loginPending == null ? _tokens(email) : await loginPending!.future;
  @override
  Future<void> signOutFromGoogle() async {}
}

class _AddressStorage extends AddressSelectionStorage {
  @override
  Future<void> clear() async {}
}

class _Gate extends AppVersionGateController {
  @override
  AppVersionGateState build() =>
      const AppVersionGateState(AppVersionGateStatus.allowed);
}

/// Models a server that accepted PATCH and can commit it after client cancel.
/// No real backend is contacted. Identity is captured at request dispatch.
class _Server extends NotificationRepository {
  _Server() : super(Dio());
  final tokens = <String, String?>{};
  final pending = <Completer<void>>[];
  final cancellations = <CancelToken>[];
  Completer<void>? deletePending;
  bool deleteFails = false;
  int deletes = 0;
  bool? cancelledAtDelete;
  @override
  Future<void> updateFcmToken(String token, {CancelToken? cancelToken}) async {
    final user = ApiClient.instance.session!.accessToken!;
    final operation = Completer<void>();
    pending.add(operation);
    cancellations.add(cancelToken!);
    await operation.future;
    tokens[user] =
        token; // Intentionally ignores cancellation after acceptance.
  }

  @override
  Future<void> clearFcmToken() async {
    final user = ApiClient.instance.session!.accessToken!;
    deletes++;
    cancelledAtDelete = cancellations.isEmpty
        ? null
        : cancellations.last.isCancelled;
    if (deletePending != null) await deletePending!.future;
    if (deleteFails) throw StateError('delete failed');
    tokens[user] = null;
  }
}

void main() {
  late ProviderContainer container;
  late NotificationService service;
  late FakeNotificationPlatform platform;
  late _Server server;
  late _AuthRepository repository;
  setUpAll(
    () => dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example.invalid',
    ),
  );

  Future<void> start(WidgetTester tester, {Future<String?>? tokenRead}) async {
    final storage = _Storage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    repository = _AuthRepository(Dio(), storage);
    server = _Server();
    platform = FakeNotificationPlatform();
    if (tokenRead != null) platform.token = () => tokenRead;
    service = NotificationService(platform: platform);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        notificationRepositoryProvider.overrideWithValue(server),
        addressSelectionStorageProvider.overrideWithValue(_AddressStorage()),
        appVersionGateProvider.overrideWith(_Gate.new),
        notificationPermissionProvider.overrideWith(() => _Permission()),
      ],
    );
    addTearDown(() async {
      service.dispose();
      container.dispose();
      await platform.close();
    });
    final auth = container.read(authControllerProvider.notifier);
    await tester.pump();
    await auth.login(email: 'a', password: 'test');
    await service.init(container);
    service.setRouterReady(true);
    await tester.pump();
  }

  testWidgets(
    'accepted FCM PATCH can commit after logout DELETE: server boundary reproduction',
    (tester) async {
      await start(tester);
      expect(server.pending, hasLength(1));
      await container.read(authControllerProvider.notifier).logout();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(server.tokens['a'], isNull);
      expect(
        server.cancelledAtDelete,
        isTrue,
      ); // Cancel before DELETE, not after it.
      server.pending.single.complete();
      await tester.pump();
      expect(server.tokens['a'], 'device-token');
      expect(server.pending, hasLength(1));
    },
  );

  testWidgets('logout stops native token wait before any PATCH can be sent', (
    tester,
  ) async {
    final token = Completer<String?>();
    await start(tester, tokenRead: token.future);
    expect(server.pending, isEmpty);
    await container.read(authControllerProvider.notifier).logout();
    token.complete('late-native-token');
    await tester.pump();
    expect(server.pending, isEmpty);
    expect(server.deletes, 1);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  testWidgets(
    'rotation and silent refresh during DELETE cannot register again',
    (tester) async {
      await start(tester);
      server.deletePending = Completer<void>();
      final auth = container.read(authControllerProvider.notifier);
      final logout = auth.logout();
      platform.tokens.add('rotated-during-logout');
      expect(
        await auth.commitRefreshedTokens(
          _tokens('a'),
          expectedRevision: auth.revision,
        ),
        isTrue,
      );
      ApiClient.instance.onSessionRefreshed!();
      await tester.pump();
      expect(server.pending, hasLength(1));
      expect(server.cancelledAtDelete, isTrue);
      server.deletePending!.complete();
      await logout;
      server.pending.single.complete();
      await tester.pump();
      expect(server.pending, hasLength(1));
    },
  );

  testWidgets(
    'account change cancels immediately and registers new user only after login completes',
    (tester) async {
      await start(tester);
      repository.loginPending = Completer<AuthTokens>();
      final login = container
          .read(authControllerProvider.notifier)
          .login(email: 'b', password: 'test');
      expect(server.cancellations.single.isCancelled, isTrue);
      platform.tokens.add('new-device-token');
      ApiClient.instance.onSessionRefreshed!();
      await tester.pump();
      expect(server.pending, hasLength(1));
      repository.loginPending!.complete(_tokens('b'));
      await login;
      await tester.pump();
      expect(server.pending, hasLength(2));
      server.pending.last.complete();
      server.pending.first.complete();
      await tester.pump();
      expect(server.tokens['b'], 'new-device-token');
      expect(
        server.tokens['a'],
        'device-token',
      ); // Accepted old request belongs to A, not B.
      expect(container.read(authControllerProvider).user?.id, 'b');
    },
  );

  testWidgets(
    'failed account change resumes token sync for the retained account',
    (tester) async {
      await start(tester);
      repository.loginPending = Completer<AuthTokens>();
      final login = container
          .read(authControllerProvider.notifier)
          .login(email: 'b', password: 'test');
      final result = login.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      expect(server.cancellations.single.isCancelled, isTrue);
      repository.loginPending!.completeError(
        StateError('transient login error'),
      );
      await tester.pump();
      expect(await result, isA<StateError>());
      expect(container.read(authControllerProvider).user?.id, 'a');
      expect(server.pending, hasLength(2));
      for (final pending in server.pending) {
        pending.complete();
      }
      await tester.pump();
    },
  );

  testWidgets(
    'DELETE failure still logs out locally without resuming old registration',
    (tester) async {
      await start(tester);
      server.deleteFails = true;
      await container.read(authControllerProvider.notifier).logout();
      expect(server.cancelledAtDelete, isTrue);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      platform.tokens.add('late-rotation');
      ApiClient.instance.onSessionRefreshed!();
      server.pending.single.complete();
      await tester.pump();
      expect(server.pending, hasLength(1));
      expect(server.deletes, 1);
    },
  );

  testWidgets('real auth silent token publication shares active FCM upload', (
    tester,
  ) async {
    await start(tester);
    final auth = container.read(authControllerProvider.notifier);
    expect(
      await auth.commitRefreshedTokens(
        _tokens('a'),
        expectedRevision: auth.revision,
      ),
      isTrue,
    );
    ApiClient.instance.onSessionRefreshed!();
    ApiClient.instance.onSessionRefreshed!();
    await service.init(container);
    await tester.pump();
    expect(server.pending, hasLength(1));
    server.pending.single.complete();
    await tester.pump();
  });
}

class _Permission extends NotificationPermissionNotifier {
  @override
  Future<AuthorizationStatus> build() async => AuthorizationStatus.authorized;
}
