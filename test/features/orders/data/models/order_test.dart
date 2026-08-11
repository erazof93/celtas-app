import 'package:celtas_mobile/features/orders/data/models/order.dart';
import 'package:celtas_mobile/features/orders/data/models/order_item.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Order buildOrder({
    String id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    String addressSnapshot =
        '{"alias":"Casa","fullAddress":"Av. Los Álamos 123",'
        '"reference":"Portón azul","district":"San Juan de Miraflores"}',
    List<OrderItem> items = const [
      OrderItem(
        id: 'item-1',
        menuItemId: 'menu-1',
        name: 'Berserker Burger',
        unitPrice: 15.5,
        quantity: 2,
        subtotal: 31,
      ),
      OrderItem(
        id: 'item-2',
        name: "Odin's Wings x8",
        unitPrice: 18,
        quantity: 1,
        subtotal: 18,
      ),
    ],
  }) =>
      Order(
        id: id,
        status: OrderStatus.enCamino,
        addressSnapshot: addressSnapshot,
        total: 49,
        whatsappUrl: 'https://wa.me/51999999999',
        items: items,
        createdAt: DateTime(2026, 8, 6),
      );

  test('fromJson parsea el contrato real del backend', () {
    final json = {
      'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      'status': 'en_camino',
      'addressSnapshot':
          '{"alias":"Casa","fullAddress":"Av. Los Álamos 123",'
              '"reference":null,"district":"San Juan de Miraflores"}',
      'total': 49.0,
      'whatsappUrl': 'https://wa.me/51999999999',
      'deliveredAt': null,
      'items': [
        {
          'id': 'item-1',
          'menuItemId': 'menu-1',
          'name': 'Berserker Burger',
          'unitPrice': 15.5,
          'quantity': 2,
          'subtotal': 31.0,
        },
      ],
      'createdAt': '2026-08-06T10:00:00.000Z',
    };

    final order = Order.fromJson(json);

    expect(order.status, OrderStatus.enCamino);
    expect(order.items, hasLength(1));
    expect(order.items.first.menuItemId, 'menu-1');
  });

  test('address decodifica el JSON string crudo de addressSnapshot', () {
    final order = buildOrder();

    expect(order.address.alias, 'Casa');
    expect(order.address.fullAddress, 'Av. Los Álamos 123');
    expect(order.address.reference, 'Portón azul');
    expect(order.address.district, 'San Juan de Miraflores');
  });

  test('itemsCount suma quantity de todos los items, no la cantidad de líneas', () {
    final order = buildOrder();

    expect(order.itemsCount, 3); // 2 + 1, no 2 líneas
  });

  test('shortId usa los primeros 8 caracteres del UUID en mayúsculas '
      '(mismo criterio que celtas-admin)', () {
    final order = buildOrder();

    expect(order.shortId, 'A1B2C3D4');
  });
}
