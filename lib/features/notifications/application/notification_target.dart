/// Interpretación pura del payload `data` de una notificación push.
///
/// Sin dependencia de `FirebaseMessaging` ni de `ProviderContainer` — a
/// diferencia de `NotificationService` (que sí las necesita para invalidar
/// providers y navegar), esta clasificación es testeable de forma aislada.
/// Extraído tras la auditoría del módulo 10: la lógica de a qué pantalla
/// navega / qué provider invalida una notificación solo estaba validada por
/// prueba manual en dispositivo real, sin cobertura de regresión.
///
/// Mismo criterio de payload documentado en `NotificationService`: no hay un
/// campo `type` explícito, se infiere por la llave presente en `data`.
sealed class NotificationTarget {
  const NotificationTarget();

  factory NotificationTarget.fromPayload(Map<String, dynamic> data) {
    final orderId = data['orderId'] as String?;
    if (orderId != null) return OrderNotificationTarget(orderId);
    if (data.containsKey('couponCode')) {
      return const CouponNotificationTarget();
    }
    return const NoneNotificationTarget();
  }
}

/// Cambio de estado de pedido: `{ orderId, status }`.
class OrderNotificationTarget extends NotificationTarget {
  const OrderNotificationTarget(this.orderId);

  final String orderId;

  @override
  bool operator ==(Object other) =>
      other is OrderNotificationTarget && other.orderId == orderId;

  @override
  int get hashCode => orderId.hashCode;
}

/// Cupón nuevo (manual o automático): `{ couponCode }`.
class CouponNotificationTarget extends NotificationTarget {
  const CouponNotificationTarget();
}

/// Payload sin llaves reconocidas — no se invalida ni navega a nada.
class NoneNotificationTarget extends NotificationTarget {
  const NoneNotificationTarget();
}
