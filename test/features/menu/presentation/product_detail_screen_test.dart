import 'dart:async';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/beverage_option.dart';
import 'package:celtas_mobile/features/home/data/models/extra_portion_option.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:celtas_mobile/features/menu/presentation/product_detail_screen.dart';
import 'package:celtas_mobile/shared/widgets/celtas_button.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  const mayo = SauceOption(id: 's-1', name: 'Mayonesa');
  const mostaza = SauceOption(id: 's-2', name: 'Mostaza');
  const cocaCola = BeverageOption(id: 'b-1', name: 'Coca-Cola 500ml', price: 3);
  const incaKola = BeverageOption(id: 'b-2', name: 'Inca Kola 500ml', price: 3);
  const papasExtra = ExtraPortionOption(
    id: 'e-1',
    name: 'Papas extra',
    price: 5,
  );
  const quesoExtra = ExtraPortionOption(
    id: 'e-2',
    name: 'Queso extra',
    price: 4,
  );

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
        // Sin `groupRequired` (opcional, default `false`), max = todo el
        // catálogo de prueba (2) para permitir elegir ambas a la vez —
        // mismo criterio que los fixtures opcionales de bebidas/porciones
        // extras (i-4/i-6), que también fijan su propio máximo explícito.
        sauceGroupMaxSelectable: 2,
      ),
      // Bebidas opcionales, máximo 1 (para poder violar el máximo con 2
      // opciones reales, sin necesitar una tercera).
      PublicMenuItem(
        id: 'i-4',
        name: 'Combo Bebida Opcional',
        price: 18,
        beverages: [cocaCola, incaKola],
        beverageGroupMaxSelectable: 1,
      ),
      // Bebidas obligatorias, máximo 1.
      PublicMenuItem(
        id: 'i-5',
        name: 'Combo Bebida Obligatoria',
        price: 20,
        beverages: [cocaCola, incaKola],
        beverageGroupRequired: true,
        beverageGroupMaxSelectable: 1,
      ),
      // Porciones extras opcionales, máximo 1.
      PublicMenuItem(
        id: 'i-6',
        name: 'Combo Extra Opcional',
        price: 22,
        extraPortions: [papasExtra, quesoExtra],
        extraPortionsGroupMaxSelectable: 1,
      ),
      // Porciones extras obligatorias, máximo 1.
      PublicMenuItem(
        id: 'i-7',
        name: 'Combo Extra Obligatoria',
        price: 24,
        extraPortions: [papasExtra, quesoExtra],
        extraPortionsGroupRequired: true,
        extraPortionsGroupMaxSelectable: 1,
      ),
      // Salsas obligatorias, máximo 1 — mismo criterio que bebidas/porciones
      // extras obligatorias (`sauceGroupRequired`/`Max`, ver
      // `menu.service.ts`/`OrdersService.validateGroupSelection` en el
      // backend real).
      PublicMenuItem(
        id: 'i-8',
        name: 'Combo Salsa Obligatoria',
        price: 26,
        sauces: [mayo, mostaza],
        sauceGroupRequired: true,
        sauceGroupMaxSelectable: 1,
      ),
      // Bebidas opcionales con `beverageAllowWithout: false` — el admin
      // desactivó el checkbox "Sin bebida" para este producto (mismo
      // catálogo/máximo que i-4, que lo deja en su default `true`).
      PublicMenuItem(
        id: 'i-9',
        name: 'Combo Bebida Sin Opción Vacía',
        price: 19,
        beverages: [cocaCola, incaKola],
        beverageGroupMaxSelectable: 1,
        beverageAllowWithout: false,
      ),
      // Salsas opcionales dejando `sauceAllowWithout` en su default (`true`,
      // sin fijarlo a mano — `avoid_redundant_argument_values` marcaría el
      // valor explícito por coincidir con el default) — confirma que el
      // contrato real (`GET /menu` sin el campo) se resuelve a `true` y el
      // checkbox "Sin salsas" se ofrece igual que si el admin lo hubiera
      // marcado a mano.
      PublicMenuItem(
        id: 'i-10',
        name: 'Salsas Burger Con Opción Vacía Por Default',
        price: 13,
        sauces: [mayo, mostaza],
        sauceGroupMaxSelectable: 2,
      ),
      // Porciones extras OBLIGATORIAS, dejando `extraPortionsAllowWithout`
      // en su default (`true`) — confirma que el flag no tiene efecto en un
      // grupo obligatorio: "Sin X" nunca es válido ahí (ver doc de
      // `_OptionGroupDropdown.allowWithout`), así que el checkbox se sigue
      // ocultando igual que en i-7 (mismo fixture en la práctica, separado
      // para dejar el caso documentado con su propio test).
      PublicMenuItem(
        id: 'i-11',
        name: 'Combo Extra Obligatoria Con Flag Explícito',
        price: 25,
        extraPortions: [papasExtra, quesoExtra],
        extraPortionsGroupRequired: true,
        extraPortionsGroupMaxSelectable: 1,
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

  // ─── Helpers del patrón dropdown + diálogo de checkboxes ────────────────
  // (`_OptionGroupDropdown` en `product_detail_screen.dart`) — reemplazó el
  // selector de chips horizontales de una iteración anterior. `testKey` es
  // el prefijo de cada grupo: 'sauce'/'beverage'/'extra'.

  /// Toca el campo tipo dropdown, que abre el diálogo con los checkboxes.
  Future<void> openDropdown(WidgetTester tester, String testKey) async {
    await tester.tap(find.byKey(ValueKey('detail-$testKey-dropdown')));
    await tester.pumpAndSettle();
  }

  /// Toca un checkbox YA con el diálogo abierto — `optionId` real (ej.
  /// `'s-1'`) o `'none'` para el checkbox "Sin X". No cierra el diálogo.
  Future<void> tapDialogOption(
    WidgetTester tester,
    String testKey,
    String optionId,
  ) async {
    await tester.tap(find.byKey(ValueKey('detail-$testKey-option-$optionId')));
    await tester.pump();
  }

  /// Confirma el diálogo (aplica la selección temporal al estado real).
  Future<void> confirmDialog(WidgetTester tester, String testKey) async {
    await tester.tap(find.byKey(ValueKey('detail-$testKey-dialog-ok')));
    await tester.pumpAndSettle();
  }

  /// Cierra el diálogo sin aplicar la selección temporal.
  Future<void> cancelDialog(WidgetTester tester, String testKey) async {
    await tester.tap(find.byKey(ValueKey('detail-$testKey-dialog-cancel')));
    await tester.pumpAndSettle();
  }

  /// Atajo para el caso más común: abrir el diálogo, tocar una o varias
  /// opciones en orden, y confirmar con ACEPTAR.
  Future<void> selectDialogOptions(
    WidgetTester tester,
    String testKey,
    List<String> optionIds,
  ) async {
    await openDropdown(tester, testKey);
    for (final optionId in optionIds) {
      await tapDialogOption(tester, testKey, optionId);
    }
    await confirmDialog(tester, testKey);
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

  group('selector de salsas/cremas (dropdown + diálogo)', () {
    testWidgets(
      'producto sin salsas configuradas → no muestra la sección',
      (tester) async {
        await pumpDetail(tester); // i-1, sin sauces

        expect(find.text('SALSAS Y CREMAS'), findsNothing);
      },
    );

    testWidgets(
      'hero de 270px deja el selector de salsas dentro del viewport '
      'visible SIN deslizar, en un producto con salsas (mismo viewport '
      '390×844 lógicos que usa `pumpDetail`, hallazgo de UX real en '
      'dispositivo — ver doc-comment de `_ProductDetailBody`)',
      (tester) async {
        await pumpDetail(tester, productId: 'i-3');

        // Viewport lógico real (physicalSize / devicePixelRatio) — sin
        // scrollear nada tras el pump inicial.
        final logicalHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;

        final dropdownBottom = tester
            .getBottomRight(
              find.byKey(const ValueKey('detail-sauce-dropdown')),
            )
            .dy;

        expect(
          dropdownBottom,
          lessThanOrEqualTo(logicalHeight),
          reason:
              'El campo de salsas debe quedar visible sin deslizar en un '
              'celular de ~6.1" (viewport de prueba: 390×844 lógicos)',
        );
      },
    );

    testWidgets(
      'producto con salsas → muestra el campo dropdown con el placeholder '
      '"Elige tus cremas" (nada elegido por defecto, sin etiqueta '
      '"Obligatorio")',
      (tester) async {
        await pumpDetail(tester, productId: 'i-3');

        expect(find.text('SALSAS Y CREMAS'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('detail-sauce-dropdown')),
          findsOneWidget,
        );
        // Sin nada elegido el campo muestra el placeholder del grupo — ver
        // `_OptionGroupDropdown.hintText`.
        expect(find.text('Elige tus cremas'), findsOneWidget);
        expect(find.text('Listo'), findsNothing);
        expect(find.text('✓ Seleccionado'), findsNothing);
        // i-3 no tiene `sauceGroupRequired` configurado (default `false`,
        // ver fixture) — el campo no muestra la etiqueta "Obligatorio". Un
        // producto con salsas obligatorias SÍ la muestra, ver el grupo
        // "salsas obligatorias" más abajo (fixture i-8).
        expect(find.text('Obligatorio'), findsNothing);
      },
    );

    testWidgets(
      'tocar el dropdown abre el diálogo con un checkbox por salsa y el '
      'checkbox "Sin salsas"',
      (tester) async {
        await pumpDetail(tester, productId: 'i-3');

        await openDropdown(tester, 'sauce');

        expect(find.text('Mayonesa'), findsOneWidget);
        expect(find.text('Mostaza'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('detail-sauce-option-s-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('detail-sauce-option-s-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('detail-sauce-option-none')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'elegir una salsa y tocar ACEPTAR actualiza el resumen del dropdown '
      'a "✓ Seleccionado" y muestra el badge "Listo" (grupo opcional con '
      'una selección real) y agrega la fila con esa selección',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await selectDialogOptions(tester, 'sauce', ['s-1']);

        // Resumen del campo, ya cerrado el diálogo: "✓ Seleccionado" +
        // badge "Listo" (verde) — un grupo opcional CON selección real
        // también muestra el badge, no solo los obligatorios (ver
        // `_OptionGroupDropdown._badge`). El nombre real de la salsa no se
        // muestra acá — el detalle de qué se eligió solo se ve abriendo el
        // diálogo (ver `_OptionGroupDropdown._summaryText`).
        expect(find.text('✓ Seleccionado'), findsOneWidget);
        expect(find.text('Listo'), findsOneWidget);
        expect(find.text('Mayonesa'), findsNothing);
        // El placeholder ya no se muestra: el campo dejó de estar vacío.
        expect(find.text('Elige tus cremas'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

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
      'CANCELAR descarta la marca hecha dentro del diálogo — el resumen '
      'del dropdown no cambia',
      (tester) async {
        await pumpDetail(tester, productId: 'i-3');

        await openDropdown(tester, 'sauce');
        await tapDialogOption(tester, 'sauce', 's-1');
        await cancelDialog(tester, 'sauce');

        // Sigue en blanco: la marca dentro del diálogo nunca se aplicó.
        expect(find.text('✓ Seleccionado'), findsNothing);
        expect(find.text('Listo'), findsNothing);
      },
    );

    testWidgets(
      'sin elegir ninguna opción, tocar "Agregar" agrega la fila igual '
      '— i-3 es un grupo opcional (`sauceGroupRequired: false`) y no '
      'bloquea nada sin importar la selección',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedSauces, isEmpty);
        expect(item.explicitlyNoSauces, isFalse);
      },
    );

    testWidgets(
      'elegir DOS salsas reales a la vez (multi-selección genuina, no '
      'solo una tras otra) sigue mostrando "✓ Seleccionado" + badge '
      '"Listo" (no cuenta cuántas) y agrega la fila con las dos',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await selectDialogOptions(tester, 'sauce', ['s-1', 's-2']);

        // Resumen del campo: "✓ Seleccionado" + badge "Listo", sin importar
        // cuántas se eligieron — no es un contador.
        expect(find.text('✓ Seleccionado'), findsOneWidget);
        expect(find.text('Listo'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final selected = container
            .read(cartProvider)
            .items
            .single
            .selectedSauces
            .map((s) => s.name)
            .toList();
        expect(selected, containsAll(['Mayonesa', 'Mostaza']));
        expect(selected, hasLength(2));
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

        // Primera pasada: "Sin salsas" explícito.
        await selectDialogOptions(tester, 'sauce', ['none']);
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        // Segunda pasada: con Mayonesa.
        unawaited(goRouter.push('/product/i-3'));
        await tester.pumpAndSettle();
        await selectDialogOptions(tester, 'sauce', ['s-1']);
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final state = container.read(cartProvider);
        expect(state.items, hasLength(2));
        expect(state.totalCount, 2);
      },
    );

    testWidgets(
      'producto con salsas: el botón de agregar arranca HABILITADO sin '
      'elegir nada — grupo opcional, no hay elección forzada',
      (tester) async {
        await pumpDetail(tester, productId: 'i-3');

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'elegir una salsa real mantiene el botón habilitado y agrega la '
      'fila con esa selección',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await selectDialogOptions(tester, 'sauce', ['s-1']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);
        expect(button.onPressed, isNotNull);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        expect(container.read(cartProvider).items.single.selectedSauces, [
          mayo,
        ]);
      },
    );

    testWidgets(
      'elegir "Sin salsas" agrega la fila con explicitlyNoSauces=true y '
      'selectedSauces vacío',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await selectDialogOptions(tester, 'sauce', ['none']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.onPressed, isNotNull);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedSauces, isEmpty);
        expect(item.explicitlyNoSauces, isTrue);
      },
    );

    testWidgets(
      '"Sin salsas" y las salsas reales son mutuamente excluyentes dentro '
      'del mismo diálogo, en ambos sentidos',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        // "Sin salsas" → Mayonesa dentro del MISMO diálogo: desmarca "Sin
        // salsas" antes de confirmar, así que al agregar viaja
        // explicitlyNoSauces en false con la salsa real seleccionada.
        await openDropdown(tester, 'sauce');
        await tapDialogOption(tester, 'sauce', 'none');
        await tapDialogOption(tester, 'sauce', 's-1');
        await confirmDialog(tester, 'sauce');

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();
        final firstItem = container.read(cartProvider).items.single;
        expect(firstItem.explicitlyNoSauces, isFalse);
        expect(firstItem.selectedSauces, [mayo]);
      },
    );

    testWidgets(
      'Mayonesa → "Sin salsas" dentro del mismo diálogo limpia la '
      'selección real',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-3');

        await openDropdown(tester, 'sauce');
        await tapDialogOption(tester, 'sauce', 's-1');
        await tapDialogOption(tester, 'sauce', 'none');
        await confirmDialog(tester, 'sauce');

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();
        final item = container.read(cartProvider).items.single;
        expect(item.explicitlyNoSauces, isTrue);
        expect(item.selectedSauces, isEmpty);
      },
    );

    testWidgets(
      'salsas obligatorias: el campo muestra el badge "Obligatorio" dentro '
      'del dropdown mientras no hay nada elegido',
      (tester) async {
        await pumpDetail(tester, productId: 'i-8');

        expect(find.text('Obligatorio'), findsOneWidget);
      },
    );

    testWidgets(
      'salsas obligatorias: el badge del campo pasa de "Obligatorio" (nada '
      'elegido) a "Listo" (verde) apenas se elige una salsa',
      (tester) async {
        await pumpDetail(tester, productId: 'i-8');

        expect(find.text('Obligatorio'), findsOneWidget);
        expect(find.text('Listo'), findsNothing);

        await selectDialogOptions(tester, 'sauce', ['s-1']);

        expect(find.text('Obligatorio'), findsNothing);
        expect(find.text('Listo'), findsOneWidget);
        expect(find.text('✓ Seleccionado'), findsNothing);
      },
    );

    testWidgets(
      'salsas obligatorias: el diálogo no ofrece el checkbox "Sin salsas" '
      'y el botón arranca deshabilitado',
      (tester) async {
        await pumpDetail(tester, productId: 'i-8');

        await openDropdown(tester, 'sauce');
        expect(
          find.byKey(const ValueKey('detail-sauce-option-none')),
          findsNothing,
        );
        await cancelDialog(tester, 'sauce');

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isFalse);
      },
    );

    testWidgets(
      'salsas obligatorias: elegir una salsa habilita el botón y agrega la '
      'fila con la salsa elegida',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-8');

        await selectDialogOptions(tester, 'sauce', ['s-1']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedSauces, [mayo]);
        expect(item.explicitlyNoSauces, isFalse);
      },
    );

    testWidgets(
      'salsas obligatorias: seleccionar más salsas que el máximo permitido '
      'bloquea el botón y muestra el aviso "Máximo X" en el SnackBar al '
      'tocar "Agregar"',
      (tester) async {
        await pumpDetail(tester, productId: 'i-8'); // max = 1

        await selectDialogOptions(tester, 'sauce', ['s-1', 's-2']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isFalse);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Máximo 1 salsa'),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 900));
      },
    );

    testWidgets(
      'producto sin catálogo de salsas: el botón sigue habilitado sin '
      'elección (validación no aplica)',
      (tester) async {
        await pumpDetail(tester); // i-1, sin sauces

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);
        expect(button.onPressed, isNotNull);
      },
    );
  });

  group('selector de bebidas (dropdown + diálogo)', () {
    testWidgets('producto sin bebidas configuradas → no muestra la sección', (
      tester,
    ) async {
      await pumpDetail(tester); // i-1, sin beverages

      expect(find.text('BEBIDAS'), findsNothing);
    });

    testWidgets(
      'producto con bebidas opcionales → el diálogo muestra cada opción '
      'con su precio, y el checkbox "Sin bebida"',
      (tester) async {
        await pumpDetail(tester, productId: 'i-4');

        expect(find.text('BEBIDAS'), findsOneWidget);
        await openDropdown(tester, 'beverage');

        expect(find.text('Coca-Cola 500ml — S/3.00'), findsOneWidget);
        expect(find.text('Inca Kola 500ml — S/3.00'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('detail-beverage-option-none')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'bebidas opcionales: el campo no muestra la etiqueta "Obligatorio", '
      'y arranca con el placeholder "Elige tus bebidas" (sin "Listo" ni '
      '"✓ Seleccionado") sin nada elegido',
      (tester) async {
        await pumpDetail(tester, productId: 'i-4');

        expect(find.text('Obligatorio'), findsNothing);
        expect(find.text('Listo'), findsNothing);
        expect(find.text('✓ Seleccionado'), findsNothing);
        expect(find.text('Elige tus bebidas'), findsOneWidget);
      },
    );

    testWidgets(
      'bebidas opcionales: el botón arranca HABILITADO sin elegir nada '
      '— grupo opcional, no hay elección forzada (mismo criterio de '
      'negocio que las salsas)',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-4');

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedBeverages, isEmpty);
        expect(item.explicitlyNoBeverages, isFalse);
      },
    );

    testWidgets(
      'elegir una bebida y ACEPTAR muestra "✓ Seleccionado" + badge "Listo" '
      'en el resumen (grupo opcional con una selección real) y suma el '
      'precio de la bebida al total del botón',
      (tester) async {
        await pumpDetail(tester, productId: 'i-4');

        await selectDialogOptions(tester, 'beverage', ['b-1']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);
        expect(find.text('✓ Seleccionado'), findsOneWidget);
        expect(find.text('Listo'), findsOneWidget);
        expect(find.text('Coca-Cola 500ml — S/3.00'), findsNothing);
        expect(find.text('Elige tus bebidas'), findsNothing);
        // 18 (i-4) + 3 (Coca-Cola) = 21.
        expect(find.text('AGREGAR AL CARRITO · S/ 21.00'), findsOneWidget);
      },
    );

    testWidgets(
      'elegir "Sin bebida" habilita el botón y agrega la fila con '
      'explicitlyNoBeverages=true y selectedBeverages vacío',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-4');

        await selectDialogOptions(tester, 'beverage', ['none']);
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedBeverages, isEmpty);
        expect(item.explicitlyNoBeverages, isTrue);
      },
    );

    testWidgets(
      'seleccionar más bebidas que el máximo permitido dentro del mismo '
      'diálogo bloquea el botón y muestra el aviso "Máximo X" en el '
      'SnackBar al tocar "Agregar" — esta validación NO cambió con el '
      'punto 1 (es una regla distinta a la de "elección forzada")',
      (tester) async {
        await pumpDetail(tester, productId: 'i-4'); // max = 1

        await selectDialogOptions(tester, 'beverage', ['b-1', 'b-2']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isFalse);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Máximo 1 bebida'),
          ),
          findsOneWidget,
        );
        // Deja correr el `Future.delayed(800ms)` del resalte antes de que
        // termine el test (ver grupo "aviso de campo bloqueante...").
        await tester.pump(const Duration(milliseconds: 900));
      },
    );

    testWidgets(
      'bebidas obligatorias: el campo muestra el badge "Obligatorio" '
      'dentro del dropdown mientras no hay nada elegido',
      (tester) async {
        await pumpDetail(tester, productId: 'i-5');

        expect(find.text('Obligatorio'), findsOneWidget);
      },
    );

    testWidgets(
      'bebidas obligatorias: el badge del campo pasa de "Obligatorio" '
      '(nada elegido) a "Listo" (verde) apenas se elige una bebida, y el '
      'placeholder "Elige tus bebidas" se mantiene en ambos casos (el '
      'resumen de un grupo obligatorio siempre queda en blanco, el badge '
      'lleva la señal real de "completo")',
      (tester) async {
        await pumpDetail(tester, productId: 'i-5');

        expect(find.text('Obligatorio'), findsOneWidget);
        expect(find.text('Listo'), findsNothing);
        expect(find.text('Elige tus bebidas'), findsOneWidget);

        await selectDialogOptions(tester, 'beverage', ['b-1']);

        expect(find.text('Obligatorio'), findsNothing);
        // Un solo "Listo": el badge (`_RequiredBadge`, verde) — el resumen
        // del campo queda en blanco con una selección real en un grupo
        // obligatorio (`_OptionGroupDropdown._summaryText` corta antes con
        // `if (groupRequired) return '';`), nunca dice "✓ Seleccionado" (esa
        // señal es solo para grupos opcionales, que no tienen badge). El
        // placeholder sigue mostrándose ahí en su lugar.
        expect(find.text('Listo'), findsOneWidget);
        expect(find.text('✓ Seleccionado'), findsNothing);
        expect(find.text('Elige tus bebidas'), findsOneWidget);
      },
    );

    testWidgets(
      'bebidas obligatorias: el diálogo no ofrece el checkbox "Sin bebida" '
      'y el botón arranca deshabilitado',
      (tester) async {
        await pumpDetail(tester, productId: 'i-5');

        await openDropdown(tester, 'beverage');
        expect(
          find.byKey(const ValueKey('detail-beverage-option-none')),
          findsNothing,
        );
        await cancelDialog(tester, 'beverage');

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isFalse);
      },
    );

    testWidgets(
      'bebidas obligatorias: elegir una bebida habilita el botón y agrega '
      'la fila con la bebida elegida',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-5');

        await selectDialogOptions(tester, 'beverage', ['b-1']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedBeverages, [cocaCola]);
        expect(item.explicitlyNoBeverages, isFalse);
      },
    );
  });

  group(
    'checkbox "Sin X" controlado por allowWithout (independiente de '
    'groupRequired)',
    () {
      testWidgets(
        'grupo opcional con allowWithout=false (i-9): el diálogo NO ofrece '
        'el checkbox "Sin bebida" y el subtítulo no lo menciona',
        (tester) async {
          await pumpDetail(tester, productId: 'i-9');

          // Subtítulo sin "o \"Sin bebida\"" — el checkbox no se ofrece,
          // así que prometerlo en el texto sería incorrecto (ver
          // `_OptionGroupDropdown._subtitle`).
          expect(find.text('Elige hasta 1'), findsOneWidget);
          expect(find.textContaining('Sin bebida'), findsNothing);

          await openDropdown(tester, 'beverage');

          expect(
            find.byKey(const ValueKey('detail-beverage-option-none')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('detail-beverage-option-b-1')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'grupo opcional con allowWithout=false (i-9): el botón sigue '
        'habilitado sin elegir nada — el flag solo oculta el checkbox, no '
        'crea una elección forzada',
        (tester) async {
          final (container, _) = await pumpDetail(tester, productId: 'i-9');

          final button = tester.widget<CeltasButton>(
            find.byKey(const ValueKey('detail-add')),
          );
          expect(button.enabled, isTrue);

          await tester.tap(find.byKey(const ValueKey('detail-add')));
          await tester.pumpAndSettle();

          final item = container.read(cartProvider).items.single;
          expect(item.selectedBeverages, isEmpty);
          expect(item.explicitlyNoBeverages, isFalse);
        },
      );

      testWidgets(
        'grupo opcional con allowWithout=true por default (i-10, campo sin '
        'fijar a mano): el diálogo SÍ ofrece el checkbox "Sin salsas"',
        (tester) async {
          await pumpDetail(tester, productId: 'i-10');

          await openDropdown(tester, 'sauce');

          expect(
            find.byKey(const ValueKey('detail-sauce-option-none')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'grupo OBLIGATORIO con allowWithout=true por default (i-11): el '
        'checkbox "Sin porciones extras" se sigue ocultando igual — '
        '"Sin X" nunca es válido en un grupo obligatorio, sin importar '
        'este flag',
        (tester) async {
          await pumpDetail(tester, productId: 'i-11');

          await openDropdown(tester, 'extra');

          expect(
            find.byKey(const ValueKey('detail-extra-option-none')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'bebidas SIN groupRequired (i-4): el badge "Listo" aparece apenas '
        'hay una selección real, no solo en grupos obligatorios',
        (tester) async {
          await pumpDetail(tester, productId: 'i-4');

          expect(find.text('Listo'), findsNothing);

          await selectDialogOptions(tester, 'beverage', ['b-1']);

          expect(find.text('Listo'), findsOneWidget);
        },
      );

      testWidgets(
        'seleccionar una bebida en un grupo NO obligatorio muestra el '
        'badge "Listo" dentro del campo (mismo caso que arriba, foco en el '
        'flujo real de selección vía diálogo + ACEPTAR)',
        (tester) async {
          await pumpDetail(tester, productId: 'i-4');

          await selectDialogOptions(tester, 'beverage', ['b-2']);

          expect(find.text('Listo'), findsOneWidget);
        },
      );
    },
  );

  group('selector de porciones extras (dropdown + diálogo)', () {
    testWidgets(
      'producto sin porciones extras configuradas → no muestra la sección',
      (tester) async {
        await pumpDetail(tester); // i-1, sin extraPortions

        expect(find.text('PORCIONES EXTRAS'), findsNothing);
      },
    );

    testWidgets(
      'porciones extras opcionales → el diálogo muestra cada opción con su '
      'precio y el botón arranca HABILITADO sin elegir nada — grupo '
      'opcional, no hay elección forzada',
      (tester) async {
        await pumpDetail(tester, productId: 'i-6');

        expect(find.text('PORCIONES EXTRAS'), findsOneWidget);
        await openDropdown(tester, 'extra');
        expect(find.text('Papas extra — S/5.00'), findsOneWidget);
        await cancelDialog(tester, 'extra');

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);
      },
    );

    testWidgets(
      'porciones extras opcionales: el campo no muestra la etiqueta '
      '"Obligatorio", y arranca con el placeholder "Elige tus porciones '
      'extras" (sin "Listo" ni "✓ Seleccionado") sin nada elegido',
      (tester) async {
        await pumpDetail(tester, productId: 'i-6');

        expect(find.text('Obligatorio'), findsNothing);
        expect(find.text('Listo'), findsNothing);
        expect(find.text('✓ Seleccionado'), findsNothing);
        expect(find.text('Elige tus porciones extras'), findsOneWidget);
      },
    );

    testWidgets(
      'elegir una porción extra muestra "✓ Seleccionado" + badge "Listo" '
      'en el resumen (grupo opcional con una selección real) y suma el '
      'precio al total del botón',
      (tester) async {
        await pumpDetail(tester, productId: 'i-6');

        await selectDialogOptions(tester, 'extra', ['e-1']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);
        expect(find.text('✓ Seleccionado'), findsOneWidget);
        expect(find.text('Listo'), findsOneWidget);
        expect(find.text('Papas extra — S/5.00'), findsNothing);
        expect(find.text('Elige tus porciones extras'), findsNothing);
        // 22 (i-6) + 5 (Papas extra) = 27.
        expect(find.text('AGREGAR AL CARRITO · S/ 27.00'), findsOneWidget);
      },
    );

    testWidgets(
      'seleccionar más porciones extras que el máximo permitido bloquea '
      'el botón y muestra el aviso "Máximo X" en el SnackBar al tocar '
      '"Agregar" — esta validación no cambió con el punto 1',
      (tester) async {
        await pumpDetail(tester, productId: 'i-6'); // max = 1

        await selectDialogOptions(tester, 'extra', ['e-1', 'e-2']);

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isFalse);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Máximo 1 porción'),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 900));
      },
    );

    testWidgets(
      'porciones extras obligatorias: el campo muestra el badge '
      '"Obligatorio" y el placeholder "Elige tus porciones extras" '
      'dentro del dropdown mientras no hay nada elegido',
      (tester) async {
        await pumpDetail(tester, productId: 'i-7');

        expect(find.text('Obligatorio'), findsOneWidget);
        expect(find.text('Elige tus porciones extras'), findsOneWidget);
      },
    );

    testWidgets(
      'porciones extras obligatorias: el diálogo no ofrece el checkbox '
      '"Sin porciones extras" y el botón arranca deshabilitado',
      (tester) async {
        await pumpDetail(tester, productId: 'i-7');

        await openDropdown(tester, 'extra');
        expect(
          find.byKey(const ValueKey('detail-extra-option-none')),
          findsNothing,
        );
        await cancelDialog(tester, 'extra');

        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isFalse);
      },
    );

    testWidgets(
      'porciones extras obligatorias: elegir una habilita el botón y '
      'agrega la fila con la porción elegida',
      (tester) async {
        final (container, _) = await pumpDetail(tester, productId: 'i-7');

        await selectDialogOptions(tester, 'extra', ['e-1']);
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedExtraPortions, [papasExtra]);
        expect(item.explicitlyNoExtraPortions, isFalse);
      },
    );
  });

  group(
    'aviso de campo bloqueante al tocar Agregar (scroll + vibración + '
    'resalte rojo temporal)',
    () {
      late List<MethodCall> platformCalls;

      setUp(() {
        platformCalls = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              platformCalls.add(call);
              return null;
            });
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      /// Color de borde del campo dropdown en este momento — lee la
      /// `decoration` del `Container` con `fieldKey` (ver
      /// `_OptionGroupDropdown.build`). El campo puede envolver OTRO
      /// `Container` más adentro (el badge "Obligatorio"/"Listo" de
      /// `_RequiredBadge`), así que se toma el primero en orden de árbol
      /// (el del campo en sí, hijo directo del `GestureDetector`), no
      /// `find...single`.
      Color? fieldBorderColor(WidgetTester tester, String testKey) {
        final container = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byKey(ValueKey('detail-$testKey-dropdown')),
                matching: find.byType(Container),
              ),
            )
            .first;
        final decoration = container.decoration as BoxDecoration?;
        return (decoration?.border as Border?)?.top.color;
      }

      testWidgets(
        'tocar "Agregar" con una bebida obligatoria sin elegir vibra '
        '(HapticFeedback.mediumImpact) y resalta el campo en rojo por '
        'un momento, sin agregar nada al carrito',
        (tester) async {
          final (container, _) = await pumpDetail(tester, productId: 'i-5');

          // Borde normal antes de tocar "Agregar" (sin selección, sin
          // resalte todavía).
          expect(fieldBorderColor(tester, 'beverage'), CeltasColors.border);

          await tester.tap(find.byKey(const ValueKey('detail-add')));
          // `pumpAndSettle` deja correr el scroll real hacia el campo
          // (`Scrollable.ensureVisible`, 300ms) y la animación de entrada
          // del SnackBar hasta que no queda ningún frame pendiente — se
          // detiene ahí, ANTES del `Future.delayed(800ms)` que revierte el
          // resalte (ese temporizador no mantiene un frame agendado
          // mientras espera), así que el resalte sigue capturado.
          await tester.pumpAndSettle();

          expect(
            platformCalls.any((c) => c.method == 'HapticFeedback.vibrate'),
            isTrue,
            reason: 'debe llamar HapticFeedback.mediumImpact() al bloquear',
          );
          expect(
            fieldBorderColor(tester, 'beverage'),
            CeltasColors.redLight,
            reason: 'el campo bloqueante se resalta en rojo tras el toque',
          );
          expect(container.read(cartProvider).items, isEmpty);

          // Pasado el momento de resalte (800ms), vuelve al borde normal.
          await tester.pump(const Duration(milliseconds: 900));
          await tester.pump();
          expect(fieldBorderColor(tester, 'beverage'), CeltasColors.border);
        },
      );

      testWidgets(
        'con dos grupos obligatorios sin elegir, resalta primero el que '
        'aparece antes en pantalla (bebidas antes que porciones extras)',
        (tester) async {
          const comboDoble = PublicMenuItem(
            id: 'i-8',
            name: 'Combo Doble Obligatorio',
            price: 30,
            beverages: [
              BeverageOption(id: 'b-1', name: 'Coca-Cola 500ml', price: 3),
            ],
            beverageGroupRequired: true,
            beverageGroupMaxSelectable: 1,
            extraPortions: [
              ExtraPortionOption(id: 'e-1', name: 'Papas extra', price: 5),
            ],
            extraPortionsGroupRequired: true,
            extraPortionsGroupMaxSelectable: 1,
          );
          const categoriaDoble = PublicMenuCategory(
            id: 'c-2',
            name: 'Combos',
            items: [comboDoble],
          );
          final containerDoble = ProviderContainer(
            overrides: [
              publicMenuProvider.overrideWith(
                (ref) async => [categoriaDoble],
              ),
            ],
          );
          addTearDown(containerDoble.dispose);
          final goRouter = GoRouter(
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
          tester.view.physicalSize = const Size(1170, 2532);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: containerDoble,
              child: MaterialApp.router(
                theme: AppTheme.dark,
                routerConfig: goRouter,
              ),
            ),
          );
          await tester.pumpAndSettle();
          unawaited(goRouter.push('/product/i-8'));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('detail-add')));
          // Mismo motivo que el test anterior: deja correr el scroll real
          // y la animación del SnackBar antes de comprobar el resalte.
          await tester.pumpAndSettle();

          expect(fieldBorderColor(tester, 'beverage'), CeltasColors.redLight);
          expect(fieldBorderColor(tester, 'extra'), CeltasColors.border);

          // Deja correr el `Future.delayed(800ms)` que limpia el resalte
          // antes de que termine el test — mismo motivo que arriba.
          await tester.pump(const Duration(milliseconds: 900));
        },
      );
    },
  );

  group('nota para el pedido (comentario libre por línea)', () {
    testWidgets(
      'el campo de nota está siempre visible, incluso en productos sin '
      'catálogo de salsas',
      (tester) async {
        await pumpDetail(tester); // i-1, sin sauces

        expect(find.text('NOTA PARA TU PEDIDO'), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-comment')), findsOneWidget);
      },
    );

    testWidgets(
      'escribir una nota y agregar guarda el comentario trimeado en la '
      'fila',
      (tester) async {
        final (container, _) = await pumpDetail(tester);

        await tester.enterText(
          find.byKey(const ValueKey('detail-comment')),
          '  Sin cebolla  ',
        );
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        expect(container.read(cartProvider).items.single.comment, 'Sin cebolla');
      },
    );

    testWidgets(
      'nota vacía o solo espacios se guarda como null (sin comentario), '
      'mismo criterio que el backend',
      (tester) async {
        final (container, _) = await pumpDetail(tester);

        await tester.enterText(
          find.byKey(const ValueKey('detail-comment')),
          '   ',
        );
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        expect(container.read(cartProvider).items.single.comment, isNull);
      },
    );

    testWidgets(
      'sin tocar el campo de nota, la fila queda sin comentario',
      (tester) async {
        final (container, _) = await pumpDetail(tester);

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        expect(container.read(cartProvider).items.single.comment, isNull);
      },
    );

    testWidgets(
      'mismo producto con distinta nota crea una fila aparte en el '
      'carrito (no fusiona), mismo criterio que las salsas',
      (tester) async {
        final (container, goRouter) = await pumpDetail(tester);

        await tester.enterText(
          find.byKey(const ValueKey('detail-comment')),
          'Sin cebolla',
        );
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        unawaited(goRouter.push('/product/i-1'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('detail-comment')),
          'Bien cocida',
        );
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
        // La salsa de la fila editada (Mayonesa) aparece precargada en el
        // resumen del dropdown como "✓ Seleccionado" (grupo opcional, sin
        // badge propio — ver `_OptionGroupDropdown._summaryText`), sin
        // necesidad de abrir el diálogo.
        expect(find.text('✓ Seleccionado'), findsOneWidget);
      },
    );

    testWidgets(
      'fila editada con explicitlyNoSauces=true precarga "Sin salsas" en '
      'el resumen del dropdown (no solo dejar todo vacío)',
      (tester) async {
        await pumpEdit(
          tester,
          seed: (notifier) => notifier.addItem(
            category.items.firstWhere((i) => i.id == 'i-3'),
            quantity: 2,
            explicitlyNoSauces: true,
          ),
          pickEditingLineKey: (state) => state.items.single.lineKey,
          productId: 'i-3',
        );

        // Botón habilitado de entrada (la precarga ya cuenta como elección
        // real) y el resumen del dropdown ya muestra "Sin salsas" sin
        // necesidad de abrir el diálogo.
        final button = tester.widget<CeltasButton>(
          find.byKey(const ValueKey('detail-add')),
        );
        expect(button.enabled, isTrue);
        expect(button.onPressed, isNotNull);
        expect(find.text('Sin salsas'), findsOneWidget);
      },
    );

    testWidgets(
      'GUARDAR CAMBIOS sin tocar el dropdown preserva explicitlyNoSauces='
      'true de la fila precargada (no se pierde al no interactuar)',
      (tester) async {
        final (container, _) = await pumpEdit(
          tester,
          seed: (notifier) => notifier.addItem(
            category.items.firstWhere((i) => i.id == 'i-3'),
            quantity: 2,
            explicitlyNoSauces: true,
          ),
          pickEditingLineKey: (state) => state.items.single.lineKey,
          productId: 'i-3',
        );

        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final item = container.read(cartProvider).items.single;
        expect(item.selectedSauces, isEmpty);
        expect(item.explicitlyNoSauces, isTrue);
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

        // La fila editada trae "Mostaza" precargada: dentro del MISMO
        // diálogo se deselecciona y se elige "Mayonesa" en su lugar — esa
        // combinación ya la tiene la otra fila del carrito.
        await openDropdown(tester, 'sauce');
        await tapDialogOption(tester, 'sauce', 's-2');
        await tapDialogOption(tester, 'sauce', 's-1');
        await confirmDialog(tester, 'sauce');

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

    testWidgets(
      'precarga la nota de la fila que se está editando en el campo de '
      'comentario',
      (tester) async {
        await pumpEdit(
          tester,
          seed: (notifier) => notifier.addItem(
            category.items.firstWhere((i) => i.id == 'i-1'),
            comment: 'Sin cebolla',
          ),
          pickEditingLineKey: (state) => state.items.single.lineKey,
          productId: 'i-1',
        );

        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('detail-comment')),
        );
        expect(field.controller?.text, 'Sin cebolla');
      },
    );

    testWidgets(
      'GUARDAR CAMBIOS con la nota editada actualiza el comentario de la '
      'fila',
      (tester) async {
        final (container, _) = await pumpEdit(
          tester,
          seed: (notifier) => notifier.addItem(
            category.items.firstWhere((i) => i.id == 'i-1'),
            comment: 'Sin cebolla',
          ),
          pickEditingLineKey: (state) => state.items.single.lineKey,
          productId: 'i-1',
        );

        await tester.enterText(
          find.byKey(const ValueKey('detail-comment')),
          'Bien cocida',
        );
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await tester.pumpAndSettle();

        final state = container.read(cartProvider);
        expect(state.items, hasLength(1));
        expect(state.items.single.comment, 'Bien cocida');
      },
    );
  });
}
