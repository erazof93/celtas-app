import 'package:celtas_mobile/features/checkout/data/models/delivery_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> json() => {
    'deliveryFee': 6,
    'isFarOrder': false,
    'distanceMeters': 1500,
    'isCovered': true,
    'deliveryMode': 'DISTANCE',
    'zone': null,
  };

  test('DISTANCE completo y campos desconocidos', () {
    final estimate = DeliveryEstimate.fromJson({...json(), 'futureField': []});
    expect(estimate.deliveryFee, 6.0);
    expect(estimate.deliveryMode, DeliveryMode.distance);
    expect(estimate.distanceMeters, 1500.0);
    expect(estimate.zone, isNull);
    expect(estimate.isCovered, isTrue);
    expect(estimate.isFarOrder, isFalse);
    expect(DeliveryEstimate.fromJson(estimate.toJson()), estimate);
  });

  test('ZONES covered y zona', () {
    final estimate = DeliveryEstimate.fromJson({
      ...json(),
      'deliveryMode': 'ZONES',
      'isFarOrder': true,
      'zone': {'id': 'z1', 'name': 'Zona cercana'},
    });
    expect(estimate.zone, const DeliveryZone(id: 'z1', name: 'Zona cercana'));
    expect(estimate.isCovered, isTrue);
    expect(estimate.isFarOrder, isTrue);
  });

  test('ZONES uncovered, zone y distance null', () {
    final estimate = DeliveryEstimate.fromJson({
      ...json(),
      'deliveryMode': 'ZONES',
      'isCovered': false,
      'deliveryFee': 0,
      'distanceMeters': null,
    });
    expect(estimate.isCovered, isFalse);
    expect(estimate.deliveryFee, 0);
    expect(estimate.distanceMeters, isNull);
    expect(estimate.zone, isNull);
  });

  test('cero covered válido', () {
    expect(
      DeliveryEstimate.fromJson({...json(), 'deliveryFee': 0}).isCovered,
      isTrue,
    );
  });

  for (final key in json().keys) {
    test('campo contractual ausente: $key', () {
      final data = json()..remove(key);
      expect(() => DeliveryEstimate.fromJson(data), throwsA(anything));
    });
  }
  for (final mode in ['INVALID', null]) {
    test('modo inválido $mode no asume DISTANCE', () {
      expect(
        () => DeliveryEstimate.fromJson({...json(), 'deliveryMode': mode}),
        throwsA(anything),
      );
    });
  }
  test('ZONES covered sin zona es contrato inválido', () {
    expect(
      () => DeliveryEstimate.fromJson({...json(), 'deliveryMode': 'ZONES'}),
      throwsFormatException,
    );
  });
}
