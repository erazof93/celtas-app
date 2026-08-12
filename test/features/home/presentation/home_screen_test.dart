import 'dart:async';

import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/presentation/home_screen.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Fake del canal de plataforma de `url_launcher` — sin esto, `launchUrl`
/// lanza `MissingPluginException` en widget tests. Mismo patrón que
/// `checkout_screen_test.dart` (`_openWhatsapp`): solo implementa
/// `launchUrl`, porque `_openExternalUrl` de los banners tampoco usa
/// `canLaunchUrl` como gate.
class FakeUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  bool launchResult = true;
  Object? launchThrows;
  String? lastLaunchedUrl;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    final error = launchThrows;
    if (error != null) throw error;
    return launchResult;
  }
}

void main() {
  final banner = Banner(
    id: 'b-1',
    title: 'aprovecha la 2x1',
    actionType: BannerActionType.none,
    active: true,
    order: 0,
    createdAt: DateTime.utc(2026, 8, 9),
    updatedAt: DateTime.utc(2026, 8, 9),
  );

  const category = PublicMenuCategory(
    id: 'c-1',
    name: 'Hamburguesa',
    description: 'Hamburguesa artesanales',
    items: [
      PublicMenuItem(
        id: 'i-1',
        name: 'Celtas Burgues Clasica',
        description: 'doble carne, queso y jamon',
        price: 15.5,
      ),
      PublicMenuItem(id: 'i-2', name: 'Sin foto', price: 9.9),
    ],
  );

  late FakeUrlLauncherPlatform fakeUrlLauncher;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    fakeUrlLauncher = FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    List<Banner> banners = const [],
    List<PublicMenuCategory> menu = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        activeBannersProvider.overrideWith((ref) async => banners),
        publicMenuProvider.overrideWith((ref) async => menu),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    // Resuelve los FutureProviders (banners + menú) antes de inspeccionar.
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('header con pin de ubicación y campana', (tester) async {
    await pumpHome(tester);

    expect(find.text('Entregar en'), findsOneWidget);
    expect(find.text('Casa · Av. Corrientes 1234'), findsOneWidget);
  });

  testWidgets('sin banners activos → el carrusel se oculta (no es error)', (
    tester,
  ) async {
    await pumpHome(tester, menu: [category]);

    // El menú se muestra igual aunque no haya banners.
    expect(find.text('Hamburguesa'), findsWidgets);
    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
  });

  testWidgets('con banners → carrusel con título y puntos indicadores', (
    tester,
  ) async {
    await pumpHome(tester, banners: [banner], menu: [category]);

    expect(find.text('APROVECHA LA 2X1'), findsOneWidget);
    // Punto indicador activo (16px) + menú renderizado.
    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
  });

  testWidgets('tarjeta de producto: nombre, descripción y precio en soles', (
    tester,
  ) async {
    await pumpHome(tester, menu: [category]);

    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
    expect(find.text('doble carne, queso y jamon'), findsOneWidget);
    expect(find.text('S/ 15.50'), findsOneWidget);
    expect(find.text('S/ 9.90'), findsOneWidget);
  });

  testWidgets('botón "+" → agrega al carrito local y muestra SnackBar', (
    tester,
  ) async {
    final container = await pumpHome(tester, menu: [category]);

    // Hay un botón "+" por producto.
    expect(find.byKey(const ValueKey('add-i-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-i-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-i-1')));
    await tester.pump();

    expect(find.text('Agregado: Celtas Burgues Clasica'), findsOneWidget);

    // El carrito local quedó con el ítem (módulo 4: el "+" ya no es solo aviso).
    final state = container.read(cartProvider);
    expect(state.items, hasLength(1));
    expect(state.items.single.menuItemId, 'i-1');
    expect(state.items.single.quantity, 1);
    expect(state.totalCount, 1);
  });

  testWidgets('el badge del carrito refleja la cantidad de unidades', (
    tester,
  ) async {
    final container = await pumpHome(tester, menu: [category]);

    // Sin items: ícono sin badge.
    expect(find.byKey(const ValueKey('home-cart-badge')), findsNothing);

    // Dos toques al "+" del mismo producto → badge con 2.
    await tester.tap(find.byKey(const ValueKey('add-i-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-i-1')));
    await tester.pump();

    expect(container.read(cartProvider).totalCount, 2);
    expect(find.byKey(const ValueKey('home-cart-badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Otro producto → badge con 3.
    await tester.tap(find.byKey(const ValueKey('add-i-2')));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('chips de categorías: filtrar por categoría', (tester) async {
    const chicken = PublicMenuCategory(
      id: 'c-2',
      name: 'Chicken',
      items: [PublicMenuItem(id: 'i-3', name: 'Odin Wings', price: 7.2)],
    );
    await pumpHome(tester, menu: [category, chicken]);

    // Ambas categorías visibles por defecto.
    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
    expect(find.text('Odin Wings'), findsOneWidget);

    // Filtrar por "Chicken".
    await tester.tap(find.text('Chicken'));
    await tester.pumpAndSettle();

    expect(find.text('Odin Wings'), findsOneWidget);
    expect(find.text('Celtas Burgues Clasica'), findsNothing);

    // Volver a "Todas".
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();

    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
    expect(find.text('Odin Wings'), findsOneWidget);
  });

  testWidgets('menú vacío → mensaje de estado vacío', (tester) async {
    await pumpHome(tester);

    expect(find.text('El menú está vacío por ahora'), findsOneWidget);
  });

  testWidgets('error del menú → mensaje de error con reintento', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBannersProvider.overrideWith((ref) async => const []),
          publicMenuProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el menú'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
  });

  testWidgets('error de banners → mensaje con reintento (no se traga)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBannersProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
          publicMenuProvider.overrideWith((ref) async => [category]),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar los banners'), findsOneWidget);
    expect(find.text('REINTENTAR'), findsOneWidget);
    // El menú sigue visible aunque los banners fallen.
    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
  });

  testWidgets('carga del menú → spinner + SlowBackendNotice', (tester) async {
    final completer = Completer<List<PublicMenuCategory>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBannersProvider.overrideWith((ref) async => const []),
          publicMenuProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byType(SlowBackendNotice), findsOneWidget);

    completer.complete([category]);
    await tester.pumpAndSettle();
    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
  });

  testWidgets('pull-to-refresh → vuelve a pedir banners y menú', (
    tester,
  ) async {
    var bannerCalls = 0;
    var menuCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBannersProvider.overrideWith((ref) async {
            bannerCalls++;
            return [banner];
          }),
          publicMenuProvider.overrideWith((ref) async {
            menuCalls++;
            return [category];
          }),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(bannerCalls, 1);
    expect(menuCalls, 1);

    // Fling hacia abajo para disparar el RefreshIndicator.
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(bannerCalls, 2);
    expect(menuCalls, 2);
    expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
  });

  testWidgets('pull-to-refresh con error → no lanza excepción async', (
    tester,
  ) async {
    var fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBannersProvider.overrideWith((ref) async {
            if (fail) throw Exception('boom');
            return [banner];
          }),
          publicMenuProvider.overrideWith((ref) async => [category]),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // El refresh falla pero no debe propagar una excepción sin manejar.
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar los banners'), findsOneWidget);

    // Reintentar desde el estado de error recupera los banners.
    fail = false;
    await tester.tap(find.text('REINTENTAR'));
    await tester.pumpAndSettle();
    expect(find.text('APROVECHA LA 2X1'), findsOneWidget);
  });

  testWidgets('carrusel con 2 banners → swipe cambia el punto activo', (
    tester,
  ) async {
    final banner2 = Banner(
      id: 'b-2',
      title: 'combo familiar',
      actionType: BannerActionType.none,
      active: true,
      order: 1,
      createdAt: DateTime.utc(2026, 8, 9),
      updatedAt: DateTime.utc(2026, 8, 9),
    );
    await pumpHome(tester, banners: [banner, banner2], menu: [category]);

    expect(find.text('APROVECHA LA 2X1'), findsOneWidget);

    // Swipe a la izquierda → segundo banner visible.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('COMBO FAMILIAR'), findsOneWidget);
  });

  testWidgets('chip "Todas" seleccionado por defecto', (tester) async {
    await pumpHome(tester, menu: [category]);

    final todasChip = tester.widget<Container>(
      find
          .ancestor(of: find.text('Todas'), matching: find.byType(Container))
          .first,
    );
    final decoration = todasChip.decoration as BoxDecoration;
    expect(decoration.color, CeltasColors.orange);
  });

  testWidgets('precio entero → se muestra con dos decimales', (tester) async {
    const wholePrice = PublicMenuCategory(
      id: 'c-3',
      name: 'Bebidas',
      items: [PublicMenuItem(id: 'i-4', name: 'Inca Kola 1L', price: 8)],
    );
    await pumpHome(tester, menu: [wholePrice]);

    expect(find.text('S/ 8.00'), findsOneWidget);
  });

  group('tap sobre banners', () {
    testWidgets(
      'título largo en banner tocable → no se solapa con el chevron de '
      'afordancia (regresión: hallazgo real de @tester con tester.getRect, '
      'título sin maxLines/overflow invadía la zona del ícono)',
      (tester) async {
        final longTitleBanner = Banner(
          id: 'b-long',
          title: 'combo mega familiar xxl con papas gaseosa y postre incluido',
          actionType: BannerActionType.externalUrl,
          actionValue: 'https://instagram.com/celtas',
          active: true,
          order: 0,
          createdAt: DateTime.utc(2026, 8, 9),
          updatedAt: DateTime.utc(2026, 8, 9),
        );
        await pumpHome(tester, banners: [longTitleBanner], menu: [category]);

        final textRect = tester.getRect(
          find.text(longTitleBanner.title.toUpperCase()),
        );
        final chevronRect = tester.getRect(
          find.byIcon(Icons.chevron_right_rounded),
        );

        expect(
          textRect.right,
          lessThanOrEqualTo(chevronRect.left),
          reason: 'El título del banner invade la zona del chevron',
        );
      },
    );

    testWidgets(
      "actionType 'none' → sin afordancia visual y el tap no hace nada",
      (tester) async {
        await pumpHome(tester, banners: [banner], menu: [category]);

        expect(find.byKey(const ValueKey('banner-b-1')), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

        await tester.tap(find.byKey(const ValueKey('banner-b-1')));
        await tester.pumpAndSettle();

        // Sigue en Home, sin ningún cambio visible.
        expect(find.text('Celtas Burgues Clasica'), findsOneWidget);
      },
    );

    testWidgets("actionType 'category' → selecciona el chip de esa categoría "
        '(actionValue = id real de la categoría, no un slug — contrato '
        'confirmado contra BannerForm.tsx del panel admin)', (tester) async {
      const chicken = PublicMenuCategory(
        id: 'c-2',
        name: 'Chicken',
        items: [PublicMenuItem(id: 'i-3', name: 'Odin Wings', price: 7.2)],
      );
      final categoryBanner = Banner(
        id: 'b-cat',
        title: 'solo pollo',
        actionType: BannerActionType.category,
        actionValue: 'c-2',
        active: true,
        order: 0,
        createdAt: DateTime.utc(2026, 8, 9),
        updatedAt: DateTime.utc(2026, 8, 9),
      );
      await pumpHome(
        tester,
        banners: [categoryBanner],
        menu: [category, chicken],
      );

      // Afordancia visible: actionType != none.
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      // Ambas categorías visibles antes de tocar el banner.
      expect(find.text('Odin Wings'), findsOneWidget);
      expect(find.text('Celtas Burgues Clasica'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('banner-b-cat')));
      await tester.pumpAndSettle();

      // Mismo efecto que tocar el chip "Chicken" a mano.
      expect(find.text('Odin Wings'), findsOneWidget);
      expect(find.text('Celtas Burgues Clasica'), findsNothing);
      final chickenChip = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Chicken'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = chickenChip.decoration as BoxDecoration;
      expect(decoration.color, CeltasColors.orange);
    });

    testWidgets(
      "actionType 'category' con id que ya no tiene productos disponibles "
      '(o ya no existe) → reutiliza el estado vacío del menú '
      '(GET /menu excluye del todo las categorías sin productos)',
      (tester) async {
        final categoryBanner = Banner(
          id: 'b-cat',
          title: 'promo vieja',
          actionType: BannerActionType.category,
          actionValue: 'c-borrada',
          active: true,
          order: 0,
          createdAt: DateTime.utc(2026, 8, 9),
          updatedAt: DateTime.utc(2026, 8, 9),
        );
        await pumpHome(tester, banners: [categoryBanner], menu: [category]);

        await tester.tap(find.byKey(const ValueKey('banner-b-cat')));
        await tester.pumpAndSettle();

        expect(find.text('El menú está vacío por ahora'), findsOneWidget);
        expect(find.text('Celtas Burgues Clasica'), findsNothing);
      },
    );

    testWidgets(
      "actionType 'external_url' → abre el enlace con url_launcher (no "
      'usa canLaunchUrl como gate, mismo criterio del checkout)',
      (tester) async {
        final urlBanner = Banner(
          id: 'b-url',
          title: 'síguenos',
          actionType: BannerActionType.externalUrl,
          actionValue: 'https://instagram.com/celtas',
          active: true,
          order: 0,
          createdAt: DateTime.utc(2026, 8, 9),
          updatedAt: DateTime.utc(2026, 8, 9),
        );
        await pumpHome(tester, banners: [urlBanner], menu: [category]);

        await tester.tap(find.byKey(const ValueKey('banner-b-url')));
        await tester.pumpAndSettle();

        expect(fakeUrlLauncher.lastLaunchedUrl, 'https://instagram.com/celtas');
        expect(
          find.text('No se pudo abrir el enlace del banner.'),
          findsNothing,
        );
      },
    );

    testWidgets("actionType 'external_url' con launchUrl devolviendo false → "
        'SnackBar de error, sin crash', (tester) async {
      fakeUrlLauncher.launchResult = false;
      final urlBanner = Banner(
        id: 'b-url',
        title: 'síguenos',
        actionType: BannerActionType.externalUrl,
        actionValue: 'https://instagram.com/celtas',
        active: true,
        order: 0,
        createdAt: DateTime.utc(2026, 8, 9),
        updatedAt: DateTime.utc(2026, 8, 9),
      );
      await pumpHome(tester, banners: [urlBanner], menu: [category]);

      await tester.tap(find.byKey(const ValueKey('banner-b-url')));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo abrir el enlace del banner.'),
        findsOneWidget,
      );
    });

    testWidgets(
      "actionType 'external_url' con launchUrl lanzando PlatformException "
      '→ mismo mensaje de error, sin crash',
      (tester) async {
        fakeUrlLauncher.launchThrows = PlatformException(
          code: 'ACTIVITY_NOT_FOUND',
        );
        final urlBanner = Banner(
          id: 'b-url',
          title: 'síguenos',
          actionType: BannerActionType.externalUrl,
          actionValue: 'https://instagram.com/celtas',
          active: true,
          order: 0,
          createdAt: DateTime.utc(2026, 8, 9),
          updatedAt: DateTime.utc(2026, 8, 9),
        );
        await pumpHome(tester, banners: [urlBanner], menu: [category]);

        await tester.tap(find.byKey(const ValueKey('banner-b-url')));
        await tester.pumpAndSettle();

        expect(
          find.text('No se pudo abrir el enlace del banner.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      "actionType 'external_url' con actionValue no parseable como URI → "
      'tratado como fallo, sin crash',
      (tester) async {
        final urlBanner = Banner(
          id: 'b-url',
          title: 'síguenos',
          actionType: BannerActionType.externalUrl,
          actionValue: ':::: no es una url ::::',
          active: true,
          order: 0,
          createdAt: DateTime.utc(2026, 8, 9),
          updatedAt: DateTime.utc(2026, 8, 9),
        );
        await pumpHome(tester, banners: [urlBanner], menu: [category]);

        await tester.tap(find.byKey(const ValueKey('banner-b-url')));
        await tester.pumpAndSettle();

        expect(
          find.text('No se pudo abrir el enlace del banner.'),
          findsOneWidget,
        );
        expect(fakeUrlLauncher.lastLaunchedUrl, isNull);
      },
    );
  });
}
