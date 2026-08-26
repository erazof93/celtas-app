import 'package:celtas_mobile/core/network/api_client.dart';
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
/// `menuItemId` + `quantity` obligatorios, y `sauceIds` es tri-state real
/// (`resolveSelectedSauces` en el backend distingue los tres casos, no
/// colapsa `undefined` y `[]`): se OMITE por completo si el ítem no tiene
/// catálogo de salsas o el cliente nunca eligió, se manda `[]` EXPLÍCITO si
/// el cliente tocó "Sin salsas" a propósito (`CartItem.explicitlyNoSauces`),
/// y con salsas elegidas se mandan sus ids — el backend valida cada id
/// contra lo que el producto realmente ofrece y guarda los nombres como
/// snapshot en `OrderItem.selectedSauces`.
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
      'ítem con explicitlyNoSauces=true y selectedSauces vacío → manda '
      '"sauceIds": [] explícito (no ausente)',
      () async {
        mockPostSuccess();

        await repository.createOrder(
          items: const [
            CartItem(
              menuItemId: 'i-1',
              name: 'Salsas Burger',
              unitPrice: 12,
              quantity: 1,
              explicitlyNoSauces: true,
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
        expect(item.containsKey('sauceIds'), isTrue);
        expect(item['sauceIds'], <String>[]);
      },
    );

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

    test(
      'ítem sin comentario → no manda la llave "comment"',
      () async {
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
        final item = (captured['items'] as List).single as Map<String, dynamic>;
        expect(item.containsKey('comment'), isFalse);
      },
    );

    test(
      'ítem con comentario → manda "comment" trimeado',
      () async {
        mockPostSuccess();

        await repository.createOrder(
          items: const [
            CartItem(
              menuItemId: 'i-1',
              name: 'Berserker Burger',
              unitPrice: 15.5,
              quantity: 1,
              comment: '  Sin cebolla, bien cocida  ',
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
        expect(item['comment'], 'Sin cebolla, bien cocida');
      },
    );

    test(
      'ítem con comentario solo espacios → no manda la llave "comment" '
      '(mismo criterio que sauceIds: nunca una llave irrelevante)',
      () async {
        mockPostSuccess();

        await repository.createOrder(
          items: const [
            CartItem(
              menuItemId: 'i-1',
              name: 'Berserker Burger',
              unitPrice: 15.5,
              quantity: 1,
              comment: '   ',
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
        expect(item.containsKey('comment'), isFalse);
      },
    );

    test(
      'varios ítems: cada uno manda su propio comentario de forma '
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
              comment: 'Sin cebolla',
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
        expect(items[0]['comment'], 'Sin cebolla');
        expect(items[1].containsKey('comment'), isFalse);
      },
    );

    test(
      'ítem sin rewardRedemptionId → no manda la llave "rewardRedemptionId"',
      () async {
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
        final item = (captured['items'] as List).single as Map<String, dynamic>;
        expect(item.containsKey('rewardRedemptionId'), isFalse);
      },
    );

    test(
      'ítem de premio canjeado → manda "rewardRedemptionId", nunca '
      '"unitPrice" (el backend fuerza el precio, el cliente no lo decide)',
      () async {
        mockPostSuccess();

        await repository.createOrder(
          items: const [
            CartItem(
              menuItemId: 'i-1',
              name: 'Berserker Burger',
              unitPrice: 0,
              quantity: 1,
              rewardRedemptionId: 'reward-1',
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
        expect(item['rewardRedemptionId'], 'reward-1');
        expect(item.containsKey('unitPrice'), isFalse);
      },
    );

    test(
      'varios ítems: cada uno manda su propio rewardRedemptionId de forma '
      'independiente',
      () async {
        mockPostSuccess();

        await repository.createOrder(
          items: const [
            CartItem(
              menuItemId: 'i-1',
              name: 'Berserker Burger',
              unitPrice: 0,
              quantity: 1,
              rewardRedemptionId: 'reward-1',
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
        expect(items[0]['rewardRedemptionId'], 'reward-1');
        expect(items[1].containsKey('rewardRedemptionId'), isFalse);
      },
    );

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

  group('createOrder — 409 local cerrado', () {
    /// Contrato verificado contra `orders.service.ts` (`create`): el check
    /// de `isOpenNow()` ocurre ANTES de tocar la base y lanza
    /// `ConflictException` (409) con el mensaje ya armado en español, listo
    /// para mostrar tal cual — mismo `message` que arma
    /// `SettingsService.isOpenNow`, ej. horario programado
    /// ("El local está cerrado en este momento. Hoy atendemos de 11:00 a
    /// 23:00") o cierre manual con motivo ("El local está cerrado
    /// temporalmente: Cerrado por mantenimiento").
    void mockPost409(String message) {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/orders'),
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/orders'),
            statusCode: 409,
            data: {'success': false, 'message': message, 'statusCode': 409},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    }

    test(
      'horario programado: conserva el mensaje real del backend y el '
      'statusCode 409',
      () async {
        mockPost409(
          'El local está cerrado en este momento. Hoy atendemos de 11:00 a '
          '23:00',
        );

        Object? caught;
        try {
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
        } catch (e) {
          caught = e;
        }

        expect(caught, isA<ApiException>());
        final exception = caught as ApiException;
        expect(
          exception.message,
          'El local está cerrado en este momento. Hoy atendemos de 11:00 a '
          '23:00',
        );
        expect(exception.statusCode, 409);
      },
    );

    test('cierre manual con motivo: conserva el mensaje real del backend', () async {
      mockPost409('El local está cerrado temporalmente: Cerrado por mantenimiento');

      Object? caught;
      try {
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
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ApiException>());
      final exception = caught as ApiException;
      expect(
        exception.message,
        'El local está cerrado temporalmente: Cerrado por mantenimiento',
      );
      expect(exception.statusCode, 409);
    });
  });

  group('estimateDeliveryFee — POST /orders/estimate-delivery-fee', () {
    test(
      'manda { addressId } y devuelve SOLO deliveryFee (ignora isFarOrder/'
      'distanceMeters, aunque vengan en la respuesta)',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/orders/estimate-delivery-fee',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions:
                RequestOptions(path: '/orders/estimate-delivery-fee'),
            data: const {
              'deliveryFee': 6.5,
              'isFarOrder': true,
              'distanceMeters': 8200,
            },
          ),
        );

        final fee = await repository.estimateDeliveryFee('addr-1');

        expect(fee, 6.5);
        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            '/orders/estimate-delivery-fee',
            data: captureAny(named: 'data'),
          ),
        ).captured.single as Map<String, dynamic>;
        expect(captured, {'addressId': 'addr-1'});
      },
    );

    test('error del backend → ApiException con el mensaje real', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/orders/estimate-delivery-fee',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions:
              RequestOptions(path: '/orders/estimate-delivery-fee'),
          response: Response<Map<String, dynamic>>(
            requestOptions:
                RequestOptions(path: '/orders/estimate-delivery-fee'),
            statusCode: 404,
            data: const {
              'success': false,
              'message': 'Dirección no encontrada',
              'statusCode': 404,
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      Object? caught;
      try {
        await repository.estimateDeliveryFee('addr-inexistente');
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ApiException>());
      expect((caught as ApiException).message, 'Dirección no encontrada');
    });
  });
}
