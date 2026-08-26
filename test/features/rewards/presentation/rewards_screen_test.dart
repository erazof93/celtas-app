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

  String? capturedEspecialParam;

  GoRouter router() => GoRouter(
    initialLocation: '/rewards',
    routes: [
      GoRoute(path: '/rewards', builder: (_, _) => const RewardsScreen()),
      // Captura el query param `especial` real que le llega a la ruta de
      // canje — mismo prefijo que cubre `app_router.dart`, sin necesidad
      // de montar `RewardRedeemScreen` completa acá.
      GoRoute(
        path: '/rewards/redeem/:redemptionId',
        builder: (context, state) {
          capturedEspecialParam = state.uri.queryParameters['especial'];
          return const Scaffold(body: Text('redeem-screen'));
        },
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
    capturedEspecialParam = null;
    final container = ProviderContainer(
      overrides: [rewardRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router()),
      ),
    );
    if (awaitSettle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  group('tablero de hitos', () {
    testWidgets(
      'hitos vacío (admin sin configurar todavía) → estado neutro simple, '
      'sin tablero, sin crashear',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 3,
            hitos: [],
            premiosDisponibles: [],
          ),
        );

        await pumpScreen(tester, repository: repository);

        expect(find.text('3 estrellas este mes'), findsOneWidget);
        expect(find.byType(RewardsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'numeración "Premio N" con 2 hitos normales, ambos sin alcanzar',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 1,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 3,
                alcanzado: false,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 6,
                alcanzado: false,
                esEspecial: false,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        await pumpScreen(tester, repository: repository);

        expect(find.text('Premio 1'), findsOneWidget);
        expect(find.text('Premio 2'), findsOneWidget);
        expect(find.text('1 de 6 estrellas'), findsOneWidget);
        expect(
          find.text('Te faltan 2 estrellas para desbloquear tu próximo premio'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'numeración "Premio N" con 4 hitos y el especial en el MEDIO (no al '
      'final) — la numeración de los normales sigue por posición entre sí, '
      'ignorando al especial',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 4,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 2,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 4,
                alcanzado: true,
                esEspecial: false,
              ),
              // Especial EN EL MEDIO, entre el 3er y 4to hito normal.
              RewardMilestoneProgress(
                estrellasRequeridas: 6,
                alcanzado: false,
                esEspecial: true,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 8,
                alcanzado: false,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 10,
                alcanzado: false,
                esEspecial: false,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        // `awaitSettle: false`: hay hitos alcanzados + un especial
        // pendiente, así que el trofeo/glow de `_ProgressCard` animan en
        // loop infinito (por diseño) — `pumpAndSettle` nunca asentaría.
        await pumpScreen(tester, repository: repository, awaitSettle: false);

        // 4 hitos normales (2,4,8,10) numerados 1-4 por posición ascendente
        // entre sí, el especial (6) nunca consume un número.
        expect(find.text('Premio 1'), findsOneWidget);
        expect(find.text('Premio 2'), findsOneWidget);
        expect(find.text('Premio 3'), findsOneWidget);
        expect(find.text('Premio 4'), findsOneWidget);
        expect(find.text('★ Especial'), findsOneWidget);
        expect(find.text('Premio 5'), findsNothing);
      },
    );

    testWidgets('4 combinaciones alcanzado × especial en un mismo tablero', (
      tester,
    ) async {
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => const RewardProgress(
          estrellasDelMes: 8,
          hitos: [
            // 1: alcanzado + normal
            RewardMilestoneProgress(
              estrellasRequeridas: 5,
              alcanzado: true,
              esEspecial: false,
            ),
            // 2: alcanzado + especial
            RewardMilestoneProgress(
              estrellasRequeridas: 8,
              alcanzado: true,
              esEspecial: true,
            ),
            // 3: no alcanzado + normal
            RewardMilestoneProgress(
              estrellasRequeridas: 12,
              alcanzado: false,
              esEspecial: false,
            ),
            // 4: no alcanzado + especial
            RewardMilestoneProgress(
              estrellasRequeridas: 15,
              alcanzado: false,
              esEspecial: true,
            ),
          ],
          premiosDisponibles: [],
        ),
      );

      // `awaitSettle: false`: hay hitos alcanzados (trofeo en loop) y un
      // especial pendiente (glow en loop) — mismo motivo que arriba.
      await pumpScreen(tester, repository: repository, awaitSettle: false);

      // Combo 1: "Premio 1" (único normal, el 8-especial no cuenta).
      expect(find.text('Premio 1'), findsOneWidget);
      // Combo 3: "Premio 2" (segundo normal por posición: 5 y 12).
      expect(find.text('Premio 2'), findsOneWidget);
      // Combo 2 y 4 comparten la etiqueta "★ Especial" (dos hitos
      // especiales en este tablero).
      expect(find.text('★ Especial'), findsNWidgets(2));

      // Celda 8 (alcanzado+especial): estrella rellena grande.
      final cell8 = find.byKey(const ValueKey('milestone-cell-8'));
      expect(cell8, findsOneWidget);
      expect(
        find.descendant(of: cell8, matching: find.byIcon(Icons.star_rounded)),
        findsWidgets,
      );

      // Celda 15 (no alcanzado+especial): contorno pendiente, sin trofeo.
      final cell15 = find.byKey(const ValueKey('milestone-cell-15'));
      expect(cell15, findsOneWidget);
      expect(
        find.descendant(
          of: cell15,
          matching: find.byIcon(Icons.star_outline_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('estrella filled/vacía sigue la misma regla (starNumber <= '
        'estrellasDelMes) para celdas normales Y de hito', (tester) async {
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => const RewardProgress(
          estrellasDelMes: 2,
          hitos: [
            RewardMilestoneProgress(
              estrellasRequeridas: 5,
              alcanzado: false,
              esEspecial: false,
            ),
          ],
          premiosDisponibles: [],
        ),
      );

      await pumpScreen(tester, repository: repository);

      // Estrellas normales 1 y 2 rellenas, 3 y 4 vacías.
      final cell1 = find.byKey(const ValueKey('milestone-cell-1'));
      final cell3 = find.byKey(const ValueKey('milestone-cell-3'));
      expect(
        find.descendant(of: cell1, matching: find.byIcon(Icons.star_rounded)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cell3,
          matching: find.byIcon(Icons.star_outline_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group('premios disponibles', () {
    testWidgets(
      'slot normal: sin pill ESPECIAL, botón naranja, navega SIN el query '
      'param especial',
      (tester) async {
        // Premio marcado como ya visto: el foco de este test es la tarjeta
        // y la navegación, no la celebración de desbloqueo (que trae su
        // propio `ConfettiWidget` y rompe `pumpAndSettle`).
        SharedPreferences.setMockInitialValues({
          'seen_reward_redemption_ids': ['r-1'],
        });
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 5,
            hitos: const [],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-1',
                expiresAt: DateTime.now().add(const Duration(days: 10)),
                esEspecial: false,
              ),
            ],
          ),
        );

        await pumpScreen(tester, repository: repository);

        expect(find.text('★ ESPECIAL'), findsNothing);
        expect(find.text('Premio disponible'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('reward-redeem-r-1')));
        await tester.pumpAndSettle();

        expect(find.text('redeem-screen'), findsOneWidget);
        expect(capturedEspecialParam, isNull);
      },
    );

    testWidgets('slot especial: pill ESPECIAL, copy distinto, navega CON '
        'especial=true', (tester) async {
      // Mismo motivo que arriba: premio ya visto, sin overlay de
      // celebración de por medio.
      SharedPreferences.setMockInitialValues({
        'seen_reward_redemption_ids': ['r-2'],
      });
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => RewardProgress(
          estrellasDelMes: 15,
          hitos: const [],
          premiosDisponibles: [
            RewardSlot(
              id: 'r-2',
              expiresAt: DateTime.now().add(const Duration(days: 10)),
              esEspecial: true,
            ),
          ],
        ),
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('★ ESPECIAL'), findsOneWidget);
      expect(find.text('Premio especial disponible'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reward-redeem-r-2')));
      await tester.pumpAndSettle();

      expect(find.text('redeem-screen'), findsOneWidget);
      expect(capturedEspecialParam, 'true');
    });
  });

  group('overlay de desbloqueo', () {
    testWidgets('premio normal nuevo → overlay genérico ("Ya puedes canjear tu '
        'premio."), sin mención de estrellas requeridas', (tester) async {
      final repository = MockRewardRepository();
      when(() => repository.getProgress()).thenAnswer(
        (_) async => RewardProgress(
          estrellasDelMes: 5,
          hitos: const [
            RewardMilestoneProgress(
              estrellasRequeridas: 5,
              alcanzado: true,
              esEspecial: false,
            ),
          ],
          premiosDisponibles: [
            RewardSlot(
              id: 'r-1',
              expiresAt: DateTime.now().add(const Duration(days: 15)),
              esEspecial: false,
            ),
          ],
        ),
      );

      await pumpScreen(tester, repository: repository, awaitSettle: false);

      expect(find.byKey(const ValueKey('reward-unlock-card')), findsOneWidget);
      expect(find.text('Ya puedes canjear tu premio.'), findsOneWidget);
      expect(find.text('★ PREMIO ESPECIAL'), findsNothing);
    });

    testWidgets(
      'premio especial nuevo → overlay dorado con el umbral REAL del hito '
      'especial alcanzado, nunca un número hardcodeado',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 12,
            hitos: const [
              RewardMilestoneProgress(
                estrellasRequeridas: 12,
                alcanzado: true,
                esEspecial: true,
              ),
            ],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-2',
                expiresAt: DateTime.now().add(const Duration(days: 15)),
                esEspecial: true,
              ),
            ],
          ),
        );

        await pumpScreen(tester, repository: repository, awaitSettle: false);

        expect(
          find.byKey(const ValueKey('reward-unlock-card-special')),
          findsOneWidget,
        );
        expect(find.text('★ PREMIO ESPECIAL'), findsOneWidget);
        expect(
          find.text(
            'Completaste las 12 estrellas del mes. Ya puedes canjear tu '
            'premio especial.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tanda mixta (normal + especial a la vez) → celebra la normal '
      'primero, y al cerrarla aparece la especial — ningún premio se pierde',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 15,
            hitos: const [
              RewardMilestoneProgress(
                estrellasRequeridas: 5,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 15,
                alcanzado: true,
                esEspecial: true,
              ),
            ],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-1',
                expiresAt: DateTime.now().add(const Duration(days: 15)),
                esEspecial: false,
              ),
              RewardSlot(
                id: 'r-2',
                expiresAt: DateTime.now().add(const Duration(days: 15)),
                esEspecial: true,
              ),
            ],
          ),
        );

        await pumpScreen(tester, repository: repository, awaitSettle: false);

        // La normal se celebra primero.
        expect(
          find.byKey(const ValueKey('reward-unlock-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('reward-unlock-card-special')),
          findsNothing,
        );

        await tester.tap(find.byKey(const ValueKey('reward-unlock-view')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Al cerrarla, la especial aparece sola — nada se perdió.
        expect(
          find.byKey(const ValueKey('reward-unlock-card-special')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Completaste las 15 estrellas del mes. Ya puedes canjear tu '
            'premio especial.',
          ),
          findsOneWidget,
        );

        // `pump` acotado, no `pumpAndSettle`: debajo de ambos overlays, el
        // tablero sigue con hitos alcanzados (5 y 15) → el trofeo/glow de
        // `_ProgressCard` siguen animando en loop.
        await tester.tap(find.byKey(const ValueKey('reward-unlock-view')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(const ValueKey('reward-unlock-card')), findsNothing);
        expect(
          find.byKey(const ValueKey('reward-unlock-card-special')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'premio ya visto (mismo id que en una apertura anterior) no vuelve a '
      'celebrarse',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'seen_reward_redemption_ids': ['r-1'],
        });
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 5,
            hitos: const [],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-1',
                expiresAt: DateTime.now().add(const Duration(days: 15)),
                esEspecial: false,
              ),
            ],
          ),
        );

        await pumpScreen(tester, repository: repository);

        expect(find.byKey(const ValueKey('reward-unlock-card')), findsNothing);
      },
    );
  });
}
