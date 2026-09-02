import 'package:celtas_mobile/features/notifications/application/notification_permission_action.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('actionForAuthorizationStatus', () {
    test('notDetermined → requestPermission (nunca se le preguntó)', () {
      expect(
        actionForAuthorizationStatus(AuthorizationStatus.notDetermined),
        NotificationPermissionAction.requestPermission,
      );
    });

    test(
      'denied → openSystemSettings (requestPermission() ya no muestra '
      'nada una vez rechazado, según la doc de FlutterFire)',
      () {
        expect(
          actionForAuthorizationStatus(AuthorizationStatus.denied),
          NotificationPermissionAction.openSystemSettings,
        );
      },
    );

    test(
      'deniedPermanently (firebase_messaging 16.6.0+) → openSystemSettings, '
      'mismo criterio que denied',
      () {
        expect(
          actionForAuthorizationStatus(
            AuthorizationStatus.deniedPermanently,
          ),
          NotificationPermissionAction.openSystemSettings,
        );
      },
    );

    test('authorized → none (ya está activado, tocar no hace nada)', () {
      expect(
        actionForAuthorizationStatus(AuthorizationStatus.authorized),
        NotificationPermissionAction.none,
      );
    });

    test('provisional (solo iOS) → none', () {
      expect(
        actionForAuthorizationStatus(AuthorizationStatus.provisional),
        NotificationPermissionAction.none,
      );
    });
  });
}
