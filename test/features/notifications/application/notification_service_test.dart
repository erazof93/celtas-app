import 'dart:async';

import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/auth/application/auth_controller.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/auth/data/models/user.dart';
import 'package:celtas_mobile/features/notifications/application/notification_platform.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/application/notification_service.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/notifications/data/notification_history_repository.dart';
import 'package:celtas_mobile/features/notifications/data/notification_permission_repository.dart';
import 'package:celtas_mobile/features/notifications/data/notification_repository.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_screen.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeNotificationPlatform implements NotificationPlatform {
  FakeNotificationPlatform() {
    incoming = StreamController.broadcast(
      sync: true,
      onListen: () => messageListeners++,
    );
    opened = StreamController.broadcast(
      sync: true,
      onListen: () => openedListeners++,
    );
    tokens = StreamController.broadcast(
      sync: true,
      onListen: () => tokenListeners++,
    );
  }
  late final StreamController<RemoteMessage> incoming;
  late final StreamController<RemoteMessage> opened;
  late final StreamController<String> tokens;
  int messageListeners = 0;
  int openedListeners = 0;
  int tokenListeners = 0;
  int localCalls = 0;
  int permissionCalls = 0;
  int tokenCalls = 0;
  int initialCalls = 0;
  int localInitialCalls = 0;
  Future<void> Function() local = () async {};
  Future<String?> Function() token = () async => 'device-token';
  Future<AuthorizationStatus>? permission;
  Future<RemoteMessage?> initial = Future.value();
  Future<NotificationResponse?> localInitial = Future.value();
  AuthorizationStatus status = AuthorizationStatus.notDetermined;
  final shown = <RemoteMessage>[];
  void Function(NotificationResponse)? onTap;
  @override
  Stream<RemoteMessage> get messages => incoming.stream;
  @override
  Stream<RemoteMessage> get openedMessages => opened.stream;
  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Future<void> initializeLocal(
    void Function(NotificationResponse) onTap,
  ) async {
    localCalls++;
    this.onTap = onTap;
    await local();
  }

  @override
  Future<NotificationResponse?> initialLocalResponse() {
    localInitialCalls++;
    return localInitial;
  }

  @override
  Future<RemoteMessage?> initialMessage() {
    initialCalls++;
    return initial;
  }

  @override
  Future<AuthorizationStatus> requestPermission() async {
    permissionCalls++;
    return status =
        await (permission ?? Future.value(AuthorizationStatus.authorized));
  }

  @override
  Future<String?> getToken() {
    tokenCalls++;
    return token();
  }

  @override
  Future<void> showLocal(RemoteMessage message) async {
    shown.add(message);
  }

  Future<void> close() async {
    await Future.wait([incoming.close(), opened.close(), tokens.close()]);
  }
}

class _Auth extends AuthController {
  _Auth(this.initial);
  final AuthState initial;
  int generation = 0;
  @override
  AuthState build() => initial;
  @override
  int get revision => generation;
  @override
  bool get canRefresh => state.status == AuthStatus.authenticated;
  void replace(AuthState next) {
    generation++;
    state = next;
  }
}

class _Gate extends AppVersionGateController {
  _Gate(this.initial);
  final AppVersionGateState initial;
  @override
  AppVersionGateState build() => initial;
  @override
  void recheck() {}
  void replace(AppVersionGateStatus status) =>
      state = AppVersionGateState(status, minVersion: '1.0.1+17');
}

class _Permission implements NotificationPermissionRepository {
  _Permission(this.platform);
  final FakeNotificationPlatform platform;
  @override
  Future<AuthorizationStatus> getStatus() async => platform.status;
  @override
  Future<AuthorizationStatus> requestPermission() =>
      platform.requestPermission();
  @override
  Future<bool> openSystemSettings() async => false;
}

class _History extends NotificationHistoryRepository {
  List<NotificationHistoryItem> items = [];
  @override
  Future<List<NotificationHistoryItem>> load() async => [];
  @override
  Future<void> save(List<NotificationHistoryItem> items) async {
    this.items = items;
  }
}

class _Repository extends NotificationRepository {
  _Repository() : super(Dio());
  final uploaded = <String>[];
  final cancellations = <CancelToken>[];
  Future<void> Function() upload = () async {};
  @override
  Future<void> updateFcmToken(
    String fcmToken, {
    CancelToken? cancelToken,
  }) async {
    uploaded.add(fcmToken);
    cancellations.add(cancelToken!);
    await upload();
  }
}

AuthState authenticated(String id) => AuthState.authenticated(
  accessToken: 'test-access-$id',
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
RemoteMessage order(String id) => RemoteMessage(
  messageId: id,
  data: {'orderId': id},
  notification: const RemoteNotification(title: 'Pedido', body: 'Actualizado'),
);

void main() {
  late FakeNotificationPlatform platform;
  late NotificationService service;
  late ProviderContainer container;
  late GoRouter router;
  late _Repository repository;
  late _History history;
  late List<Object> errors;
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(envString: 'API_BASE_URL=https://example.invalid');
  });
  setUp(() {
    platform = FakeNotificationPlatform();
    errors = [];
  });

  Future<void> attach({
    AuthState? auth,
    void Function()? beforeAttach,
    AppVersionGateStatus gate = AppVersionGateStatus.allowed,
  }) async {
    service = NotificationService(
      platform: platform,
      onError: (error, _) => errors.add(error),
    );
    beforeAttach?.call();
    repository = _Repository();
    history = _History();
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('APP LISTA')),
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (_, state) =>
              Scaffold(body: Text('PEDIDO ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/coupons',
          builder: (_, _) => const Scaffold(body: Text('CUPONES')),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        routerProvider.overrideWithValue(router),
        authControllerProvider.overrideWith(
          () => _Auth(auth ?? authenticated('a')),
        ),
        appVersionGateProvider.overrideWith(
          () => _Gate(AppVersionGateState(gate, minVersion: '1.0.1+17')),
        ),
        notificationRepositoryProvider.overrideWithValue(repository),
        notificationHistoryRepositoryProvider.overrideWithValue(history),
        notificationPermissionRepositoryProvider.overrideWithValue(
          _Permission(platform),
        ),
      ],
    );
    addTearDown(() async {
      service.dispose();
      container.dispose();
      router.dispose();
      await platform.close();
    });
    await service.init(container);
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CeltasApp(notifications: service),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  testWidgets(
    'repeated init attaches listeners once and syncs already authenticated session',
    (tester) async {
      await attach();
      await service.init(container);
      service.captureEvents();
      expect(platform.permissionCalls, 0);
      await mount(tester);
      await settle(tester);
      await service.init(container);
      await tester.pump();
      expect(platform.messageListeners, 1);
      expect(platform.openedListeners, 1);
      expect(platform.tokenListeners, 1);
      expect(platform.localCalls, 1);
      expect(platform.initialCalls, 1);
      expect(platform.localInitialCalls, 1);
      expect(platform.permissionCalls, 1);
      expect(repository.uploaded, ['device-token']);
    },
  );

  testWidgets('pending permission never blocks UI or starts token requests', (
    tester,
  ) async {
    platform.permission = Completer<AuthorizationStatus>().future;
    await attach();
    await mount(tester);
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('APP LISTA'), findsOneWidget);
    expect(platform.permissionCalls, 1);
    expect(platform.tokenCalls, 0);
    await service.init(container);
    service.setRouterReady(true);
    expect(platform.permissionCalls, 1);
    expect(repository.uploaded, isEmpty);
    expect(errors, isEmpty);
  });

  testWidgets('denied permission preserves app and notification destinations', (
    tester,
  ) async {
    platform.permission = Future.value(AuthorizationStatus.denied);
    platform.initial = Future.value(order('denied'));
    await attach();
    await mount(tester);
    await settle(tester);
    expect(find.text('PEDIDO denied'), findsOneWidget);
    expect(platform.tokenCalls, 0);
    expect(repository.uploaded, isEmpty);
    expect(history.items, hasLength(1));
  });

  testWidgets('getToken errors are captured and the next event can retry', (
    tester,
  ) async {
    platform.token = () async => throw StateError('getToken');
    await attach();
    await mount(tester);
    await settle(tester);
    expect(find.text('APP LISTA'), findsOneWidget);
    expect(errors, hasLength(1));
    expect(repository.uploaded, isEmpty);
    platform.token = () async => 'recovered-token';
    ApiClient.instance.onSessionRefreshed!();
    await tester.pump();
    expect(repository.uploaded, ['recovered-token']);
    expect(platform.tokenCalls, 2);
  });

  testWidgets('token wait has a global budget; late result cannot upload', (
    tester,
  ) async {
    final pending = Completer<String?>();
    platform.token = () => pending.future;
    await attach();
    await mount(tester);
    await tester.pump(const Duration(seconds: 20));
    expect(errors.whereType<TimeoutException>(), hasLength(1));
    expect(find.text('APP LISTA'), findsOneWidget);
    pending.complete('late-token');
    await tester.pump();
    expect(repository.uploaded, isEmpty);
    expect(platform.tokenCalls, 1);
  });

  testWidgets(
    'retry shares pending native getToken instead of launching a duplicate',
    (tester) async {
      final pending = Completer<String?>();
      platform.token = () => pending.future;
      await attach();
      await mount(tester);
      await tester.pump(const Duration(seconds: 20));
      ApiClient.instance.onSessionRefreshed!();
      await tester.pump();
      expect(platform.tokenCalls, 1);
      pending.complete('shared-token');
      await tester.pump();
      expect(repository.uploaded, ['shared-token']);
    },
  );

  testWidgets(
    'initial message arriving late navigates once after router readiness',
    (tester) async {
      final pending = Completer<RemoteMessage?>();
      platform.initial = pending.future;
      await attach();
      await service.init(container);
      await mount(tester);
      await settle(tester);
      pending.complete(order('late'));
      await settle(tester);
      expect(find.text('PEDIDO late'), findsOneWidget);
      expect(platform.initialCalls, 1);
      expect(service.pendingDestinations, 0);
      platform.opened.add(order('late'));
      await settle(tester);
      expect(history.items, hasLength(1));
      expect(service.pendingDestinations, 0);
    },
  );

  testWidgets('initial notification is held until the real router is mounted', (
    tester,
  ) async {
    platform.initial = Future.value(order('before-router'));
    await attach();
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(service.pendingDestinations, 1);
    await mount(tester);
    await settle(tester);
    expect(find.text('PEDIDO before-router'), findsOneWidget);
  });

  testWidgets(
    'session error keeps pending destination until restoration succeeds',
    (tester) async {
      platform.initial = Future.value(order('restore'));
      await attach(auth: const AuthState.error());
      await mount(tester);
      await settle(tester);
      expect(service.pendingDestinations, 1);
      expect(find.text('APP LISTA'), findsOneWidget);
      (container.read(authControllerProvider.notifier) as _Auth).replace(
        authenticated('a'),
      );
      await settle(tester);
      expect(find.text('PEDIDO restore'), findsOneWidget);
      expect(service.pendingDestinations, 0);
    },
  );

  testWidgets(
    'unauthenticated session retains destination for an authorized login',
    (tester) async {
      await attach(auth: const AuthState.unauthenticated());
      await mount(tester);
      platform.opened.add(order('login'));
      await settle(tester);
      expect(service.pendingDestinations, 1);
      (container.read(authControllerProvider.notifier) as _Auth).replace(
        authenticated('a'),
      );
      await settle(tester);
      expect(find.text('PEDIDO login'), findsOneWidget);
    },
  );

  testWidgets(
    'UpdateRequired prevents notification navigation and permission prompt',
    (tester) async {
      platform.initial = Future.value(order('blocked'));
      await attach(gate: AppVersionGateStatus.updateRequired);
      await mount(tester);
      await settle(tester);
      platform.opened.add(
        const RemoteMessage(messageId: 'coupon', data: {'couponCode': 'TEST'}),
      );
      await settle(tester);
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(service.pendingDestinations, 2);
      expect(platform.permissionCalls, 0);
      expect(platform.tokenCalls, 0);
      (container.read(appVersionGateProvider.notifier) as _Gate).replace(
        AppVersionGateStatus.allowed,
      );
      await settle(tester);
      expect(find.text('CUPONES'), findsOneWidget);
      expect(service.pendingDestinations, 0);
      expect(container.read(routerProvider), same(router));
    },
  );

  testWidgets(
    'block confirmed while message is pending still prevents late navigation',
    (tester) async {
      final pending = Completer<RemoteMessage?>();
      platform.initial = pending.future;
      await attach();
      await mount(tester);
      await settle(tester);
      (container.read(appVersionGateProvider.notifier) as _Gate).replace(
        AppVersionGateStatus.updateRequired,
      );
      await settle(tester);
      pending.complete(order('late-blocked'));
      await settle(tester);
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
      expect(service.pendingDestinations, 1);
      expect(router.routeInformationProvider.value.uri.path, '/');
    },
  );

  testWidgets(
    'foreground notification is stored and local tap follows the same gate',
    (tester) async {
      await attach();
      await mount(tester);
      await settle(tester);
      platform.incoming.add(order('foreground'));
      await settle(tester);
      expect(platform.shown, hasLength(1));
      expect(history.items, hasLength(1));
      expect(router.routeInformationProvider.value.uri.path, '/');
      platform.onTap!(
        const NotificationResponse(
          id: 42,
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: '{"orderId":"foreground"}',
        ),
      );
      await settle(tester);
      expect(find.text('PEDIDO foreground'), findsOneWidget);
    },
  );

  testWidgets('local notification that launched the process is captured once', (
    tester,
  ) async {
    platform.localInitial = Future.value(
      const NotificationResponse(
        id: 42,
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '{"orderId":"local-initial"}',
      ),
    );
    await attach();
    await mount(tester);
    await settle(tester);
    expect(find.text('PEDIDO local-initial'), findsOneWidget);
    expect(platform.localInitialCalls, 1);
    await service.init(container);
    await settle(tester);
    expect(platform.localInitialCalls, 1);
  });

  testWidgets(
    'valid token refresh replaces stale native wait without another getToken',
    (tester) async {
      final pending = Completer<String?>();
      platform.token = () => pending.future;
      await attach();
      await mount(tester);
      await tester.pump();
      platform.tokens.add('rotated-token');
      await tester.pump();
      expect(repository.uploaded, ['rotated-token']);
      expect(platform.tokenCalls, 1);
      pending.complete('obsolete-token');
      await tester.pump();
      expect(repository.uploaded, ['rotated-token']);
    },
  );

  testWidgets(
    'authentication change cancels upload and syncs the current account',
    (tester) async {
      final pending = Completer<void>();
      await attach();
      repository.upload = () => pending.future;
      await mount(tester);
      await tester.pump();
      expect(repository.uploaded, hasLength(1));
      (container.read(authControllerProvider.notifier) as _Auth).replace(
        authenticated('b'),
      );
      await tester.pump();
      expect(repository.cancellations.first.isCancelled, isTrue);
      pending.complete();
      await tester.pump();
      expect(repository.uploaded, hasLength(2));
      expect(container.read(authControllerProvider).user?.id, 'b');
    },
  );

  testWidgets(
    'backend error is captured without changing session or navigation',
    (tester) async {
      await attach();
      repository.upload = () async =>
          throw const ApiException('unavailable', statusCode: 503);
      await mount(tester);
      await settle(tester);
      expect(errors, hasLength(1));
      expect(find.text('APP LISTA'), findsOneWidget);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
    },
  );

  testWidgets('pending local initialization is shared and never blocks app', (
    tester,
  ) async {
    final pending = Completer<void>();
    platform.local = () => pending.future;
    await attach();
    await mount(tester);
    await service.init(container);
    platform.incoming.add(order('local-pending'));
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('APP LISTA'), findsOneWidget);
    expect(platform.localCalls, 1);
    expect(platform.shown, isEmpty);
    pending.complete();
    await tester.pump();
    expect(platform.shown, hasLength(1));
    expect(platform.localInitialCalls, 1);
  });

  testWidgets(
    'local initialization failure is captured and retry has no duplicate listeners',
    (tester) async {
      platform.local = () async => throw StateError('local failed');
      await attach();
      await mount(tester);
      expect(errors, hasLength(1));
      platform.local = () async {};
      await service.init(container);
      await tester.pump();
      expect(platform.localCalls, 2);
      expect(platform.messageListeners, 1);
      expect(platform.openedListeners, 1);
      expect(platform.tokenListeners, 1);
    },
  );

  testWidgets(
    'permission and initial message failures are caught without blocking app',
    (tester) async {
      final permission = Completer<AuthorizationStatus>();
      final initial = Completer<RemoteMessage?>();
      platform.permission = permission.future;
      platform.initial = initial.future;
      await attach();
      await mount(tester);
      permission.completeError(StateError('permission failed'));
      initial.completeError(StateError('initial failed'));
      await settle(tester);
      expect(find.text('APP LISTA'), findsOneWidget);
      expect(errors, hasLength(2));
      expect(repository.uploaded, isEmpty);
      platform.permission = Future.value(AuthorizationStatus.authorized);
      platform.initial = Future.value(order('initial-retry'));
      await service.init(container);
      service.setRouterReady(true);
      await settle(tester);
      expect(find.text('PEDIDO initial-retry'), findsOneWidget);
      expect(repository.uploaded, ['device-token']);
    },
  );

  testWidgets('simultaneous refresh triggers share one backend upload', (
    tester,
  ) async {
    final pending = Completer<void>();
    await attach();
    repository.upload = () => pending.future;
    await mount(tester);
    ApiClient.instance.onSessionRefreshed!();
    ApiClient.instance.onSessionRefreshed!();
    service.setRouterReady(true);
    await service.init(container);
    await tester.pump();
    expect(repository.uploaded, hasLength(1));
    pending.complete();
    await tester.pump();
    expect(repository.uploaded, hasLength(1));
  });

  testWidgets('confirmed update blocks a late token upload', (tester) async {
    final pending = Completer<String?>();
    platform.token = () => pending.future;
    await attach();
    await mount(tester);
    (container.read(appVersionGateProvider.notifier) as _Gate).replace(
      AppVersionGateStatus.updateRequired,
    );
    await tester.pump();
    pending.complete('late-token');
    await tester.pump();
    expect(repository.uploaded, isEmpty);
    expect(find.byType(ForceUpdateScreen), findsOneWidget);
  });

  testWidgets(
    'events captured during preparation wait for container and router',
    (tester) async {
      await attach(
        beforeAttach: () {
          service.captureEvents();
          service.captureEvents();
          platform.opened.add(order('before-container'));
          expect(service.pendingDestinations, 1);
        },
      );
      expect(service.pendingDestinations, 1);
      await mount(tester);
      await settle(tester);
      expect(find.text('PEDIDO before-container'), findsOneWidget);
      expect(history.items, hasLength(1));
      expect(platform.messageListeners, 1);
      expect(platform.openedListeners, 1);
    },
  );
}
