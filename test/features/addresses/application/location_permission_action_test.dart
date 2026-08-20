import 'package:celtas_mobile/features/addresses/application/location_permission_action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('locationPermissionActionFor', () {
    test('denied → requestPermission', () {
      expect(
        locationPermissionActionFor(LocationPermission.denied),
        LocationPermissionAction.requestPermission,
      );
    });

    test('unableToDetermine → requestPermission', () {
      expect(
        locationPermissionActionFor(LocationPermission.unableToDetermine),
        LocationPermissionAction.requestPermission,
      );
    });

    test(
      'deniedForever → openSystemSettings (el diálogo nativo ya no aparece)',
      () {
        expect(
          locationPermissionActionFor(LocationPermission.deniedForever),
          LocationPermissionAction.openSystemSettings,
        );
      },
    );

    test('whileInUse → none', () {
      expect(
        locationPermissionActionFor(LocationPermission.whileInUse),
        LocationPermissionAction.none,
      );
    });

    test('always → none', () {
      expect(
        locationPermissionActionFor(LocationPermission.always),
        LocationPermissionAction.none,
      );
    });
  });
}
