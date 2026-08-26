import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/rewards/application/reward_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:celtas_mobile/features/rewards/data/reward_repository.dart';
import 'package:celtas_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRewardRepository extends Mock implements RewardRepository {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://backend-celtas.onrender.com',
    );
  });

  setUp(() {
    // El historial de "premios ya vistos" (`SeenRewardsStorage`) lee
    // `shared_preferences` real al detectar un premio nuevo — sin este mock
    // el canal de plataforma no responde en el entorno de test.
    SharedPreferences.setMockInitialValues({});
  });

  GoRouter router() => GoRouter(
        initialLocation: '/rewards',
        routes: [
          GoRoute(
            path: '/rewards',
            builder: (_, _) => const RewardsScreen(),
          ),
        ],
      );

  // `awaitSettle: false` cuando puede haber un `ConfettiWidget` activo (premio
  // nuevo detectado): su animación de partículas sigue programando frames
  // más allá de su `duration`, así que `pumpAndSettle` nunca asienta y tira
  // "pumpAndSettle timed out" — en su lugar se hacen pumps acotados,
  // suficientes para que el `FutureProvider` resuelva y la UI se reconstruya.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required MockRewardRepository repository,
    bool awaitSettle = true,
  }) async {
    final container = ProviderContainer(
      overrides: [rewardRepositoryProvider.overrideWithValue(repository)],
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
    if (awaitSettle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets(
    'estrellasParaProximoPremio 0 SIN premio disponible (cliente sin '
    'estrellas este mes, ej. recién registrado) → grilla vacía y aviso de '
    'primera estrella, NUNCA el mensaje de premio listo (el resto `0 % N` '
    'es ambiguo entre "recién se cruzó un múltiplo" y "no tiene ninguna '
    'estrella todavía")',
    (tester) async {
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => const RewardProgress(
          estrellasParaProximoPremio: 0,
          estrellasPorPremio: 10,
          premiosDisponibles: [],
        ),
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('0 de 10 estrellas'), findsOneWidget);
      expect(
        find.text('Empieza a comprar para ganar tu primera estrella'),
        findsOneWidget,
      );
      expect(
        find.text('¡Ya puedes desbloquear tu próximo premio!'),
        findsNothing,
      );
      // Grilla completamente vacía: ninguna estrella rellena.
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(10));
    },
  );

  testWidgets(
    'estrellasParaProximoPremio 0 CON premio disponible (recién se cruzó '
    'un múltiplo) → la grilla SIEMPRE representa el progreso hacia el '
    'PRÓXIMO premio (0 de 10, sin inflarse a llena); el aviso del premio ya '
    'ganado vive únicamente en la sección "Premios disponibles"',
    (tester) async {
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => RewardProgress(
          estrellasParaProximoPremio: 0,
          estrellasPorPremio: 10,
          premiosDisponibles: [
            RewardSlot(
              id: 'r-1',
              expiresAt: DateTime.now().add(const Duration(days: 15)),
            ),
          ],
        ),
      );

      // `awaitSettle: false`: hay un premio nunca visto → aparece el overlay
      // de celebración con `ConfettiWidget`, cuya animación de partículas
      // sigue programando frames más allá de su `duration` y nunca deja
      // asentar a `pumpAndSettle`.
      await pumpScreen(tester, repository: repository, awaitSettle: false);
      // Cierra el overlay de celebración para poder inspeccionar la grilla
      // debajo — al desmontarse, `ConfettiController` se dispone, así que
      // `pumpAndSettle` después de esto sí puede asentar sin problema.
      final viewRewardsButton = find.byKey(
        const ValueKey('reward-unlock-view'),
      );
      expect(viewRewardsButton, findsOneWidget);
      await tester.tap(viewRewardsButton);
      await tester.pumpAndSettle();

      expect(find.text('0 de 10 estrellas'), findsOneWidget);
      expect(
        find.text('Te faltan 10 estrellas para desbloquear tu próximo premio'),
        findsOneWidget,
      );
      expect(
        find.text('¡Ya puedes desbloquear tu próximo premio!'),
        findsNothing,
      );
      expect(
        find.text('Empieza a comprar para ganar tu primera estrella'),
        findsNothing,
      );
      // El aviso del premio ya ganado sigue viviendo en su propia sección.
      expect(find.text('Premios disponibles'), findsOneWidget);
      expect(find.byKey(const ValueKey('reward-slot-r-1')), findsOneWidget);
    },
  );

  testWidgets(
    'estrellasParaProximoPremio > 0 → grilla parcial y "Te faltan N '
    'estrellas" (estrellasParaProximoPremio es lo YA ACUMULADO, no lo que '
    'falta)',
    (tester) async {
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => const RewardProgress(
          estrellasParaProximoPremio: 4,
          estrellasPorPremio: 10,
          premiosDisponibles: [],
        ),
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('4 de 10 estrellas'), findsOneWidget);
      expect(
        find.text('Te faltan 6 estrellas para desbloquear tu próximo premio'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(6));
    },
  );

  testWidgets(
    'regresión producción: 12 estrellas ganadas este mes con '
    'estrellasPorPremio=10 (backend devuelve 12 % 10 = 2 ya acumuladas) → '
    'debe mostrar "2 de 10 estrellas" / "Te faltan 8", NUNCA restar el '
    'acumulado del total',
    (tester) async {
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => const RewardProgress(
          estrellasParaProximoPremio: 2,
          estrellasPorPremio: 10,
          premiosDisponibles: [],
        ),
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('2 de 10 estrellas'), findsOneWidget);
      expect(
        find.text('Te faltan 8 estrellas para desbloquear tu próximo premio'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(8));
    },
  );
}
