import 'dart:async';

import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/data/models/sauce_option.dart';
import 'package:celtas_mobile/features/home/presentation/home_screen.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    List<NotificationHistoryItem>? notifications,
    List<Address> addresses = const [],
    Override? businessHoursOverride,
  }) async {
    final container = ProviderContainer(
      overrides: [
        activeBannersProvider.overrideWith((ref) async => banners),
        publicMenuProvider.overrideWith((ref) async => menu),
        addressListProvider.overrideWith(
          () => _FakeAddressListNotifier(addresses),
        ),
        // Default: local abierto, sin `nextChangeAt` — la mayoría de los
        // tests de este archivo no se ocupan del cartel de "local cerrado",
        // así que no debe aparecer sin pedirlo, y no debe hacer una request
        // de red real.
        businessHoursOverride ??
            businessHoursProvider.overrideWith(
              (ref) async => const BusinessHours(
                open: true,
                message: null,
                nextChangeAt: null,
              ),
            ),
        if (notifications != null)
          notificationHistoryProvider.overrideWith(
            () => _FakeNotificationHistoryNotifier(notifications),
          ),
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
  });

  testWidgets(
    'header sin dirección guardada → invita a ingresar una',
    (tester) async {
      await pumpHome(tester);

      expect(find.text('Ingresa tu dirección'), findsOneWidget);
    },
  );

  testWidgets(
    'header con direcciones → muestra la principal (isDefault)',
    (tester) async {
      await pumpHome(
        tester,
        addresses: const [
          Address(
            id: 'a-1',
            alias: 'Trabajo',
            fullAddress: 'Av. Callao 850',
            district: 'Surco',
          ),
          Address(
            id: 'a-2',
            alias: 'Casa',
            fullAddress: 'Av. Los Álamos 123',
            district: 'San Juan de Miraflores',
            isDefault: true,
          ),
        ],
      );

      expect(find.text('Casa · Av. Los Álamos 123'), findsOneWidget);
      expect(find.text('Ingresa tu dirección'), findsNothing);
    },
  );

  testWidgets(
    'header con direcciones pero ninguna principal → usa la primera',
    (tester) async {
      await pumpHome(
        tester,
        addresses: const [
          Address(
            id: 'a-1',
            alias: 'Trabajo',
            fullAddress: 'Av. Callao 850',
            district: 'Surco',
          ),
          Address(
            id: 'a-2',
            alias: 'Casa',
            fullAddress: 'Av. Los Álamos 123',
            district: 'San Juan de Miraflores',
          ),
        ],
      );

      expect(find.text('Trabajo · Av. Callao 850'), findsOneWidget);
    },
  );

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

  testWidgets(
    'botón "+" en un producto CON salsas → navega al detalle en vez de '
    'agregar directo (hallazgo real probando en dispositivo: el atajo se '
    'sentía roto porque nunca dejaba elegir las salsas)',
    (tester) async {
      const withSauces = PublicMenuCategory(
        id: 'c-5',
        name: 'Con salsas',
        items: [
          PublicMenuItem(
            id: 'i-5',
            name: 'Con Salsas Burger',
            price: 10,
            sauces: [SauceOption(id: 's-1', name: 'Mayonesa')],
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          activeBannersProvider.overrideWith((ref) async => const []),
          publicMenuProvider.overrideWith((ref) async => [withSauces]),
          businessHoursProvider.overrideWith(
            (ref) async => const BusinessHours(
              open: true,
              message: null,
              nextChangeAt: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: '/product/:id',
            builder: (_, state) =>
                Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-i-5')));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL i-5'), findsOneWidget);
      // No agregó directo: el carrito sigue vacío, la elección de salsas
      // queda en manos del detalle.
      expect(container.read(cartProvider).items, isEmpty);
    },
  );

  testWidgets(
    'el SnackBar de "Agregado" desde el "+" rápido tiene margen para no '
    'quedar tapado por la barra flotante del carrito',
    (tester) async {
      await pumpHome(tester, menu: [category]);

      await tester.tap(find.byKey(const ValueKey('add-i-1')));
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 88));
    },
  );

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

  NotificationHistoryItem notificationAt(int i, {bool read = false}) =>
      NotificationHistoryItem(
        title: 'Notificación $i',
        body: 'Cuerpo $i',
        receivedAt: DateTime.utc(2026, 8, 12).add(Duration(minutes: i)),
        data: {'orderId': 'order-$i'},
        read: read,
      );

  testWidgets('el badge de la campana refleja la cantidad de notificaciones no '
      'leídas (mismo patrón que el badge del carrito)', (tester) async {
    await pumpHome(
      tester,
      menu: [category],
      notifications: [
        notificationAt(0),
        notificationAt(1),
        notificationAt(2, read: true),
      ],
    );

    expect(
      find.byKey(const ValueKey('home-notifications-badge')),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
    'sin notificaciones no leídas (o sin historial) → campana sin badge',
    (tester) async {
      await pumpHome(
        tester,
        menu: [category],
        notifications: [notificationAt(0, read: true)],
      );

      expect(
        find.byKey(const ValueKey('home-notifications-badge')),
        findsNothing,
      );
    },
  );

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

  group('cartel de "local cerrado" (GET /settings/business-hours)', () {
    testWidgets(
      'open: false → cartel visible con el mensaje real del backend, y el '
      'resto del Home sigue funcionando (SÍ se puede seguir agregando '
      'productos con el cartel visible)',
      (tester) async {
        final container = await pumpHome(
          tester,
          menu: [category],
          businessHoursOverride: businessHoursProvider.overrideWith(
            (ref) async => const BusinessHours(
              open: false,
              message:
                  'El local está cerrado en este momento. Hoy atendemos de '
                  '11:00 a 23:00',
              nextChangeAt: null,
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('home-closed-notice')),
          findsOneWidget,
        );
        expect(
          find.text(
            'El local está cerrado en este momento. Hoy atendemos de 11:00 '
            'a 23:00',
          ),
          findsOneWidget,
        );

        // Regla de negocio central de este cambio: el cartel es puramente
        // informativo — el cliente sigue pudiendo agregar productos al
        // carrito con el local cerrado. El único bloqueo real sigue siendo
        // el 409 del checkout.
        await tester.tap(find.byKey(const ValueKey('add-i-1')));
        await tester.pump();

        expect(container.read(cartProvider).items, isNotEmpty);
        expect(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('Agregado:'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('open: true → sin cartel', (tester) async {
      await pumpHome(tester, menu: [category]);

      expect(
        find.byKey(const ValueKey('home-closed-notice')),
        findsNothing,
      );
    });

    testWidgets(
      'nextChangeAt: null (cierre manual, o el horario nunca abre) → NO '
      'programa ningún timer',
      (tester) async {
        var calls = 0;
        await pumpHome(
          tester,
          businessHoursOverride: businessHoursProvider.overrideWith((
            ref,
          ) async {
            calls++;
            return const BusinessHours(
              open: false,
              message: 'El local está cerrado temporalmente: mantenimiento',
              nextChangeAt: null,
            );
          }),
        );

        expect(calls, 1);

        // Sin timer programado, ningún avance de tiempo (por más grande que
        // sea) debería disparar un refetch nuevo.
        await tester.pump(const Duration(hours: 2));
        await tester.pumpAndSettle();

        expect(calls, 1);
      },
    );

    testWidgets(
      'el timer se dispara en el instante de nextChangeAt (con el margen '
      'de deriva de reloj), no antes',
      (tester) async {
        var calls = 0;
        final firstChange = DateTime.now().add(const Duration(minutes: 10));
        await pumpHome(
          tester,
          businessHoursOverride: businessHoursProvider.overrideWith((
            ref,
          ) async {
            calls++;
            return BusinessHours(
              open: true,
              message: null,
              nextChangeAt: firstChange,
            );
          }),
        );

        expect(calls, 1);

        // Justo antes de nextChangeAt (con margen de sobra): no debería
        // haber vuelto a consultar todavía.
        await tester.pump(const Duration(minutes: 9, seconds: 58));
        await tester.pump();
        expect(calls, 1);

        // Cruza nextChangeAt + el margen de 5s de deriva de reloj: ahora sí
        // debe haber disparado el refetch.
        await tester.pump(const Duration(seconds: 9));
        await tester.pumpAndSettle();
        expect(calls, 2);
      },
    );

    testWidgets(
      'al dispararse, reconsulta y se reprograma con el nextChangeAt nuevo '
      'devuelto por esa respuesta (no se queda pegado al primer valor)',
      (tester) async {
        var calls = 0;
        await pumpHome(
          tester,
          businessHoursOverride: businessHoursProvider.overrideWith((
            ref,
          ) async {
            calls++;
            // `DateTime.now()` fresco en cada llamada, no capturado una
            // sola vez afuera: `tester.pump(duration)` avanza el reloj
            // FALSO de los `Timer`, pero NO el `DateTime.now()` real —
            // anclar el 2do valor a un `now` capturado al principio del
            // test calcularía mal el delay real que ve el widget. Fetch
            // inicial: cambia en 5 min. Fetch tras dispararse ese timer:
            // cambia en otros 3 min desde ESE momento.
            final next = calls == 1
                ? DateTime.now().add(const Duration(minutes: 5))
                : DateTime.now().add(const Duration(minutes: 3));
            return BusinessHours(open: true, message: null, nextChangeAt: next);
          }),
        );

        expect(calls, 1);

        // Dispara el primer timer (5 min + margen).
        await tester.pump(const Duration(minutes: 5, seconds: 7));
        await tester.pumpAndSettle();
        expect(calls, 2);

        // Si NO se hubiera reprogramado con el nextChangeAt nuevo (3 min
        // desde ESE momento, no desde el inicio), no pasaría nada acá.
        await tester.pump(const Duration(minutes: 2, seconds: 50));
        await tester.pumpAndSettle();
        expect(calls, 2);

        // El timer reprogramado sí dispara en su nuevo momento (3 min +
        // margen de 5s desde que se reprogramó).
        await tester.pump(const Duration(seconds: 20));
        await tester.pumpAndSettle();
        expect(calls, 3);
      },
    );

    testWidgets(
      'AppLifecycleState.resumed cancela cualquier timer pendiente y '
      'reconsulta de inmediato (no deja dos timers corriendo a la vez)',
      (tester) async {
        var calls = 0;
        final now = DateTime.now();
        await pumpHome(
          tester,
          businessHoursOverride: businessHoursProvider.overrideWith((
            ref,
          ) async {
            calls++;
            // Fetch inicial: próximo cambio en 5 min. Fetch tras "resumed":
            // en 20 min — valores bien separados para poder distinguir si
            // el timer del fetch inicial quedó corriendo por error.
            final next = calls == 1
                ? now.add(const Duration(minutes: 5))
                : now.add(const Duration(minutes: 20));
            return BusinessHours(open: true, message: null, nextChangeAt: next);
          }),
        );

        expect(calls, 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        // Reconsultó de inmediato al volver, sin esperar los 5 min.
        expect(calls, 2);

        // Si el timer del fetch inicial (5 min) NO se hubiera cancelado,
        // dispararía acá un 3er refetch fantasma.
        await tester.pump(const Duration(minutes: 5, seconds: 7));
        await tester.pumpAndSettle();
        expect(calls, 2);

        // El timer reprogramado tras el resumed (20 min) sí dispara en su
        // momento.
        await tester.pump(const Duration(minutes: 15));
        await tester.pumpAndSettle();
        expect(calls, 3);
      },
    );

    testWidgets(
      'resumed cancela el timer viejo de inmediato (síncrono), antes de que '
      'complete el refetch que el propio resumed dispara — evita una '
      'carrera donde el timer viejo dispara un refetch fantasma mientras el '
      'nuevo sigue en vuelo',
      (tester) async {
        var calls = 0;
        await pumpHome(
          tester,
          businessHoursOverride: businessHoursProvider.overrideWith((
            ref,
          ) async {
            calls++;
            if (calls == 1) {
              // Timer viejo: dispara a los 2s + margen(5s) = 7s.
              return BusinessHours(
                open: true,
                message: null,
                nextChangeAt: DateTime.now().add(const Duration(seconds: 2)),
              );
            }
            // Cualquier fetch DESPUÉS del primero (el que dispara "resumed",
            // o un refetch fantasma del timer viejo si no se hubiera
            // cancelado) tarda 10s en resolver — más que los 7s del timer
            // viejo, a propósito: si el timer viejo sigue vivo, tiene
            // tiempo de sobra para disparar (y sumar una llamada de más)
            // ANTES de que este primer refetch termine.
            await Future<void>.delayed(const Duration(seconds: 10));
            return const BusinessHours(
              open: false,
              message: 'Cerrado',
              nextChangeAt: null,
            );
          }),
        );

        expect(calls, 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        // Flush del microtask que arranca el refetch (calls=2, entra en su
        // delay de 10s) sin todavía avanzar tiempo de reloj.
        await tester.pump();
        expect(calls, 2);

        // Cruza los 7s del timer viejo MIENTRAS el fetch de "resumed"
        // (10s) todavía está en vuelo.
        await tester.pump(const Duration(seconds: 7));
        expect(
          calls,
          2,
          reason:
              'si el timer viejo no se hubiera cancelado, dispararía acá '
              'un refetch fantasma (calls pasaría a 3)',
        );

        // Deja completar el resto del delay de 10s.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(calls, 2);
      },
    );

    testWidgets(
      'el timer se cancela al salir del Home (dispose) — no sigue '
      'consultando en segundo plano',
      (tester) async {
        var calls = 0;
        final firstChange = DateTime.now().add(const Duration(minutes: 10));
        final container = await pumpHome(
          tester,
          businessHoursOverride: businessHoursProvider.overrideWith((
            ref,
          ) async {
            calls++;
            return BusinessHours(
              open: true,
              message: null,
              nextChangeAt: firstChange,
            );
          }),
        );

        expect(calls, 1);

        // Desmonta el Home reemplazando el árbol de widgets → dispara
        // `dispose()`, que debe cancelar el timer.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pump(const Duration(minutes: 15));
        await tester.pumpAndSettle();

        // Sin llamadas nuevas: si el timer siguiera corriendo, ya habría
        // disparado un 2do refetch en el minuto 10.
        expect(calls, 1);
      },
    );
  });
}

/// Fake sin persistencia real, mismo criterio que
/// `notifications_screen_test.dart`: la lista se fija en el `build()`, sin
/// tocar `shared_preferences`.
class _FakeNotificationHistoryNotifier extends NotificationHistoryNotifier {
  _FakeNotificationHistoryNotifier(this._items);

  final List<NotificationHistoryItem> _items;

  @override
  Future<List<NotificationHistoryItem>> build() async => _items;
}

/// Direcciones fijas para el header del Home, sin tocar la red. Mismo patrón
/// que `_FakeNotificationHistoryNotifier`: la lista se fija en el `build()`.
class _FakeAddressListNotifier extends AddressListNotifier {
  _FakeAddressListNotifier(this._addresses);

  final List<Address> _addresses;

  @override
  Future<List<Address>> build() async => _addresses;
}
