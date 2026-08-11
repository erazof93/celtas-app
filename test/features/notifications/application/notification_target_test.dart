import 'package:celtas_mobile/features/notifications/application/notification_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationTarget.fromPayload', () {
    test('{ orderId, status } → OrderNotificationTarget', () {
      final target = NotificationTarget.fromPayload({
        'orderId': 'order-123',
        'status': 'confirmado',
      });

      expect(target, isA<OrderNotificationTarget>());
      expect((target as OrderNotificationTarget).orderId, 'order-123');
    });

    test('{ couponCode } → CouponNotificationTarget', () {
      final target = NotificationTarget.fromPayload({'couponCode': 'BIENVENIDO10'});

      expect(target, isA<CouponNotificationTarget>());
    });

    test('payload sin llaves reconocidas → NoneNotificationTarget', () {
      final target = NotificationTarget.fromPayload({'algoInesperado': 'x'});

      expect(target, isA<NoneNotificationTarget>());
    });

    test('payload vacío → NoneNotificationTarget', () {
      final target = NotificationTarget.fromPayload(const {});

      expect(target, isA<NoneNotificationTarget>());
    });

    test('orderId presente junto con couponCode → gana orderId', () {
      // No debería pasar en producción (el backend nunca manda ambas
      // llaves en el mismo push), pero si pasara, el comportamiento debe
      // quedar definido: pedidos tienen precedencia, igual que antes de
      // extraer esta clasificación a una función pura.
      final target = NotificationTarget.fromPayload({
        'orderId': 'order-456',
        'couponCode': 'X',
      });

      expect(target, isA<OrderNotificationTarget>());
      expect((target as OrderNotificationTarget).orderId, 'order-456');
    });
  });
}
