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
      final target = NotificationTarget.fromPayload({
        'couponCode': 'BIENVENIDO10',
      });

      expect(target, isA<CouponNotificationTarget>());
    });

    test(
      '{ businessHoursChanged: "true" } → BusinessHoursNotificationTarget',
      () {
        final target = NotificationTarget.fromPayload({
          'businessHoursChanged': 'true',
        });

        expect(target, isA<BusinessHoursNotificationTarget>());
      },
    );

    test('{ link } → LinkNotificationTarget', () {
      final target = NotificationTarget.fromPayload({
        'link': 'https://celtas.com/promos/dia-del-padre',
      });

      expect(target, isA<LinkNotificationTarget>());
      expect(
        (target as LinkNotificationTarget).link,
        'https://celtas.com/promos/dia-del-padre',
      );
    });

    test('{ link: "" } (vacío) → NoneNotificationTarget', () {
      // El backend solo manda la llave si `payload.link` es truthy
      // (`notifications.service.ts`), pero el chequeo `isNotEmpty` acá es la
      // segunda línea de defensa si algún día llegara vacía igual.
      final target = NotificationTarget.fromPayload({'link': ''});

      expect(target, isA<NoneNotificationTarget>());
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

    test('orderId presente junto con link → gana orderId', () {
      // Mismo criterio que el caso couponCode de arriba: no debería pasar en
      // producción, pero el orden de precedencia queda definido igual —
      // `link` es la última llave que se chequea en `fromPayload`.
      final target = NotificationTarget.fromPayload({
        'orderId': 'order-789',
        'link': 'https://celtas.com',
      });

      expect(target, isA<OrderNotificationTarget>());
      expect((target as OrderNotificationTarget).orderId, 'order-789');
    });
  });
}
