import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/menu/presentation/product_detail_screen.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  const category = PublicMenuCategory(
    id: 'c-1',
    name: 'Hamburguesa',
    description: 'Hamburguesas artesanales',
    items: [
      PublicMenuItem(
        id: 'i-1',
        name: 'Berserker Burger',
        description: 'Doble carne 100% angus, cheddar añejo y bacon.',
        price: 15.5,
      ),
      PublicMenuItem(
        id: 'i-2',
        name: 'Sin foto',
        price: 9.9,
      ),
    ],
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  Future<ProviderContainer> pumpDetail(
    WidgetTester tester, {
    String productId = 'i-1',
  }) async {
    // Viewport tipo teléfono (390×844 lógicos): el hero de 400px no cabe en el
    // surface default de test (800×600) y el stepper quedaría off-screen.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        publicMenuProvider.overrideWith((ref) async => [category]),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ProductDetailScreen(productId: productId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('muestra nombre, descripción y precio del producto',
      (tester) async {
    await pumpDetail(tester);

    expect(find.text('Berserker Burger'), findsOneWidget);
    expect(
      find.text('Doble carne 100% angus, cheddar añejo y bacon.'),
      findsOneWidget,
    );
    expect(find.text('S/ 15.50'), findsOneWidget);
  });

  testWidgets('producto inexistente → mensaje de no encontrado',
      (tester) async {
    await pumpDetail(tester, productId: 'i-999');

    expect(find.text('Producto no encontrado'), findsOneWidget);
  });

  testWidgets('selector de cantidad: botones + y − con mínimo 1',
      (tester) async {
    await pumpDetail(tester);

    expect(find.text('1'), findsOneWidget);

    // + → 2
    await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // + → 3
    await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    // − → 2
    await tester.tap(find.byKey(const ValueKey('detail-qty-minus')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // − → 1 (mínimo, no baja a 0)
    await tester.tap(find.byKey(const ValueKey('detail-qty-minus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('detail-qty-minus')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('botón muestra el precio multiplicado por la cantidad',
      (tester) async {
    await pumpDetail(tester);

    // Cantidad 1 → 15.50.
    expect(find.text('AGREGAR AL CARRITO · S/ 15.50'), findsOneWidget);

    // Cantidad 3 → 46.50.
    await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
    await tester.pump();
    expect(find.text('AGREGAR AL CARRITO · S/ 46.50'), findsOneWidget);
  });

  testWidgets('agregar al carrito con cantidad seleccionada actualiza el provider',
      (tester) async {
    final container = await pumpDetail(tester);

    await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('detail-add')));
    await tester.pump();

    final state = container.read(cartProvider);
    expect(state.items, hasLength(1));
    expect(state.items.single.menuItemId, 'i-1');
    expect(state.items.single.quantity, 3);
    expect(state.items.single.unitPrice, 15.5);
    expect(state.totalCount, 3);

    // SnackBar de confirmación con opción de ver el carrito.
    expect(find.text('Agregado: Berserker Burger ×3'), findsOneWidget);
    expect(find.text('VER CARRITO'), findsOneWidget);
  });

  testWidgets('agregar el mismo producto desde el detalle suma cantidades',
      (tester) async {
    final container = await pumpDetail(tester);

    await tester.tap(find.byKey(const ValueKey('detail-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('detail-add')));
    await tester.pump();

    expect(container.read(cartProvider).items.single.quantity, 2);
  });

  testWidgets('estado de carga del menú → spinner con aviso de backend lento',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        publicMenuProvider.overrideWith((ref) => Future.any(const [])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ProductDetailScreen(productId: 'i-1'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SlowBackendNotice), findsOneWidget);

    // A los 5s el aviso de backend lento se hace visible.
    await tester.pump(const Duration(seconds: 6));
    expect(
      find.text('El servidor está despertando, puede tardar unos segundos…'),
      findsOneWidget,
    );
  });
}