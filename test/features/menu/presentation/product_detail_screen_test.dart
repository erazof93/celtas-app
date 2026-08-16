import 'dart:async';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:celtas_mobile/features/menu/presentation/product_detail_screen.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  const mayo = SauceOption(id: 's-1', name: 'Mayonesa');
  const mostaza = SauceOption(id: 's-2', name: 'Mostaza');

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
      PublicMenuItem(id: 'i-2', name: 'Sin foto', price: 9.9),
      // Único ítem con salsas del set de prueba: los demás cubren el caso
      // "sin salsas" (arroz chaufa y similares), este cubre el selector.
      PublicMenuItem(
        id: 'i-3',
        name: 'Salsas Burger',
        price: 12,
        sauces: [mayo, mostaza],
      ),
    ],
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  /// Router mínimo: /home (destino del `pop()` tras agregar) y
  /// /product/:id — mismo patrón que `checkout_screen_test.dart` y
  /// `cart_screen_test.dart` para pantallas que navegan con go_router real
  /// en vez de un `MaterialApp(home: ...)` suelto.
  GoRouter router() => GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('HOME')),
          ),
          GoRoute(
            path: '/product/:id',
            builder: (_, state) => ProductDetailScreen(
              productId: state.pathParameters['id']!,
            ),
          ),
        ],
      );

  Future<(ProviderContainer, GoRouter)> pumpDetail(
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
    final goRouter = router();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: goRouter),
      ),
    );
    await tester.pumpAndSettle();
    // Llega al detalle igual que en producción: `push` desde Home — así el
    // `pop()` que dispara "Agregar" tiene a dónde volver.
    unawaited(goRouter.push('/product/$productId'));
    await tester.pumpAndSettle();
    return (container, goRouter);
  }

  testWidgets('muestra nombre, descripción y precio del producto', (
    tester,
  ) async {
    await pumpDetail(tester);

    expect(find.text('Berserker Burger'), findsOneWidget);
    expect(
      find.text('Doble carne 100% angus, cheddar añejo y bacon.'),
      findsOneWidget,
    );
    expect(find.text('S/ 15.50'), findsOneWidget);
  });

  testWidgets('producto inexistente → mensaje de no encontrado', (
    tester,
  ) async {
    await pumpDetail(tester, productId: 'i-999');

    expect(find.text('Producto no encontrado'), findsOneWidget);
  });

  testWidgets('selector de cantidad: botones + y − con mínimo 1', (
    tester,
  ) async {
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

  testWidgets('botón muestra el precio multiplicado por la cantidad', (
    tester,
  ) async {
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

  testWidgets(
    'agregar al carrito con cantidad seleccionada actualiza el provider y '
    'vuelve a Home',
    (tester) async {
      final (container, _) = await pumpDetail(tester);

      await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('detail-add')));
      await tester.pump();
      await tester.pumpAndSettle();

      final state = container.read(cartProvider);
      expect(state.items, hasLength(1));
      expect(state.items.single.menuItemId, 'i-1');
      expect(state.items.single.quantity, 3);
      expect(state.items.single.unitPrice, 15.5);
      expect(state.items.single.selectedSauces, isEmpty);
      expect(state.totalCount, 3);

      // SnackBar de confirmación — vive en el ScaffoldMessenger raíz, sigue
      // visible aunque la pantalla ya haya hecho `pop()`.
      expect(find.text('Agregado: Berserker Burger ×3'), findsOneWidget);
      // Volvió a Home para seguir agregando (pedido explícito del flujo de
      // "captura" normal de la app) — la ruta de detalle ya no está en el
      // Navigator, así que sus elementos desaparecen del árbol (no basta con
      // buscar el texto "HOME": `MaterialPage` mantiene la ruta de abajo
      // montada con `maintainState`, estaría igual de presente sin el pop).
      expect(find.byKey(const ValueKey('detail-add')), findsNothing);
    },
  );

  testWidgets(
    'agregar el mismo producto y misma selección de salsas desde el '
    'detalle suma cantidades (se vuelve a abrir el detalle cada vez)',
    (tester) async {
      final (container, goRouter) = await pumpDetail(tester);

      await tester.tap(find.byKey(const ValueKey('detail-add')));
      await tester.pumpAndSettle();

      // El "Agregar" ya hizo pop a Home — se vuelve a entrar al detalle
      // para simular al usuario agregando el mismo producto de nuevo.
      unawaited(goRouter.push('/product/i-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('detail-add')));
      await tester.pumpAndSettle();

      expect(container.read(cartProvider).items.single.quantity, 2);
    },
  );

  testWidgets(
    'no muestra el ícono de favoritos (fuera de alcance del proyecto)',
    (tester) async {
      await pumpDetail(tester);

      expect(find.byKey(const ValueKey('detail-favorite')), findsNothing);
      // El botón de volver sigue presente, sin el corazón al lado.
      expect(find.byKey(const ValueKey('detail-back')), findsOneWidget);
    },
  );

  testWidgets(
    'body envuelto en SafeArea(top: false) para que el CTA inferior no '
    'quede tapado por la barra de navegación del sistema',
    (tester) async {
      await pumpDetail(tester);

      final safeArea = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safeArea.top, isFalse);
      expect(safeArea.bottom, isTrue);
    },
  );

  testWidgets(
    'el SnackBar de "Agregado" tiene margen suficiente para no quedar '
    'tapado por la barra flotante del carrito del Home',
    (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.byKey(const ValueKey('detail-add')));
      await tester.pump();
      await tester.pumpAndSettle();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 88));
    },
  );

  testWidgets('estado de carga del menú → spinner con aviso de backend lento', (
    tester,
  ) async {
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

  group('selector de salsas/cremas', () {
    testWidgets(
      'producto sin salsas configuradas → no muestra la sección',
      (tester) async {
        await pumpDetail(tester); // i-1, sin sauces

        expect(find.text('SALSAS Y CREMAS'), findsNothing);
      },
    );

    testWidgets(
      'producto con salsas → muestra los chips, ninguno seleccionado '
      'por defecto',
      (tester) async {
        await pumpDetail(tester, productId: 'i-3');

        expect(find.text('SALSAS Y CREMAS'), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-sauce-s-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-sauce-s-2')), findsOneWidget);
        expect(find.text('Mayonesa'), findsOneWidget);
        expect(find.text('Mostaza'), findsOneWidget);
      },
    );

    testWidgets(
      'tocar un chip lo selecciona/deselecciona (multi-selección '
      'independiente)',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await tester.tap(find.byKey(const ValueKey('detail-sauce-s-1')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pump();

        final selected = container
            .read(cartProvider)
            .items
            .single
            .selectedSauces
            .map((s) => s.name)
            .toList();
        expect(selected, ['Mayonesa']);
      },
    );

    testWidgets(
      'agregar sin seleccionar ninguna salsa guarda la fila sin salsas '
      '(selección opcional)',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pump();

        expect(
          container.read(cartProvider).items.single.selectedSauces,
          isEmpty,
        );
      },
    );

    testWidgets(
      'agregar el mismo producto con distinta selección de salsas crea '
      'una fila aparte en el carrito (no fusiona)',
      (tester) async {
        final (container, goRouter) = await pumpDetail(
          tester,
          productId: 'i-3',
        );

        // Primera pasada: sin salsas.
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        // Segunda pasada: con Mayonesa.
        unawaited(goRouter.push('/product/i-3'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('detail-sauce-s-1')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final state = container.read(cartProvider);
        expect(state.items, hasLength(2));
        expect(state.totalCount, 2);
      },
    );
  });

  group('modo edición (editingItem, ícono de lápiz del carrito)', () {
    /// Router con `/cart` como origen (destino real del `pop()` en modo
    /// edición, ver doc de `editingItem` en `product_detail_screen.dart`) y
    /// `/product/:id` leyendo `editingItem` de `state.extra` — mismo mapeo
    /// que hace `app_router.dart` de verdad.
    GoRouter editRouter() => GoRouter(
          initialLocation: '/cart',
          routes: [
            GoRoute(
              path: '/cart',
              builder: (_, _) => const Scaffold(body: Text('CART')),
            ),
            GoRoute(
              path: '/product/:id',
              builder: (_, state) => ProductDetailScreen(
                productId: state.pathParameters['id']!,
                editingItem: state.extra as CartItem?,
              ),
            ),
          ],
        );

    /// Arranca en `/cart` con el carrito ya poblado por `seed` (agrega la
    /// fila que se va a editar, y opcionalmente otras) y navega a
    /// `/product/:id` en modo edición, igual que el ícono de lápiz real de
    /// `cart_screen.dart`.
    Future<(ProviderContainer, GoRouter)> pumpEdit(
      WidgetTester tester, {
      required void Function(CartNotifier notifier) seed,
      required String Function(CartState state) pickEditingLineKey,
      required String productId,
    }) async {
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
      seed(container.read(cartProvider.notifier));
      final editingLineKey = pickEditingLineKey(container.read(cartProvider));
      final editingItem = container
          .read(cartProvider)
          .items
          .firstWhere((i) => i.lineKey == editingLineKey);

      final goRouter = editRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: goRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(goRouter.push('/product/$productId', extra: editingItem));
      await tester.pumpAndSettle();
      return (container, goRouter);
    }

    testWidgets(
      'precarga la cantidad y las salsas de la fila que se está editando, '
      'y el botón dice GUARDAR CAMBIOS',
      (tester) async {
        await pumpEdit(
          tester,
          seed: (notifier) => notifier.addItem(
            category.items.firstWhere((i) => i.id == 'i-3'),
            quantity: 3,
            selectedSauces: const [mayo],
          ),
          pickEditingLineKey: (state) => state.items.single.lineKey,
          productId: 'i-3',
        );

        // Cantidad precargada (no arranca en 1).
        expect(find.text('3'), findsOneWidget);
        // Botón de confirmar en modo edición, sin el precio.
        expect(find.text('GUARDAR CAMBIOS'), findsOneWidget);
        expect(find.textContaining('AGREGAR AL CARRITO'), findsNothing);
        // Mayonesa (única salsa de la fila editada) aparece seleccionada —
        // el chip seleccionado es el único que muestra el ícono de check.
        expect(find.byIcon(Icons.check), findsOneWidget);
      },
    );

    testWidgets(
      'GUARDAR CAMBIOS actualiza la fila correcta (misma cantidad de filas, '
      'sin duplicar) y vuelve al carrito, no a Home',
      (tester) async {
        final (container, _) = await pumpEdit(
          tester,
          seed: (notifier) => notifier.addItem(
            category.items.firstWhere((i) => i.id == 'i-3'),
            quantity: 2,
            selectedSauces: const [mayo],
          ),
          pickEditingLineKey: (state) => state.items.single.lineKey,
          productId: 'i-3',
        );

        // Sube la cantidad de 2 a 4 antes de guardar.
        await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pump();
        await tester.pumpAndSettle();

        final state = container.read(cartProvider);
        expect(state.items, hasLength(1)); // sigue siendo una sola fila
        expect(state.items.single.quantity, 4);
        expect(state.items.single.selectedSauces, [mayo]);

        // Volvió al carrito (de donde se navegó en modo edición), no a
        // Home — `/product/:id` en este flujo siempre se llega con `push`
        // desde `/cart`.
        expect(find.text('CART'), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-add')), findsNothing);
      },
    );

    testWidgets(
      'si la edición hace coincidir la combinación de salsas con otra fila '
      'ya existente del mismo producto, se fusionan sumando cantidades '
      '(no quedan dos filas duplicadas)',
      (tester) async {
        final salsasBurger = category.items.firstWhere((i) => i.id == 'i-3');
        final (container, _) = await pumpEdit(
          tester,
          seed: (notifier) {
            notifier.addItem(salsasBurger, selectedSauces: const [mayo]);
            notifier.addItem(
              salsasBurger,
              quantity: 3,
              selectedSauces: const [mostaza],
            );
          },
          pickEditingLineKey: (state) => state.items
              .firstWhere((i) => i.selectedSauces.contains(mostaza))
              .lineKey,
          productId: 'i-3',
        );

        // La fila editada trae "Mostaza" precargada: se deselecciona y se
        // elige "Mayonesa" en su lugar — esa combinación ya la tiene la
        // otra fila del carrito.
        await tester.tap(find.byKey(const ValueKey('detail-sauce-s-2')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('detail-sauce-s-1')));
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pump();
        await tester.pumpAndSettle();

        final state = container.read(cartProvider);
        expect(state.items, hasLength(1)); // se fusionaron en una sola fila
        expect(state.items.single.lineKey, 'i-3::s-1');
        // 1 (fila original con mayo) + 3 (fila editada, fusionada) = 4.
        expect(state.items.single.quantity, 4);
      },
    );
  });
}
