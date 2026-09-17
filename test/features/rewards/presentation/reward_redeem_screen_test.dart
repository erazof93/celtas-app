import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/rewards/application/reward_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_catalog_item.dart';
import 'package:celtas_mobile/features/rewards/presentation/reward_redeem_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cubre el requisito de verificación del ROADMAP: que `isSpecial` viaje
/// correctamente desde la ruta hasta el catálogo que se pide —
/// `rewardCatalogProvider(true)` para un premio especial,
/// `rewardCatalogProvider(false)` para uno normal — SIN mezclar ambas
/// listas.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const normalItem = RewardCatalogItem(
    id: 'i-normal',
    name: 'Berserker Burger',
    price: 15.5,
  );
  const specialItem = RewardCatalogItem(
    id: 'i-special',
    name: 'Combo Vikingo Especial',
    price: 32,
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required bool isSpecial,
  }) async {
    final container = ProviderContainer(
      overrides: [
        rewardCatalogProvider(false).overrideWith((ref) async => [normalItem]),
        rewardCatalogProvider(true).overrideWith((ref) async => [specialItem]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: RewardRedeemScreen(redemptionId: 'r-1', isSpecial: isSpecial),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'isSpecial: false → pide rewardCatalogProvider(false), muestra el '
    'catálogo NORMAL, sin badge de especial',
    (tester) async {
      await pumpScreen(tester, isSpecial: false);

      expect(find.text('Berserker Burger'), findsOneWidget);
      expect(find.text('Combo Vikingo Especial'), findsNothing);
      expect(find.text('★ Premio especial'), findsNothing);
    },
  );

  testWidgets('isSpecial: true → pide rewardCatalogProvider(true), muestra el '
      'catálogo ESPECIAL con su badge, nunca el normal', (tester) async {
    await pumpScreen(tester, isSpecial: true);

    expect(find.text('Combo Vikingo Especial'), findsOneWidget);
    expect(find.text('Berserker Burger'), findsNothing);
    expect(find.text('★ Premio especial'), findsOneWidget);
  });

  group('canje: navega a Home en vez de volver al canje', () {
    GoRouter router() => GoRouter(
      initialLocation: '/rewards/redeem/r-1',
      routes: [
        GoRoute(
          path: '/rewards/redeem/:redemptionId',
          builder: (context, state) => RewardRedeemScreen(
            redemptionId: state.pathParameters['redemptionId']!,
            isSpecial: state.uri.queryParameters['especial'] == 'true',
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );

    Future<ProviderContainer> pumpWithRouter(WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          rewardCatalogProvider(
            false,
          ).overrideWith((ref) async => [normalItem]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: router(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets(
      'al tocar un premio del catálogo: agrega al carrito, muestra '
      '"¡Premio agregado al carrito!" y, tras la pausa, navega a /home '
      'reemplazando el stack (ya no hace falta "volver" a Mis Estrellas)',
      (tester) async {
        final container = await pumpWithRouter(tester);

        await tester.tap(find.byKey(const ValueKey('reward-catalog-i-normal')));
        // Antes de que venza la pausa de 800ms: el SnackBar ya está, pero
        // todavía NO se navegó — la pantalla de canje sigue visible.
        await tester.pump();

        expect(
          find.text('¡Premio agregado al carrito!'),
          findsOneWidget,
        );
        expect(
          container.read(cartProvider).items.single.rewardRedemptionId,
          'r-1',
        );
        expect(find.text('HOME'), findsNothing);

        // Deja pasar la pausa completa y asienta la navegación.
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(find.text('HOME'), findsOneWidget);
        expect(find.byType(RewardRedeemScreen), findsNothing);
      },
    );
  });
}
