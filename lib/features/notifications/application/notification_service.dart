import 'dart:convert';

import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/features/auth/application/auth_providers.dart';
import 'package:celtas_mobile/features/auth/application/auth_state.dart';
import 'package:celtas_mobile/features/coupons/application/coupon_providers.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/application/notification_target.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/orders/application/order_history_providers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Único canal de notificaciones en Android. Se crea una vez en `init()`.
const _androidChannel = AndroidNotificationChannel(
  'celtas_default',
  'Celtas',
  description: 'Novedades de tus pedidos y cupones',
  importance: Importance.high,
);

/// Notificaciones push (FCM) + notificación local en foreground + su
/// integración con el resto de la app: registra el `fcmToken`, invalida el
/// provider correspondiente al recibir una notificación de pedido/cupón,
/// navega a la pantalla relevante al tocarla, y guarda cada una en el
/// historial local (`notificationHistoryProvider`, pantalla `/notifications`).
///
/// Singleton igual que `ApiClient.instance` — necesita vivir fuera del árbol
/// de widgets porque `getInitialMessage()` (la app arrancó porque el usuario
/// tocó una notificación estando cerrada) se resuelve antes de que exista
/// ningún `BuildContext`. Por eso `main.dart` crea el `ProviderContainer` a
/// mano (`UncontrolledProviderScope`) y se lo pasa a `init()`, en vez de
/// dejar que `ProviderScope` lo cree internamente.
///
/// Payload de notificación confirmado contra el backend real
/// (`orders.service.ts` / `coupons.service.ts`, no hay un campo `type`
/// explícito — se infiere por la llave presente en `data`):
///   - Cambio de estado de pedido: `{ orderId, status }`
///   - Cupón nuevo (manual o automático): `{ couponCode }`
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  late final ProviderContainer _container;

  Future<void> init(ProviderContainer container) async {
    _container = container;

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    await FirebaseMessaging.instance.requestPermission();

    // Registra/actualiza el fcmToken solo en la transición HACIA
    // autenticado (login, registro, Google, o bootstrap con sesión previa) —
    // no en cada refresh silencioso de accessToken, que produce un
    // `AuthState` nuevo con el mismo status y dispararía este listener en
    // cada request que gatille un refresh si no se filtrara la transición.
    _container.listen(authControllerProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _registerToken();
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      if (_container.read(authControllerProvider).status ==
          AuthStatus.authenticated) {
        _registerToken();
      }
    });

    // Foreground: FCM no muestra la notificación sola, hay que mostrarla a
    // mano. Invalida ya mismo el provider: la pantalla puede estar abierta.
    FirebaseMessaging.onMessage.listen((message) {
      _invalidateFor(message.data);
      _showLocalNotification(message);
      _saveToHistory(message);
    });

    // Background: la app ya corría, el usuario tocó la notificación y volvió
    // — mismo isolate, se puede invalidar y navegar directo.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _invalidateFor(message.data);
      _navigateFor(message.data);
      _saveToHistory(message);
    });

    // Terminated: la app arrancó porque el usuario tocó la notificación. El
    // bootstrap de sesión puede seguir en curso, así que la navegación
    // espera a que quede autenticada.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigateWhenAuthenticated(initialMessage.data);
      _saveToHistory(initialMessage);
    }
  }

  /// Guarda la notificación en el historial local (`/notifications`), desde
  /// los mismos 3 puntos donde ya se intercepta foreground/background/
  /// terminated arriba. Si el payload no trae `notification` (no debería
  /// pasar — el backend siempre manda título/cuerpo, ver
  /// `orders.service.ts`/`coupons.service.ts` — pero no se asume), se arma un
  /// texto genérico a partir de `NotificationTarget` en vez de perder el
  /// registro o crashear con un `!` sobre un valor nulo.
  void _saveToHistory(RemoteMessage message) {
    final target = NotificationTarget.fromPayload(message.data);
    if (target is NoneNotificationTarget) return;
    final fallbackTitle = switch (target) {
      OrderNotificationTarget() => 'Actualización de tu pedido',
      CouponNotificationTarget() => 'Tenés un cupón nuevo',
      NoneNotificationTarget() => 'Celtas',
    };
    _container
        .read(notificationHistoryProvider.notifier)
        .add(
          NotificationHistoryItem(
            title: message.notification?.title ?? fallbackTitle,
            body: message.notification?.body ?? '',
            receivedAt: DateTime.now(),
            data: message.data,
          ),
        );
  }

  Future<void> _registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await _container
          .read(notificationRepositoryProvider)
          .updateFcmToken(token);
    } catch (_) {
      // Best-effort: si falla (backend dormido, sin red) no bloquea el
      // login. El próximo login o refresh de token lo reintenta.
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    _invalidateFor(data);
    _navigateFor(data);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _invalidateFor(Map<String, dynamic> data) {
    switch (NotificationTarget.fromPayload(data)) {
      case OrderNotificationTarget(:final orderId):
        _container.invalidate(orderListProvider);
        _container.invalidate(orderDetailProvider(orderId));
      case CouponNotificationTarget():
        _container.invalidate(userCouponListProvider);
      case NoneNotificationTarget():
        break;
    }
  }

  void _navigateFor(Map<String, dynamic> data) {
    switch (NotificationTarget.fromPayload(data)) {
      case OrderNotificationTarget(:final orderId):
        _container.read(routerProvider).push('/orders/$orderId');
      case CouponNotificationTarget():
        _container.read(routerProvider).go('/coupons');
      case NoneNotificationTarget():
        break;
    }
  }

  /// Navega en cuanto la sesión quede autenticada (o de inmediato si ya lo
  /// está). Solo lo usa el mensaje inicial (app arrancada desde terminada
  /// tocando la notificación), donde el bootstrap de sesión puede seguir en
  /// curso.
  void _navigateWhenAuthenticated(Map<String, dynamic> data) {
    if (_container.read(authControllerProvider).status ==
        AuthStatus.authenticated) {
      _navigateFor(data);
      return;
    }
    late final ProviderSubscription<AuthState> subscription;
    subscription = _container.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        _navigateFor(data);
        subscription.close();
      } else if (next.status == AuthStatus.unauthenticated) {
        // Sin sesión: las rutas de pedidos/cupones están protegidas, no hay
        // a dónde navegar — se descarta el deep link.
        subscription.close();
      }
    });
  }
}
