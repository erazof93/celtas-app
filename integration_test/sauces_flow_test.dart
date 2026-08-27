import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// E2E real (emulador/dispositivo Android + backend real) del flujo de
/// salsas/cremas de punta a punta. Cubre los 2 ítems de
/// `docs/testing-checklist.md` → sección "Salsas/cremas" que sólo podían
/// confirmarse en dispositivo (ninguna sesión anterior tuvo uno conectado
/// para esto):
///
///   1. "AGREGAR AL CARRITO" vuelve a Home automáticamente — con la
///      transición REAL de `go_router` sobre el `ShellRoute`, y la fila del
///      carrito mostrando `cremas: ...` / `Sin salsas` según el caso.
///   2. El `whatsappUrl` de un pedido REAL trae las salsas concatenadas al
///      final de la linea del item, incluido el literal `(Salsas: Sin salsas)`
///      cuando el cliente eligió "Sin salsas" a propósito. Ese texto lo arma
///      el backend (`OrdersService.buildWhatsappUrl`); acá se confirma que
///      llega intacto en la respuesta de `POST /orders` que la app abriría con
///      `url_launcher`.
///
/// Usa el usuario de prueba persistente `mobile_it@celtas.pe` (el mismo que
/// `cart_flow_test.dart`). Crea 1 pedido REAL con 2 líneas del mismo producto
/// (una con salsa real, otra con "Sin salsas").
const _testEmail = 'mobile_it@celtas.pe';
const _testPassword = 'Secret123!';

// Coordenadas dentro de San Juan de Miraflores (Lima).
const _sjmLat = -12.1590;
const _sjmLng = -76.9700;

void _log(String message) =>
    debugPrint('[salsas-e2e ${DateTime.now().toIso8601String()}] $message');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load();
  });

  testWidgets(
    'salsas E2E: "AGREGAR" vuelve a Home + whatsappUrl trae "(Salsas: <nombre>)" '
    'y "(Salsas: Sin salsas)"',
    (tester) async {
      await _bootToHome(tester);
      _log('Home cargado.');

      // ── Buscar en el menú real el primer producto que ofrezca salsas. ──
      final menuResponse =
          await ApiClient.instance.dio.get<List<dynamic>>('/menu');
      final categories =
          (menuResponse.data ?? const []).cast<Map<String, dynamic>>();
      Map<String, dynamic>? sauceProduct;
      for (final category in categories) {
        final items =
            (category['items'] as List? ?? const []).cast<Map<String, dynamic>>();
        for (final item in items) {
          if ((item['sauces'] as List? ?? const []).isNotEmpty) {
            sauceProduct = item;
            break;
          }
        }
        if (sauceProduct != null) break;
      }
      expect(
        sauceProduct,
        isNotNull,
        reason: 'El menú real no tiene ningún producto con salsas configuradas.',
      );

      final productId = sauceProduct!['id'] as String;
      final productName = sauceProduct['name'] as String;
      final sauces =
          (sauceProduct['sauces'] as List).cast<Map<String, dynamic>>();
      final firstSauceId = sauces.first['id'] as String;
      final firstSauceName = sauces.first['name'] as String;
      _log('Producto con salsas: "$productName" ($productId) — '
          'salsa "$firstSauceName" ($firstSauceId).');

      // ══════════════════════════════════════════════════════════════════════
      // PARTE 1 — "AGREGAR AL CARRITO" vuelve a Home (transición real).
      // ══════════════════════════════════════════════════════════════════════
      await _openDetail(tester, productId);
      await tester.tap(find.byKey(ValueKey('detail-sauce-$firstSauceId')));
      await tester.pumpAndSettle();
      await _tapAdd(tester);

      expect(
        find.byKey(const ValueKey('detail-add')),
        findsNothing,
        reason: 'Tras "AGREGAR AL CARRITO" el detalle sigue montado — no volvió '
            'a Home automáticamente (ítem 1 del checklist).',
      );
      expect(find.byKey(const ValueKey('home-cart-icon')), findsOneWidget);
      _log('Add con salsa real → volvió a Home. OK.');

      await _openDetail(tester, productId);
      await tester.tap(find.byKey(const ValueKey('detail-sauce-none')));
      await tester.pumpAndSettle();
      await _tapAdd(tester);

      expect(
        find.byKey(const ValueKey('detail-add')),
        findsNothing,
        reason: 'Tras "AGREGAR AL CARRITO" (caso "Sin salsas") no volvió a Home.',
      );
      expect(find.byKey(const ValueKey('home-cart-icon')), findsOneWidget);
      _log('Add "Sin salsas" → volvió a Home. OK.');

      // ── Carrito: línea "cremas: <salsa>" y línea "Sin salsas". ──
      await tester.tap(find.byKey(const ValueKey('home-cart-icon')));
      await tester.pumpAndSettle();
      expect(find.text('Tu carrito'), findsOneWidget);
      expect(
        find.text('cremas: $firstSauceName'),
        findsOneWidget,
        reason: 'La fila del carrito no muestra "cremas: $firstSauceName".',
      );
      expect(
        find.text('Sin salsas'),
        findsOneWidget,
        reason: 'La fila del carrito con "Sin salsas" no muestra ese literal.',
      );
      _log('Carrito muestra "cremas: $firstSauceName" y "Sin salsas". OK.');

      // ══════════════════════════════════════════════════════════════════════
      // PARTE 2 — pedido REAL y verificación del whatsappUrl.
      // ══════════════════════════════════════════════════════════════════════
      await _ensureAddress(tester);
      final addressesResponse =
          await ApiClient.instance.dio.get<List<dynamic>>('/users/me/addresses');
      final addresses =
          (addressesResponse.data ?? const []).cast<Map<String, dynamic>>();
      expect(addresses, isNotEmpty, reason: 'No hay dirección para el pedido.');

      final hours = await ApiClient.instance.dio
          .get<Map<String, dynamic>>('/settings/business-hours');
      _log('business-hours: ${hours.data}');

      // Camino de UI: cart-continue → checkout → confirmar. Es el que da por
      // verificado el ítem 2 del checklist "en dispositivo real" (ejercita
      // `OrderRepository.createOrder` + la pantalla de checkout de verdad).
      final uiResult = await _orderViaUi(tester);
      String? whatsappUrl = uiResult.whatsappUrl;
      var orderPath = uiResult.whatsappUrl != null ? 'ui' : 'ninguno';

      // Si el camino de UI no dejó un pedido en este device, igual se crea uno
      // con el MISMO shape de payload que `OrderRepository.createOrder` para no
      // perder la validación del formato del mensaje de WhatsApp — pero NO
      // cuenta como el camino de UI verificado (ver el assert final).
      if (whatsappUrl == null) {
        _log('UI: el checkout no dejó un pedido en este device '
            '(${uiResult.diagnostic}). Fallback: POST directo sólo para validar '
            'el formato del mensaje.');
        whatsappUrl = await _createOrderDirect(productId, sauces.first);
        orderPath = 'directo';
      }

      expect(
        whatsappUrl,
        isNotNull,
        reason: 'No se pudo obtener el whatsappUrl de ningún pedido real.',
      );

      // `Uri.queryParameters` ya percent-decodifica el valor — el backend usa
      // `encodeURIComponent` (espacios como %20, no `+`), así que esto alcanza.
      final decoded = Uri.parse(whatsappUrl!).queryParameters['text'] ?? '';
      _log('whatsappUrl (text decodificado) [camino=$orderPath]:\n$decoded');

      expect(
        decoded,
        contains('$productName (Salsas: $firstSauceName)'),
        reason: 'La línea del ítem con salsa real no trae '
            '"(Salsas: $firstSauceName)".',
      );
      expect(
        decoded,
        contains('$productName (Salsas: Sin salsas)'),
        reason: 'La línea del ítem "Sin salsas" no trae "(Salsas: Sin salsas)".',
      );

      // El ítem 2 del checklist pide verificar en dispositivo real que el texto
      // que la app pasa a `url_launcher` trae las salsas — eso SÓLO queda
      // demostrado si el pedido se creó recorriendo el checkout de la app. Un
      // fallback verde (POST directo del propio test) no debe poder esconder
      // una regresión del checkout: se falla ruidoso si no se tomó el camino de
      // UI.
      expect(
        orderPath,
        'ui',
        reason: 'El pedido NO se creó por el flujo de checkout de la app en '
            'este device (camino="$orderPath"). El formato "(Salsas: ...)" se '
            'validó igual vía POST directo, pero este test exige el camino de '
            'UI para dar el ítem 2 por verificado en dispositivo. '
            'Diagnóstico del checkout: ${uiResult.diagnostic}',
      );
      _log('SALSAS E2E OK — pedido creado por el flujo de UI.');
    },
  );
}

/// Camino de UI: desde el carrito ya cargado, `cart-continue` → checkout →
/// `checkout-confirm` (+ modal de teléfono si aparece). Devuelve el
/// `whatsappUrl` del pedido creado por este camino, o `null` con un
/// `diagnostic` legible de por qué no se pudo (para que el caller decida).
Future<({String? whatsappUrl, String diagnostic})> _orderViaUi(
  WidgetTester tester,
) async {
  final beforeResponse =
      await ApiClient.instance.dio.get<List<dynamic>>('/orders/me');
  final ordersBefore = (beforeResponse.data ?? const []).length;

  await tester.tap(find.byKey(const ValueKey('cart-continue')));
  await tester.pumpAndSettle();

  final confirmReady = await _waitFor(
    tester,
    () => find.byKey(const ValueKey('checkout-confirm')).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
  );
  if (!confirmReady) {
    return (whatsappUrl: null, diagnostic: 'no apareció checkout-confirm en 60s');
  }

  await tester.ensureVisible(find.byKey(const ValueKey('checkout-confirm')));
  await tester.tap(find.byKey(const ValueKey('checkout-confirm')));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  if (find
      .byKey(const ValueKey('checkout-phone-required-dialog'))
      .evaluate()
      .isNotEmpty) {
    _log('UI: modal de teléfono → completando.');
    await tester.enterText(
      find.byKey(const ValueKey('checkout-phone-input')),
      '999888777',
    );
    await tester.tap(find.byKey(const ValueKey('checkout-phone-confirm')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('checkout-phone-confirm-final')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  if (find
      .byKey(const ValueKey('checkout-closed-dialog'))
      .evaluate()
      .isNotEmpty) {
    final message = find.descendant(
      of: find.byKey(const ValueKey('checkout-closed-dialog')),
      matching: find.byType(Text),
    );
    final texts = [
      for (final element in message.evaluate())
        (element.widget as Text).data ?? '',
    ];
    return (
      whatsappUrl: null,
      diagnostic: 'diálogo "Local cerrado" (409 de POST /orders): '
          '${texts.join(" | ")}',
    );
  }

  // Esperar el pedido nuevo. Amplio: `_openWhatsapp` puede quedarse esperando
  // el `launchUrl` en algunos emuladores, pero el pedido ya se creó en el
  // backend antes de eso — se detecta por `GET /orders/me`, no por que la
  // pantalla navegue.
  final deadline = DateTime.now().add(const Duration(seconds: 120));
  while (DateTime.now().isBefore(deadline)) {
    final response =
        await ApiClient.instance.dio.get<List<dynamic>>('/orders/me');
    final orders = response.data ?? const [];
    if (orders.length > ordersBefore) {
      final newest = orders.first as Map<String, dynamic>;
      _log('UI: pedido creado ${newest['id']}.');
      return (whatsappUrl: newest['whatsappUrl'] as String, diagnostic: 'ok');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  return (
    whatsappUrl: null,
    diagnostic: 'no apareció ningún pedido nuevo en GET /orders/me 120s después '
        'de tocar confirmar',
  );
}

/// Crea un pedido con el MISMO shape de payload que
/// `OrderRepository.createOrder`: 2 líneas del mismo producto, una con la
/// primera salsa real y otra con `sauceIds: []` explícito ("Sin salsas").
Future<String?> _createOrderDirect(
  String productId,
  Map<String, dynamic> firstSauce,
) async {
  final addressesResponse =
      await ApiClient.instance.dio.get<List<dynamic>>('/users/me/addresses');
  final addresses =
      (addressesResponse.data ?? const []).cast<Map<String, dynamic>>();
  final addressId = addresses.first['id'] as String;

  // El backend exige teléfono en la cuenta para crear el pedido.
  final me = await ApiClient.instance.dio.get<Map<String, dynamic>>('/users/me');
  final phone = me.data?['phone'] as String?;
  if (phone == null || phone.trim().isEmpty) {
    _log('directo: la cuenta no tiene teléfono → PATCH /users/me.');
    await ApiClient.instance.dio
        .patch<Map<String, dynamic>>('/users/me', data: {'phone': '999888777'});
  }

  try {
    final response = await ApiClient.instance.dio.post<Map<String, dynamic>>(
      '/orders',
      data: {
        'items': [
          {
            'menuItemId': productId,
            'quantity': 1,
            'sauceIds': [firstSauce['id']],
          },
          {
            'menuItemId': productId,
            'quantity': 1,
            'sauceIds': const <String>[],
          },
        ],
        'addressId': addressId,
      },
    );
    _log('directo: pedido creado ${response.data?['id']}.');
    return response.data?['whatsappUrl'] as String?;
  } on DioException catch (e) {
    _log('directo: POST /orders falló '
        '${e.response?.statusCode} → ${e.response?.data}');
    rethrow;
  }
}

/// Lanza la app y deja el menú real cargado (onboarding + login si hace falta).
Future<void> _bootToHome(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: CeltasApp()));

  final bootResolved = await _waitFor(
    tester,
    () =>
        find.text('Bienvenido de nuevo').evaluate().isNotEmpty ||
        find.byKey(const ValueKey('home-cart-icon')).evaluate().isNotEmpty ||
        find.text('COMENZAR').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 75),
  );
  expect(bootResolved, isTrue, reason: 'El Splash no resolvió en 75s.');

  if (find.text('COMENZAR').evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(CeltasButton, 'COMENZAR'));
    await tester.pumpAndSettle();
  }

  if (find.text('Bienvenido de nuevo').evaluate().isNotEmpty) {
    _log('Sin sesión en el dispositivo: iniciando sesión como $_testEmail');
    await tester.enterText(find.byType(TextFormField).at(0), _testEmail);
    await tester.enterText(find.byType(TextFormField).at(1), _testPassword);
    await tester.ensureVisible(find.byType(CeltasButton));
    await tester.tap(find.widgetWithText(CeltasButton, 'INICIAR SESIÓN'));
  }

  final menuLoaded = await _waitFor(
    tester,
    () => _productFinder().evaluate().isNotEmpty,
    timeout: const Duration(seconds: 90),
  );
  expect(menuLoaded, isTrue,
      reason: 'El menú real no cargó en 90s — backend dormido o credenciales '
          'inválidas.');
}

Future<void> _openDetail(WidgetTester tester, String productId) async {
  final card = find.byKey(ValueKey('product-$productId'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('detail-add')), findsOneWidget,
      reason: 'No se abrió el detalle del producto $productId.');
}

Future<void> _tapAdd(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('detail-add')));
  await tester.tap(find.byKey(const ValueKey('detail-add')));
  await tester.pump(); // registra el postFrameCallback del pop diferido
  await tester.pump(const Duration(milliseconds: 400)); // navega
  await tester.pumpAndSettle();
}

Future<void> _ensureAddress(WidgetTester tester) async {
  final response =
      await ApiClient.instance.dio.get<List<dynamic>>('/users/me/addresses');
  if ((response.data ?? const []).isNotEmpty) return;
  _log('La cuenta de prueba no tiene direcciones: creando una para el E2E');
  await ApiClient.instance.dio.post<Map<String, dynamic>>(
    '/users/me/addresses',
    data: {
      'alias': 'Casa (E2E salsas)',
      'fullAddress': 'Av. Los Héroes 123',
      'district': 'San Juan de Miraflores',
      'isDefault': true,
      'latitude': _sjmLat,
      'longitude': _sjmLng,
    },
  );
  await tester.pump();
}

Finder _productFinder() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('product-'),
    );

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return condition();
}
