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
    if (data.containsKey('businessHoursChanged')) {
      return const BusinessHoursNotificationTarget();
    }
    final link = data['link'] as String?;
    if (link != null && link.isNotEmpty) {
      return LinkNotificationTarget(link);
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

/// Cambió el horario de atención (el admin activó/desactivó el cierre
/// manual): `{ businessHoursChanged: 'true' }`. Sin más contenido — es solo
/// un aviso de "algo cambió", nunca la fuente del estado real: el título y
/// cuerpo de la notificación NO deben tratarse como el estado verdadero,
/// siempre hay que reconsultar `GET /settings/business-hours`
/// (`businessHoursProvider`) para saber si el local está abierto ahora.
class BusinessHoursNotificationTarget extends NotificationTarget {
  const BusinessHoursNotificationTarget();
}

/// Link directo (deep link o URL externa): `{ link: "https://..." }`.
/// Se dispara cuando el backend envía una notificación de marketing con un
/// link (`BroadcastNotificationDto.link` — solo `@IsString`/`@MaxLength`,
/// sin restricción de esquema: el admin puede mandar tanto una URL externa
/// como un deep link propio, contrato verificado contra
/// `broadcast-notification.dto.ts`).
class LinkNotificationTarget extends NotificationTarget {
  const LinkNotificationTarget(this.link);

  final String link;

  @override
  bool operator ==(Object other) =>
      other is LinkNotificationTarget && other.link == link;

  @override
  int get hashCode => link.hashCode;
}

/// Payload sin llaves reconocidas — no se invalida ni navega a nada.
class NoneNotificationTarget extends NotificationTarget {
  const NoneNotificationTarget();
}
