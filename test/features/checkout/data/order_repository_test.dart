import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/checkout/data/order_repository.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

/// Contrato de `POST /orders` verificado contra `celtas-backend/src/modules/
/// orders/dto/create-order.dto.ts` + `orders.service.ts`: cada ítem manda
/// `menuItemId` + `quantity` obligatorios, y `sauceIds` SOLO si el cliente
/// eligió alguna salsa para ese ítem (nunca una lista vacía) — el backend
/// valida cada id contra lo que el producto realmente ofrece y guarda los
/// nombres como snapshot en `OrderItem.selectedSauces`.
void main() {
  late MockDio dio;
  late OrderRepository repository;

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    dio = MockDio();
    repository = OrderRepository(dio);
  });

  const orderJson = {
    'id': 'order-1',
    'total': 15.5,
    'whatsappUrl': 'https://wa.me/51999999999',
  };

  void mockPostSuccess() {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/orders',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/orders'),
        data: orderJson,
      ),
    );
  }

  group('createOrder — payload de items con salsas', () {
    test('ítem sin salsas seleccionadas → no manda la llave "sauceIds"', () async {
      mockPostSuccess();

      await repository.createOrder(
        items: const [
          CartItem(
            menuItemId: 'i-1',
            name: 'Berserker Burger',
            unitPrice: 15.5,
            quantity: 1,
          ),
        ],
        addressId: 'addr-1',
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      final items = captured['items'] as List;
      final item = items.single as Map<String, dynamic>;
      expect(item['menuItemId'], 'i-1');
      expect(item['quantity'], 1);
      expect(item.containsKey('sauceIds'), isFalse);
    });

    test(
      'ítem con salsas seleccionadas → manda "sauceIds" con los ids '
      '(no los nombres)',
      () async {
        mockPostSuccess();

        await repository.createOrder(
          items: const [
            CartItem(
              menuItemId: 'i-1',
              name: 'Celtas Burguesa Clásica',
              unitPrice: 20,
              quantity: 2,
              selectedSauces: [
                SauceOption(id: 's-1', name: 'Mayonesa'),
                SauceOption(id: 's-2', name: 'Mostaza'),
              ],
            ),
          ],
          addressId: 'addr-1',
        );

        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            '/orders',
            data: captureAny(named: 'data'),
          ),
        ).captured.single as Map<String, dynamic>;
        final item = (captured['items'] as List).single as Map<String, dynamic>;
        expect(item['sauceIds'], ['s-1', 's-2']);
      },
    );

    test(
      'varios ítems: cada uno manda su propia selección de salsas de forma '
      'independiente',
      () async {
        mockPostSuccess();

        await repository.createOrder(
          items: const [
            CartItem(
              menuItemId: 'i-1',
              name: 'Celtas Burguesa Clásica',
              unitPrice: 20,
              quantity: 1,
              selectedSauces: [SauceOption(id: 's-1', name: 'Mayonesa')],
            ),
            CartItem(
              menuItemId: 'i-2',
              name: 'Arroz Chaufa',
              unitPrice: 18,
              quantity: 1,
            ),
          ],
          addressId: 'addr-1',
        );

        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            '/orders',
            data: captureAny(named: 'data'),
          ),
        ).captured.single as Map<String, dynamic>;
        final items = (captured['items'] as List).cast<Map<String, dynamic>>();
        expect(items[0]['sauceIds'], ['s-1']);
        expect(items[1].containsKey('sauceIds'), isFalse);
      },
    );

    test('el total nunca se manda: lo calcula el backend', () async {
      mockPostSuccess();

      await repository.createOrder(
        items: const [
          CartItem(
            menuItemId: 'i-1',
            name: 'Berserker Burger',
            unitPrice: 15.5,
            quantity: 1,
          ),
        ],
        addressId: 'addr-1',
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: captureAny(named: 'data'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(captured.containsKey('total'), isFalse);
    });

    test('parsea id/total/whatsappUrl de la respuesta', () async {
      mockPostSuccess();

      final result = await repository.createOrder(
        items: const [
          CartItem(
            menuItemId: 'i-1',
            name: 'Berserker Burger',
            unitPrice: 15.5,
            quantity: 1,
          ),
        ],
        addressId: 'addr-1',
      );

      expect(result.id, 'order-1');
      expect(result.total, 15.5);
      expect(result.whatsappUrl, 'https://wa.me/51999999999');
    });
  });
}
