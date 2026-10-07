import 'dart:async';

import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/data/address_repository.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/checkout/application/checkout_providers.dart';
import 'package:celtas_mobile/features/checkout/data/models/delivery_estimate.dart';
import 'package:celtas_mobile/features/checkout/data/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrders extends Mock implements OrderRepository {}

class MockAddresses extends Mock implements AddressRepository {}

const quote = DeliveryEstimate(
  deliveryFee: 5,
  isFarOrder: false,
  distanceMeters: 1000,
  isCovered: true,
  deliveryMode: DeliveryMode.distance,
  zone: null,
);

void main() {
  late MockOrders orders;
  late ProviderContainer container;
  setUp(() {
    orders = MockOrders();
    container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(orders)],
    );
  });
  tearDown(() => container.dispose());

  test('loading → data', () async {
    final pending = Completer<DeliveryEstimate>();
    when(
      () => orders.estimateDeliveryFee('A'),
    ).thenAnswer((_) => pending.future);
    final provider = deliveryFeeEstimateProvider('A');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    expect(container.read(provider).isLoading, isTrue);
    pending.complete(quote);
    expect(await container.read(provider.future), quote);
    expect(container.read(provider), isA<AsyncData<DeliveryEstimate>>());
  });

  test('error preservado y retry', () async {
    when(
      () => orders.estimateDeliveryFee('A'),
    ).thenAnswer((_) async => throw StateError('red'));
    final provider = deliveryFeeEstimateProvider('A');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(container.read(provider.future), throwsStateError);
    expect(container.read(provider).hasError, isTrue);
    when(() => orders.estimateDeliveryFee('A')).thenAnswer((_) async => quote);
    container.invalidate(provider);
    expect(await container.read(provider.future), quote);
  });

  test('B termina antes de A: A no sustituye B', () async {
    final a = Completer<DeliveryEstimate>();
    final b = Completer<DeliveryEstimate>();
    when(() => orders.estimateDeliveryFee('A')).thenAnswer((_) => a.future);
    when(() => orders.estimateDeliveryFee('B')).thenAnswer((_) => b.future);
    final subA = container.listen(deliveryFeeEstimateProvider('A'), (_, _) {});
    final subB = container.listen(deliveryFeeEstimateProvider('B'), (_, _) {});
    addTearDown(subA.close);
    addTearDown(subB.close);
    b.complete(quote.copyWith(deliveryFee: 12));
    await container.read(deliveryFeeEstimateProvider('B').future);
    a.complete(quote);
    await container.read(deliveryFeeEstimateProvider('A').future);
    expect(
      container.read(deliveryFeeEstimateProvider('B')).requireValue.deliveryFee,
      12,
    );
  });

  for (final remove in [false, true]) {
    test(
      '${remove ? 'eliminar' : 'editar coordenadas mismo ID'} invalida estimate',
      () async {
        final addresses = MockAddresses();
        const address = Address(
          id: 'A',
          alias: 'Casa',
          fullAddress: 'Av. 123',
          district: 'Surco',
        );
        when(() => addresses.getAddresses()).thenAnswer((_) async => [address]);
        when(
          () => addresses.updateAddress('A', latitude: -12, longitude: -77),
        ).thenAnswer((_) async {});
        when(() => addresses.deleteAddress('A')).thenAnswer((_) async {});
        var calls = 0;
        when(() => orders.estimateDeliveryFee('A')).thenAnswer(
          (_) async => quote.copyWith(deliveryFee: (++calls).toDouble()),
        );
        final local = ProviderContainer(
          overrides: [
            orderRepositoryProvider.overrideWithValue(orders),
            addressRepositoryProvider.overrideWithValue(addresses),
          ],
        );
        addTearDown(local.dispose);
        final sub = local.listen(deliveryFeeEstimateProvider('A'), (_, _) {});
        addTearDown(sub.close);
        await local.read(addressListProvider.future);
        await local.read(deliveryFeeEstimateProvider('A').future);
        if (remove) {
          await local.read(addressListProvider.notifier).removeAddress('A');
        } else {
          await local
              .read(addressListProvider.notifier)
              .updateAddress('A', latitude: -12, longitude: -77);
        }
        expect(
          (await local.read(
            deliveryFeeEstimateProvider('A').future,
          )).deliveryFee,
          2,
        );
      },
    );
  }
}
