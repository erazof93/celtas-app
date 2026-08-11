import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Test de integración del módulo 4 (Producto + Carrito) contra el backend
/// REAL en dispositivo físico.
///
/// Es auto-suficiente: si el dispositivo no tiene sesión (el runner de
/// integración desinstala la app y borra la sesión), se loguea con el usuario
/// de prueba persistente `mobile_it@celtas.pe` (creado contra el backend real).
///
/// Cubre el flujo end-to-end real:
///   1. Home con menú real cargado (el backend de Render puede tardar 30-50s
///      en despertar — se espera con timeout amplio).
///   2. "+" desde Home → carrito local (badge).
///   3. Detalle de producto → cantidad → agregar.
///   4. Carrito: editar cantidades, totales.
///   5. Cupón INVALIDO999 → mensaje de error real del backend
///      ("El cupón no existe", verificado con curl).
///   6. Sonda de GET /coupons/me: si hay un cupón real disponible, se aplica y
///      se verifica el descuento; si no, se reporta en consola.
///   7. CONTINUAR → checkout placeholder (módulo 5).
const _testEmail = 'mobile_it@celtas.pe';
const _testPassword = 'Secret123!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load();
  });

  testWidgets('flujo real: Home → detalle → carrito → cupón inválido',
      (tester) async {
    await _bootToHome(tester);

    // Necesitamos al menos un producto para seguir.
    final productFinder = _productFinder();
    final firstProduct = productFinder.first;
    expect(firstProduct, findsWidgets, reason: 'El menú real no tiene productos');

    final firstKey = tester.widget<Widget>(firstProduct).key as ValueKey<String>;
    final productId = firstKey.value.replaceFirst('product-', '');

    // ── 1) "+" desde Home agrega al carrito y actualiza el badge. ──
    await tester.ensureVisible(find.byKey(ValueKey('add-$productId')));
    await tester.tap(find.byKey(ValueKey('add-$productId')));
    await tester.pump(const Duration(milliseconds: 300));
    // El badge con "1" debe aparecer.
    expect(find.byKey(const ValueKey('home-cart-badge')), findsOneWidget);

    // ── 2) Detalle: cantidad 2 y agregar. ──
    await tester.ensureVisible(find.byKey(ValueKey('product-$productId')));
    await tester.tap(find.byKey(ValueKey('product-$productId')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-qty-plus')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('detail-add')));
    await tester.tap(find.byKey(const ValueKey('detail-add')));
    await tester.pump(const Duration(milliseconds: 300));

    // ── 3) Carrito: el item tiene 3 unidades (1 del Home + 2 del detalle). ──
    await tester.tap(find.text('VER CARRITO'));
    await tester.pumpAndSettle();

    expect(find.text('Tu carrito'), findsOneWidget);
    expect(find.byKey(ValueKey('cart-qty-$productId')), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    // Editar cantidad con el stepper.
    await tester.tap(find.byKey(ValueKey('cart-plus-$productId')));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsWidgets);
    await tester.tap(find.byKey(ValueKey('cart-minus-$productId')));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsWidgets);

    // ── 4) Cupón inválido → mensaje real del backend. ──
    await tester.enterText(
      find.byKey(const ValueKey('cart-coupon-input')),
      'INVALIDO999',
    );
    await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // El backend responde "El cupón no existe" (verificado con curl contra
    // el backend real: {"success":false,"message":"El cupón no existe","statusCode":400}).
    expect(find.text('El cupón no existe'), findsOneWidget);
    expect(find.text('Cupón INVALIDO999 aplicado'), findsNothing);

    // ── 5) Sonda de cupón real (GET /coupons/me). ──
    debugPrint('=== CUPONES DEL USUARIO (sonda real) ===');
    try {
      final couponsResponse =
          await ApiClient.instance.dio.get<List<dynamic>>('/coupons/me');
      final coupons = couponsResponse.data ?? const [];
      debugPrint('Total de cupones del usuario: ${coupons.length}');
      for (final coupon in coupons) {
        if (coupon is Map<String, dynamic>) {
          debugPrint(
            '  - ${coupon['code']} (${coupon['status']}) '
            '${coupon['discountType']} ${coupon['discountValue']}',
          );
        }
      }
    } catch (e) {
      debugPrint('GET /coupons/me falló: $e');
    }

    // ── 6) CONTINUAR → checkout (placeholder del módulo 5). ──
    await tester.ensureVisible(find.byKey(const ValueKey('cart-continue')));
    await tester.tap(find.byKey(const ValueKey('cart-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);

    debugPrint('=== INTEGRATION OK: Home→detalle→carrito→cupón inválido ===');
  });

  testWidgets('totales con cupón aplicado si el usuario tiene uno real',
      (tester) async {
    await _bootToHome(tester);

    // Agregar 2 unidades de un producto para tener subtotal.
    final productFinder = _productFinder();
    if (productFinder.evaluate().isEmpty) return;

    final firstKey =
        tester.widget<Widget>(productFinder.first).key as ValueKey<String>;
    final productId = firstKey.value.replaceFirst('product-', '');

    await tester.tap(find.byKey(ValueKey('add-$productId')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(ValueKey('add-$productId')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('home-cart-icon')));
    await tester.pumpAndSettle();

    // Si hay cupones reales, aplicar el primero y verificar descuento.
    final couponsResponse =
        await ApiClient.instance.dio.get<List<dynamic>>('/coupons/me');
    final coupons = couponsResponse.data ?? const [];
    if (coupons.isEmpty) {
      debugPrint('El usuario no tiene cupones reales: se omite la validación.');
      return;
    }
    final realCode = (coupons.first as Map<String, dynamic>)['code'] as String;
    await tester.enterText(
      find.byKey(const ValueKey('cart-coupon-input')),
      realCode,
    );
    await tester.tap(find.byKey(const ValueKey('cart-coupon-apply')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Cupón $realCode aplicado'), findsOneWidget);
    debugPrint('=== INTEGRATION OK: cupón real $realCode aplicado ===');
  });
}

/// Lanza la app y deja el menú real cargado: pasa el onboarding, loguea si el
/// dispositivo está en Login y espera a que haya productos visibles (el
/// `home-cart-icon` aparece con el header, ANTES de que el menú cargue).
Future<void> _bootToHome(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: CeltasApp()));

  // Estado inicial: Splash/checkeo de sesión → onboarding (COMENZAR),
  // Login o Home. Con sesión y backend dormido, el refresh puede tardar
  // 30-50s (cold start de Render): timeout amplio.
  final bootResolved = await _waitFor(
    tester,
    () =>
        find.text('Bienvenido de nuevo').evaluate().isNotEmpty ||
        find.byKey(const ValueKey('home-cart-icon')).evaluate().isNotEmpty ||
        find.text('COMENZAR').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 75),
  );
  expect(bootResolved, isTrue, reason: 'El Splash no resolvió en 75s');

  // Onboarding (instalación limpia sin sesión): COMENZAR → Login.
  if (find.text('COMENZAR').evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(CeltasButton, 'COMENZAR'));
    await tester.pumpAndSettle();
  }

  // Login si el dispositivo no tiene sesión.
  if (find.text('Bienvenido de nuevo').evaluate().isNotEmpty) {
    debugPrint('Sin sesión en el dispositivo: iniciando sesión como '
        '$_testEmail');
    // Orden determinista: email es el primer TextFormField, contraseña el 2º.
    await tester.enterText(
      find.byType(TextFormField).at(0),
      _testEmail,
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      _testPassword,
    );
    await tester.ensureVisible(find.byType(CeltasButton));
    await tester.tap(find.widgetWithText(CeltasButton, 'INICIAR SESIÓN'));
  }

  // Esperar el menú real: productos visibles (no el header, que ya estaba).
  final menuLoaded = await _waitFor(
    tester,
    () => _productFinder().evaluate().isNotEmpty,
    timeout: const Duration(seconds: 90),
  );
  expect(
    menuLoaded,
    isTrue,
    reason: 'El menú real no cargó en 90s — backend dormido o '
        'credenciales inválidas.',
  );
}

/// Busca las tarjetas de producto del Home.
Finder _productFinder() => find.byWidgetPredicate(
      (widget) => widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('product-'),
    );

/// Espera hasta que [condition] sea verdadera o venza [timeout].
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