import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_history_item.freezed.dart';
part 'notification_history_item.g.dart';

/// Una notificación push ya recibida, guardada en el historial local
/// (`shared_preferences`, sin backend nuevo).
///
/// `data` es el payload crudo de FCM (`{orderId, status}` o `{couponCode}`) —
/// se guarda tal cual para poder navegar al tocar el ítem exactamente igual
/// que la notificación real (`NotificationTarget.fromPayload`), sin duplicar
/// esa lógica de interpretación.
@freezed
abstract class NotificationHistoryItem with _$NotificationHistoryItem {
  const factory NotificationHistoryItem({
    required String title,
    required String body,
    required DateTime receivedAt,
    required Map<String, dynamic> data,
  }) = _NotificationHistoryItem;

  factory NotificationHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationHistoryItemFromJson(json);
}
