import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/network/auth_session_bridge.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/core/startup/initialization_operation.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/notifications/application/notification_platform.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/application/notification_target.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Process-owned event capture. Native preparation, permission and token sync
/// are independent of UI preparation and never delay runApp or authentication.
class NotificationService {
  NotificationService({NotificationPlatform? platform, this.onError})
    : _platform = platform ?? DeviceNotificationPlatform() {
    _locals = InitializationOperation(
      () => _platform.initializeLocal(_onLocalNotificationTapped),
    );
    _initial = InitializationOperation(_platform.initialMessage);
    _localInitial = InitializationOperation(_platform.initialLocalResponse);
    _permission = InitializationOperation(_platform.requestPermission);
  }

  static final NotificationService instance = NotificationService();
  final NotificationPlatform _platform;
  final void Function(Object, StackTrace)? onError;
  late final InitializationOperation<void> _locals;
  late final InitializationOperation<RemoteMessage?> _initial;
  late final InitializationOperation<NotificationResponse?> _localInitial;
  late final InitializationOperation<AuthorizationStatus> _permission;
  ProviderContainer? _container;
  final _streams = <StreamSubscription<dynamic>>[];
  final _providers = <ProviderSubscription<dynamic>>[];
  final _history = Queue<RemoteMessage>();
  final _foreground = Queue<RemoteMessage>();
  final _invalidations = Queue<Map<String, dynamic>>();
  final _destinations = Queue<Map<String, dynamic>>();
  final _receivedIds = <String>{};
  final _tapIds = <String>{};
  final _localTapIds = <int>{};
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _disposed = false;
  bool _routerReady = false;
  bool _navigationScheduled = false;
  bool _savingHistory = false;
  bool _initialStarted = false;
  bool _localInitialStarted = false;
  bool _permissionStarted = false;
  bool _permissionGranted = false;
  bool _permissionListenerAttached = false;
  bool _syncWanted = false;
  int _tokenRevision = 0;
  String? _latestToken;
  Future<String?>? _nativeToken;
  _TokenSync? _sync;
  void Function()? _previousRefreshHook;
  late final void Function() _refreshHook = _requestTokenSync;
  void Function(AuthSessionBridge)? _previousActivityHook;
  late final void Function(AuthSessionBridge) _activityHook =
      _sessionActivityChanged;

  void _sessionActivityChanged(AuthSessionBridge owner) {
    final container = _container;
    if (_disposed ||
        container == null ||
        !identical(owner, container.read(authControllerProvider.notifier))) {
      return;
    }
    if (!container
        .read(authControllerProvider.notifier)
        .canRegisterNotifications) {
      _syncWanted = false;
      if (_sync != null) _finishSync(_sync!);
    } else {
      _requestTokenSync();
    }
  }

  int get pendingDestinations => _destinations.length;

  /// Safe before configuration/Firebase: these static streams do not consume
  /// providers or FirebaseMessaging.instance. Buffer until essentials are ready.
  void captureEvents() {
    if (_disposed) return;
    try {
      _messageSubscription ??= _platform.messages.listen(
        (m) => _receive(m, tapped: false),
        onError: _report,
      );
    } catch (error, stack) {
      _report(error, stack);
    }
    try {
      _openedSubscription ??= _platform.openedMessages.listen(
        (m) => _receive(m, tapped: true),
        onError: _report,
      );
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  Future<void> init(ProviderContainer container) async {
    if (_disposed) return;
    if (_container != null) {
      if (!identical(_container, container)) {
        throw StateError('Notification service already attached');
      }
      _captureInitial();
      unawaited(_prepareLocal());
      return;
    }
    _container = container;
    captureEvents();
    _providers.add(
      container.listen(authControllerProvider, (previous, next) {
        if (_sync != null && !_sameSession(_sync!)) _finishSync(_sync!);
        if (previous?.user?.id != next.user?.id ||
            previous?.status != AuthStatus.authenticated &&
                next.status == AuthStatus.authenticated) {
          _requestTokenSync();
        }
        _scheduleNavigation();
      }, fireImmediately: true),
    );
    _providers.add(
      container.listen(appVersionGateProvider, (_, next) {
        if (next.blocksNavigation) {
          _routerReady = false;
          if (_sync != null) {
            _syncWanted = true;
            _finishSync(_sync!);
          }
        }
        _scheduleNavigation();
      }, fireImmediately: true),
    );
    try {
      _streams.add(
        _platform.tokenRefresh.listen((token) {
          _latestToken = token;
          _tokenRevision++;
          // A valid token event can replace a stale getToken wait without
          // launching another native getToken operation or overlapping uploads.
          if (_sync != null && !_sync!.uploading) _finishSync(_sync!);
          _requestTokenSync();
        }, onError: _report),
      );
    } catch (error, stack) {
      _report(error, stack);
    }
    _previousRefreshHook = ApiClient.instance.onSessionRefreshed;
    ApiClient.instance.onSessionRefreshed = _refreshHook;
    _previousActivityHook = ApiClient.instance.onSessionActivityChanged;
    ApiClient.instance.onSessionActivityChanged = _activityHook;
    _captureInitial();
    unawaited(_prepareLocal());
    _drainCaptured();
  }

  Future<void> _prepareLocal() async {
    try {
      await _locals.run();
      if (_disposed) return;
      if (!_localInitialStarted) {
        _localInitialStarted = true;
        unawaited(_captureLocalInitial());
      }
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  void _captureInitial() {
    if (_initialStarted) return;
    _initialStarted = true;
    unawaited(
      _initial.run().then<void>(
        (message) {
          // A late initial message is an input, not an obsolete startup result.
          if (!_disposed && message != null) _receive(message, tapped: true);
        },
        onError: (Object error, StackTrace stack) {
          _initialStarted = false;
          _report(error, stack);
        },
      ),
    );
  }

  Future<void> _captureLocalInitial() async {
    try {
      final response = await _localInitial.run();
      if (!_disposed && response != null) _onLocalNotificationTapped(response);
    } catch (error, stack) {
      _localInitialStarted = false;
      _report(error, stack);
    }
  }

  /// Called only after the real router has been mounted behind the version gate.
  void setRouterReady(bool ready) {
    if (_disposed) return;
    _routerReady = ready;
    if (!ready || _container == null) return;
    _captureInitial();
    _requestPermission();
    _ensureTokenSync();
    _scheduleNavigation();
  }

  void _requestPermission() {
    if (_permissionStarted) return;
    _permissionStarted = true;
    unawaited(
      _permission.run().then<void>(
        (status) {
          if (!_disposed) {
            _setPermission(status);
            _listenPermissionChanges();
          }
        },
        onError: (Object error, StackTrace stack) {
          _permissionStarted = false;
          _report(error, stack);
        },
      ),
    );
  }

  void _listenPermissionChanges() {
    if (_permissionListenerAttached || _disposed) return;
    _permissionListenerAttached = true;
    // Start observing after the prompt, so an older initial status query
    // cannot override the prompt's result. Profile/settings keep this current.
    _providers.add(
      _container!.listen<AsyncValue<AuthorizationStatus>>(
        notificationPermissionProvider,
        (_, next) {
          final value = next.valueOrNull;
          if (value != null && !next.isLoading) _setPermission(value);
        },
      ),
    );
  }

  void _setPermission(AuthorizationStatus status) {
    final granted =
        status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    if (granted && !_permissionGranted) _syncWanted = true;
    _permissionGranted = granted;
    if (!granted && _sync != null) _finishSync(_sync!);
    if (granted) _ensureTokenSync();
  }

  void _receive(RemoteMessage message, {required bool tapped}) {
    if (_disposed) return;
    final id = message.messageId;
    if (id == null || _receivedIds.add(id)) {
      _history.add(message);
      _invalidations.add(message.data);
      if (!tapped && message.notification != null) _foreground.add(message);
    }
    if (tapped && (id == null || _tapIds.add(id))) {
      _destinations.add(message.data);
    }
    _trim(_receivedIds);
    _trim(_tapIds);
    _drainCaptured();
  }

  void _trim<T>(Set<T> ids) {
    if (ids.length > 100) ids.remove(ids.first);
  }

  void _drainCaptured() {
    if (_disposed || _container == null) return;
    if (!_savingHistory) unawaited(_saveHistory());
    while (_foreground.isNotEmpty) {
      unawaited(_showLocal(_foreground.removeFirst()));
    }
    _scheduleNavigation();
  }

  Future<void> _saveHistory() async {
    _savingHistory = true;
    try {
      while (!_disposed && _history.isNotEmpty) {
        final message = _history.first;
        final target = NotificationTarget.fromPayload(message.data);
        if (target is! NoneNotificationTarget) {
          // Wait for loading before consuming the event. Once add starts it
          // publishes in memory before saving, so retrying a failed save would
          // duplicate the item. Navigation has its own independent queue.
          await _container!.read(notificationHistoryProvider.future);
          if (_disposed) return;
          _history.removeFirst();
          final fallback = switch (target) {
            OrderNotificationTarget() => 'Actualización de tu pedido',
            CouponNotificationTarget() => 'Tienes un cupón nuevo',
            BusinessHoursNotificationTarget() => 'Aviso del local',
            LinkNotificationTarget() => 'Notificación importante',
            NoneNotificationTarget() => 'Celtas',
          };
          await _container!
              .read(notificationHistoryProvider.notifier)
              .add(
                NotificationHistoryItem(
                  title: message.notification?.title ?? fallback,
                  body: message.notification?.body ?? '',
                  receivedAt: DateTime.now(),
                  data: message.data,
                ),
              );
        } else {
          _history.removeFirst();
        }
      }
    } catch (error, stack) {
      _report(error, stack);
    } finally {
      _savingHistory = false;
    }
  }

  Future<void> _showLocal(RemoteMessage message) async {
    try {
      await _locals.run();
      if (!_disposed) await _platform.showLocal(message);
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (_disposed || response.payload == null || response.payload!.isEmpty) {
      return;
    }
    if (response.id != null && !_localTapIds.add(response.id!)) return;
    _trim(_localTapIds);
    try {
      final data = Map<String, dynamic>.from(
        jsonDecode(response.payload!) as Map,
      );
      _invalidations.add(data);
      _destinations.add(data);
      _scheduleNavigation();
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  bool get _canNavigate =>
      !_disposed &&
      _routerReady &&
      _container != null &&
      !_container!.read(appVersionGateProvider).blocksNavigation &&
      _container!.read(authControllerProvider).status ==
          AuthStatus.authenticated;

  void _scheduleNavigation() {
    if (_navigationScheduled ||
        !_canNavigate ||
        (_destinations.isEmpty && _invalidations.isEmpty)) {
      return;
    }
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      if (!_canNavigate || rootNavigatorKey.currentContext == null) return;
      while (_invalidations.isNotEmpty) {
        _invalidateFor(_invalidations.removeFirst());
      }
      if (!_canNavigate) return;
      if (_destinations.isNotEmpty) {
        final data = _destinations.first;
        try {
          _navigateFor(data);
          _destinations.removeFirst();
        } catch (error, stack) {
          _report(error, stack);
          return;
        }
        _scheduleNavigation();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _invalidateFor(Map<String, dynamic> data) {
    switch (NotificationTarget.fromPayload(data)) {
      case OrderNotificationTarget(:final orderId):
        _container!.invalidate(orderListProvider);
        _container!.invalidate(orderDetailProvider(orderId));
      case CouponNotificationTarget():
        _container!.invalidate(userCouponListProvider);
      case BusinessHoursNotificationTarget():
        _container!.invalidate(businessHoursProvider);
      case LinkNotificationTarget():
        break;
      case NoneNotificationTarget():
        break;
    }
  }

  void _navigateFor(Map<String, dynamic> data) {
    switch (NotificationTarget.fromPayload(data)) {
      case OrderNotificationTarget(:final orderId):
        unawaited(
          _container!
              .read(routerProvider)
              .push<void>('/orders/$orderId')
              .then<void>((_) {}, onError: _report),
        );
      case CouponNotificationTarget():
        _container!.read(routerProvider).go('/coupons');
      case LinkNotificationTarget(:final link):
        unawaited(_launchUrl(link));
      case BusinessHoursNotificationTarget():
        break;
      case NoneNotificationTarget():
        break;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      await launchUrl(
        Uri.parse(urlString),
        mode: LaunchMode.externalApplication,
      );
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  void _requestTokenSync() {
    if (_disposed) return;
    final active = _sync;
    if (active != null &&
        _sameSession(active) &&
        active.tokenRevision == _tokenRevision) {
      return;
    }
    _syncWanted = true;
    _ensureTokenSync();
  }

  void _ensureTokenSync() {
    final container = _container;
    if (_disposed ||
        container == null ||
        !_routerReady ||
        !_permissionGranted ||
        !_syncWanted ||
        _sync != null) {
      return;
    }
    final auth = container.read(authControllerProvider);
    if (auth.status != AuthStatus.authenticated ||
        !container
            .read(authControllerProvider.notifier)
            .canRegisterNotifications) {
      return;
    }
    final attempt = _TokenSync(
      container.read(authControllerProvider.notifier).revision,
      auth.user!.id,
      _tokenRevision,
    );
    _sync = attempt;
    _syncWanted = false;
    attempt.deadline = Timer(const Duration(seconds: 20), () {
      if (!identical(_sync, attempt)) return;
      _finishSync(attempt);
      _report(
        TimeoutException('FCM sync exceeded 20 seconds'),
        StackTrace.current,
      );
    });
    unawaited(_registerToken(attempt));
  }

  bool _sameSession(_TokenSync attempt) =>
      !_disposed &&
      _container != null &&
      _container!.read(authControllerProvider).status ==
          AuthStatus.authenticated &&
      _container!.read(authControllerProvider).user?.id == attempt.userId &&
      _container!.read(authControllerProvider.notifier).revision ==
          attempt.revision &&
      _container!
          .read(authControllerProvider.notifier)
          .canRegisterNotifications;

  Future<String?> _readToken() {
    final pending = _nativeToken;
    if (pending != null) return pending;
    final operation = Future<String?>.sync(_platform.getToken);
    _nativeToken = operation;
    operation.then<void>(
      (_) {
        if (identical(_nativeToken, operation)) _nativeToken = null;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_nativeToken, operation)) _nativeToken = null;
      },
    );
    return operation;
  }

  Future<void> _registerToken(_TokenSync attempt) async {
    try {
      final token = _latestToken ?? await _readToken();
      if (!identical(_sync, attempt) ||
          !_sameSession(attempt) ||
          !_permissionGranted) {
        return;
      }
      if (attempt.tokenRevision != _tokenRevision) return;
      if (token == null) return;
      attempt.uploading = true;
      await _container!
          .read(notificationRepositoryProvider)
          .updateFcmToken(token, cancelToken: attempt.cancelToken);
    } catch (error, stack) {
      if (identical(_sync, attempt)) _report(error, stack);
    } finally {
      if (identical(_sync, attempt)) {
        _finishSync(attempt);
        // Only a distinct event recorded in-flight requests one follow-up.
        if (_syncWanted) _ensureTokenSync();
      }
    }
  }

  void _finishSync(_TokenSync attempt) {
    attempt.deadline?.cancel();
    attempt.cancelToken.cancel('FCM sync ended');
    if (identical(_sync, attempt)) _sync = null;
  }

  void _report(Object error, StackTrace stack) {
    if (!_disposed) onError?.call(error, stack);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_sync != null) _finishSync(_sync!);
    unawaited(_messageSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    for (final subscription in _streams) {
      unawaited(subscription.cancel());
    }
    for (final subscription in _providers) {
      subscription.close();
    }
    if (_container != null &&
        identical(ApiClient.instance.onSessionRefreshed, _refreshHook)) {
      ApiClient.instance.onSessionRefreshed = _previousRefreshHook;
    }
    if (identical(ApiClient.instance.onSessionActivityChanged, _activityHook)) {
      ApiClient.instance.onSessionActivityChanged = _previousActivityHook;
    }
  }
}

class _TokenSync {
  _TokenSync(this.revision, this.userId, this.tokenRevision);
  final int revision;
  final String userId;
  final int tokenRevision;
  final cancelToken = CancelToken();
  Timer? deadline;
  bool uploading = false;
}
