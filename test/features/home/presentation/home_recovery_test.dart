import 'dart:async';

import 'package:celtas_mobile/app.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/router/app_router.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/addresses/application/address_providers.dart';
import 'package:celtas_mobile/features/addresses/application/address_selection_provider.dart';
import 'package:celtas_mobile/features/addresses/data/models/address.dart';
import 'package:celtas_mobile/features/home/application/home_providers.dart';
import 'package:celtas_mobile/features/home/data/home_repository.dart';
import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:celtas_mobile/features/home/presentation/home_screen.dart';
import 'package:celtas_mobile/features/home/presentation/widgets/content_recovery_notice.dart';
import 'package:celtas_mobile/features/menu/presentation/product_detail_screen.dart';
import 'package:celtas_mobile/features/notifications/application/notification_providers.dart';
import 'package:celtas_mobile/features/settings/application/app_version_check.dart';
import 'package:celtas_mobile/features/settings/application/app_version_gate_controller.dart';
import 'package:celtas_mobile/features/settings/application/settings_providers.dart';
import 'package:celtas_mobile/features/settings/data/models/business_hours.dart';
import 'package:celtas_mobile/features/settings/presentation/widgets/force_update_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _Repository extends HomeRepository {
  _Repository() : super(Dio());
  final menus = <Completer<List<PublicMenuCategory>>>[];
  final banners = <Completer<List<Banner>>>[];

  @override
  Future<List<PublicMenuCategory>> getMenu() {
    final request = Completer<List<PublicMenuCategory>>();
    menus.add(request);
    return request.future;
  }

  @override
  Future<List<Banner>> getActiveBanners() {
    final request = Completer<List<Banner>>();
    banners.add(request);
    return request.future;
  }
}

class _Addresses extends AddressListNotifier {
  @override
  Future<List<Address>> build() async => [];
}

class _SelectedAddress extends SelectedAddressNotifier {
  @override
  String? build() => null;
}

void main() {
  const category = PublicMenuCategory(
    id: 'category',
    name: 'Hamburguesas',
    items: [
      PublicMenuItem(id: 'product', name: 'Burger disponible', price: 15),
    ],
  );
  final banner = Banner(
    id: 'banner',
    title: 'Promoción anterior',
    actionType: BannerActionType.none,
    active: true,
    order: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  const connection = ApiException('connection', kind: ApiErrorKind.connection);
  late ProviderContainer container;
  late _Repository repository;
  var versionCheck = const AppVersionCheck(
    isUpdateRequired: false,
    minVersion: '1.0.1+16',
  );

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(
    WidgetTester tester, {
    bool detail = false,
    bool gated = false,
  }) async {
    repository = _Repository();
    final router = gated
        ? GoRouter(
            initialLocation: '/home',
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          )
        : null;
    if (router != null) addTearDown(router.dispose);
    container = ProviderContainer(
      overrides: [
        if (router != null) routerProvider.overrideWithValue(router),
        if (gated)
          appVersionCheckProvider.overrideWith((ref) async => versionCheck),
        homeRepositoryProvider.overrideWithValue(repository),
        addressListProvider.overrideWith(_Addresses.new),
        selectedAddressIdProvider.overrideWith(_SelectedAddress.new),
        unreadNotificationCountProvider.overrideWithValue(0),
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: gated
            ? const CeltasApp()
            : MaterialApp(
                theme: AppTheme.dark,
                home: detail
                    ? const ProductDetailScreen(productId: 'product')
                    : const HomeScreen(),
              ),
      ),
    );
    await tester.pump();
  }

  Future<void> load(
    WidgetTester tester, {
    bool detail = false,
    bool gated = false,
  }) async {
    await mount(tester, detail: detail, gated: gated);
    repository.menus.single.complete([category]);
    if (!detail) repository.banners.single.complete([banner]);
    await tester.pumpAndSettle();
  }

  TextButton retry(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reintentar'));

  testWidgets(
    'UpdateRequired takes precedence over Home recovery and navigation',
    (tester) async {
      await load(tester, gated: true);
      final pending = container.read(homeRefreshProvider).all();
      await tester.pump();
      repository.menus.last.completeError(connection);
      repository.banners.last.completeError(connection);
      await tester.pumpAndSettle();
      await pending;
      expect(find.byType(ContentRecoveryNotice), findsOneWidget);
      final router = container.read(routerProvider);
      versionCheck = const AppVersionCheck(
        isUpdateRequired: true,
        minVersion: '1.0.1+17',
      );
      container.read(appVersionGateProvider.notifier).recheck();
      await tester.pumpAndSettle();
      router.go('/home');
      await tester.pumpAndSettle();
      expect(find.byType(ForceUpdateScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(ContentRecoveryNotice), findsNothing);
      expect(await tester.binding.handlePopRoute(), isTrue);
      expect(container.read(routerProvider), same(router));
      expect(repository.menus, hasLength(2));
      expect(repository.banners, hasLength(2));
    },
  );

  testWidgets(
    'initial connection failure is distinct from empty; retry only menu',
    (tester) async {
      await mount(tester);
      repository.menus.single.completeError(connection);
      repository.banners.single.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No pudimos conectar'), findsOneWidget);
      expect(
        find.text('Revisa tu conexión e inténtalo nuevamente'),
        findsOneWidget,
      );
      expect(find.text('No se pudo cargar el menú'), findsOneWidget);
      expect(find.text('El menú está vacío por ahora'), findsNothing);
      expect(find.textContaining('Sin Internet'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(repository.menus, hasLength(2));
      expect(repository.banners, hasLength(1));
      expect(retry(tester).onPressed, isNull);
      repository.menus.last.complete([category]);
      await tester.pumpAndSettle();
      expect(find.text('Burger disponible'), findsOneWidget);
      expect(find.byType(ContentRecoveryNotice), findsNothing);
    },
  );

  for (final (error, title, description) in [
    (
      const ApiException('503', statusCode: 503),
      'Servicio temporalmente no disponible',
      'Puedes explorar el contenido disponible e intentar nuevamente',
    ),
    (
      const ApiException('timeout', kind: ApiErrorKind.timeout),
      'La consulta está tardando demasiado',
      'Inténtalo de nuevo en un momento',
    ),
  ]) {
    testWidgets('initial $title displays exact recovery notice', (
      tester,
    ) async {
      await mount(tester);
      repository.menus.single.completeError(error);
      repository.banners.single.complete([]);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text(description), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('El menú está vacío por ahora'), findsNothing);
    });
  }

  testWidgets('successful empty responses show empty state without error', (
    tester,
  ) async {
    await mount(tester);
    repository.menus.single.complete([]);
    repository.banners.single.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('El menú está vacío por ahora'), findsOneWidget);
    expect(find.byType(ContentRecoveryNotice), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
  });

  for (final menuFails in [true, false]) {
    testWidgets(
      '${menuFails ? "menu" : "banners"} retains data on refresh and later error',
      (tester) async {
        await load(tester);
        final refresh = container.read(homeRefreshProvider);
        final pending = menuFails ? refresh.menu() : refresh.banners();
        await tester.pump();
        expect(find.text('Burger disponible'), findsOneWidget);
        expect(find.text('PROMOCIÓN ANTERIOR'), findsOneWidget);
        expect(find.text('Actualizando contenido'), findsOneWidget);
        if (menuFails) {
          repository.menus.last.completeError(connection);
        } else {
          repository.banners.last.completeError(connection);
        }
        await tester.pumpAndSettle();
        await pending;
        expect(find.text('Burger disponible'), findsOneWidget);
        expect(find.text('PROMOCIÓN ANTERIOR'), findsOneWidget);
        expect(find.text('No pudimos conectar'), findsOneWidget);
        expect(
          find.textContaining(
            'Los precios y la disponibilidad pueden haber cambiado',
          ),
          findsOneWidget,
        );
        expect(find.text('No se pudo cargar el menú'), findsNothing);
        expect(find.text('No se pudieron cargar los banners'), findsNothing);
        expect(repository.menus, hasLength(menuFails ? 2 : 1));
        expect(repository.banners, hasLength(menuFails ? 1 : 2));
      },
    );
  }

  testWidgets(
    'simultaneous failures use one notice; retry and pull refresh share requests',
    (tester) async {
      await load(tester);
      final refresh = container.read(homeRefreshProvider);
      final first = refresh.all();
      await tester.pump();
      repository.menus.last.completeError(connection);
      repository.banners.last.completeError(
        const ApiException('503', statusCode: 503),
      );
      await tester.pumpAndSettle();
      await first;
      expect(find.byType(ContentRecoveryNotice), findsOneWidget);
      expect(find.text('No pudimos conectar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      final retryAction = retry(tester).onPressed!;
      retryAction();
      retryAction(); // Two taps before the rebuild must still coalesce.
      final concurrent = refresh.all();
      await tester.pump();
      expect(repository.menus, hasLength(3));
      expect(repository.banners, hasLength(3));
      expect(retry(tester).onPressed, isNull);
      repository.menus.last.complete([category]);
      await tester.pump();
      expect(find.byType(ContentRecoveryNotice), findsOneWidget);
      expect(find.text('Servicio temporalmente no disponible'), findsOneWidget);
      repository.banners.last.complete([banner]);
      await tester.pumpAndSettle();
      await concurrent;
      expect(find.byType(ContentRecoveryNotice), findsNothing);
      expect(repository.menus, hasLength(3));
      expect(repository.banners, hasLength(3));
    },
  );

  testWidgets(
    'pull-to-refresh refreshes both and retains content after failure',
    (tester) async {
      await load(tester);
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.menus, hasLength(2));
      expect(repository.banners, hasLength(2));
      expect(find.text('Burger disponible'), findsOneWidget);
      repository.menus.last.completeError(connection);
      repository.banners.last.complete([banner]);
      await tester.pumpAndSettle();
      expect(find.text('Burger disponible'), findsOneWidget);
      expect(find.text('No pudimos conectar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'product detail retains data and quantity after menu failure and recovery',
    (tester) async {
      await load(tester, detail: true);
      await tester.ensureVisible(find.byKey(const ValueKey('detail-qty-plus')));
      await tester.tap(find.byKey(const ValueKey('detail-qty-plus')));
      await tester.pump();
      expect(find.text('AGREGAR AL CARRITO · S/ 30.00'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      final pending = container.read(homeRefreshProvider).menu();
      await tester.pump();
      expect(find.text('Burger disponible'), findsOneWidget);
      repository.menus.last.completeError(connection);
      await tester.pumpAndSettle();
      await pending;
      expect(find.text('Burger disponible'), findsOneWidget);
      expect(find.text('No pudimos conectar'), findsOneWidget);
      expect(
        find.textContaining(
          'Los precios y la disponibilidad pueden haber cambiado',
        ),
        findsOneWidget,
      );
      expect(find.text('No se pudo cargar el producto'), findsNothing);
      expect(find.text('AGREGAR AL CARRITO · S/ 30.00'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(retry(tester).onPressed, isNull);
      repository.menus.last.complete([category]);
      await tester.pumpAndSettle();
      expect(find.byType(ContentRecoveryNotice), findsNothing);
      expect(find.text('Burger disponible'), findsOneWidget);
      expect(find.text('AGREGAR AL CARRITO · S/ 30.00'), findsOneWidget);
      expect(repository.banners, isEmpty);
    },
  );
}
