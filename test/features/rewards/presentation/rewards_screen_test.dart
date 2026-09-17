import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/rewards/application/reward_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_redemption_estado.dart';
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
      // Destino real de "Seguir comprando" en el overlay de celebración
      // (`_RewardUnlockOverlayState`).
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
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
        // El badge especial ya no incrusta el carácter "★" en el string
        // (ese glyph no está garantizado en la fuente) — dibuja un ícono
        // de estrella real al lado del texto "Especial".
        expect(find.text('Especial'), findsOneWidget);
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
      // Combo 2 y 4 comparten la etiqueta "Especial" (dos hitos especiales
      // en este tablero) — el "★" ahora es un ícono real, no parte del
      // string (ver comentario del primer test de este grupo).
      expect(find.text('Especial'), findsNWidgets(2));

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

    testWidgets(
      'tablero con muchos hitos (25, configurables libremente desde el '
      'admin) renderiza las 5 filas sin overflow ni excepciones — la '
      'cantidad de hitos nunca está hardcodeada en la UI',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 12,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 5,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 10,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 15,
                alcanzado: false,
                esEspecial: true,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 20,
                alcanzado: false,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 25,
                alcanzado: false,
                esEspecial: true,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        // `awaitSettle: false`: hay hitos alcanzados (trofeo en loop) —
        // mismo motivo que los demás tests con hitos ya alcanzados.
        await pumpScreen(tester, repository: repository, awaitSettle: false);

        expect(tester.takeException(), isNull);
        expect(find.text('12 de 25 estrellas'), findsOneWidget);
        // Anillo de progreso: ahora es un `Text.rich` (número grande +
        // "/total" chico), así que `find.text` no lo encuentra por `.data`
        // — se arma el texto plano completo de los spans en su lugar.
        expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .where((t) => t.textSpan?.toPlainText() == '12/25'),
          hasLength(1),
        );
        expect(
          find.byKey(const ValueKey('milestone-cell-25')),
          findsOneWidget,
        );
        expect(find.text('Premio 1'), findsOneWidget);
        expect(find.text('Premio 2'), findsOneWidget);
        expect(find.text('Especial'), findsNWidgets(2));
      },
    );

    testWidgets(
      'tablero con 18 hitos (última fila incompleta, 3 de 5 columnas) '
      'mantiene el mismo ancho de columna que las filas completas — bug '
      'real encontrado en dispositivo con un tablero de 18: la última fila '
      'quedaba desalineada, empujada hacia el borde derecho',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 12,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 5,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 10,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 18,
                alcanzado: false,
                esEspecial: false,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        // `awaitSettle: false`: 2 hitos alcanzados → trofeo en loop.
        await pumpScreen(tester, repository: repository, awaitSettle: false);

        expect(tester.takeException(), isNull);

        // Columna 3: estrella 3 (fila 1, completa) y estrella 18 (fila 4,
        // incompleta: solo estrellas 16-18) deben quedar en el mismo eje X
        // — la fila incompleta NO debe repartir sus 3 celdas en 3 columnas
        // anchas, sino ocupar las primeras 3 de las 5 columnas normales.
        final col3Row1X = tester
            .getCenter(find.byKey(const ValueKey('milestone-cell-3')))
            .dx;
        final col3Row4X = tester
            .getCenter(find.byKey(const ValueKey('milestone-cell-18')))
            .dx;
        expect(col3Row4X, closeTo(col3Row1X, 1));
      },
    );

    testWidgets(
      'séptima iteración: la fila queda centrada verticalmente — una celda '
      'de hito alcanzado (más alta, 78px) y una estrella suelta (48px) en '
      'la misma fila comparten el mismo eje Y central, en vez de quedar '
      'alineadas por abajo (bug visto en dispositivo: el hito quedaba más '
      'arriba que el resto de la fila)',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 1,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 1,
                alcanzado: true,
                esEspecial: false,
              ),
              // Solo para que el grid dibuje hasta la estrella 3 (columna
              // 3) en la misma fila — sin hito propio, celda de estrella
              // suelta normal.
              RewardMilestoneProgress(
                estrellasRequeridas: 5,
                alcanzado: false,
                esEspecial: false,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        // `awaitSettle: false`: hito alcanzado → trofeo/glow en loop.
        await pumpScreen(tester, repository: repository, awaitSettle: false);

        final milestoneCellY = tester
            .getCenter(find.byKey(const ValueKey('milestone-cell-1')))
            .dy;
        final plainStarCellY = tester
            .getCenter(find.byKey(const ValueKey('milestone-cell-3')))
            .dy;
        expect(milestoneCellY, closeTo(plainStarCellY, 1));
      },
    );

    testWidgets(
      'badges "Premio N"/"Especial" se mantienen en UNA sola línea, sin '
      'salto de línea, incluso con umbrales de 2 dígitos',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 20,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 12,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 20,
                alcanzado: true,
                esEspecial: true,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        await pumpScreen(tester, repository: repository, awaitSettle: false);

        expect(tester.takeException(), isNull);

        final premioText = tester.widget<Text>(find.text('Premio 1'));
        expect(premioText.maxLines, 1);
        expect(premioText.softWrap, isFalse);

        final especialText = tester.widget<Text>(find.text('Especial'));
        expect(especialText.maxLines, 1);
        expect(especialText.softWrap, isFalse);
      },
    );

    testWidgets(
      'colores: estrella suelta activa (sin hito) es DORADA',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 3,
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

        // Estrella suelta 1-3 (rellena, sin hito): ícono dorado.
        final filledStarIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('milestone-cell-1')),
            matching: find.byIcon(Icons.star_rounded),
          ),
        );
        expect(filledStarIcon.color, CeltasColors.gold);
      },
    );

    testWidgets(
      'colores del medallón (cuarta iteración): hito NORMAL alcanzado es '
      'naranja, hito ESPECIAL alcanzado es dorado — vuelve a diferenciar '
      'por color, ya no ambos dorados',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 8,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 5,
                alcanzado: true,
                esEspecial: false,
              ),
              RewardMilestoneProgress(
                estrellasRequeridas: 8,
                alcanzado: true,
                esEspecial: true,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        await pumpScreen(tester, repository: repository, awaitSettle: false);

        // `size: 30`: el ícono del medallón en sí, distinto de los acentos
        // de confetti (también `Icons.star_rounded`, pero de 9-11px) que
        // conviven en la misma celda.
        final normalIcon = tester
            .widgetList<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('milestone-cell-5')),
                matching: find.byIcon(Icons.star_rounded),
              ),
            )
            .firstWhere((i) => i.size == 30);
        expect(normalIcon.color, CeltasColors.orange);

        final especialIcon = tester
            .widgetList<Icon>(
              find.descendant(
                of: find.byKey(const ValueKey('milestone-cell-8')),
                matching: find.byIcon(Icons.star_rounded),
              ),
            )
            .firstWhere((i) => i.size == 30);
        expect(especialIcon.color, CeltasColors.gold);
      },
    );

    testWidgets(
      'el contenedor circular del medallón alcanzado es translúcido al '
      '40% del color del ícono (no un relleno sólido)',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => const RewardProgress(
            estrellasDelMes: 5,
            hitos: [
              RewardMilestoneProgress(
                estrellasRequeridas: 5,
                alcanzado: true,
                esEspecial: false,
              ),
            ],
            premiosDisponibles: [],
          ),
        );

        await pumpScreen(tester, repository: repository, awaitSettle: false);

        final medallionContainer = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byKey(const ValueKey('milestone-cell-5')),
                matching: find.byType(Container),
              ),
            )
            .firstWhere(
              (c) => ((c.decoration as BoxDecoration?)?.gradient)
                  is LinearGradient,
            );
        final gradient =
            (medallionContainer.decoration as BoxDecoration).gradient
                as LinearGradient;
        final endColor = gradient.colors.last;
        expect(endColor.a, closeTo(0.4, 0.01));
        expect(
          (endColor.r, endColor.g, endColor.b),
          (CeltasColors.orange.r, CeltasColors.orange.g, CeltasColors.orange.b),
        );
      },
    );
  });

  group('premios disponibles', () {
    testWidgets(
      'slot normal: sin pill ESPECIAL, fila completa tappable, navega SIN '
      'el query param especial',
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

    testWidgets(
      'séptima iteración: borde de la fila es NARANJA para un premio '
      'normal y DORADO solo para el especial — el dorado no debe usarse '
      'para un premio normal (se leía como si fuera especial sin serlo)',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 15,
            hitos: const [],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-normal',
                expiresAt: DateTime.now().add(const Duration(days: 10)),
                esEspecial: false,
              ),
              RewardSlot(
                id: 'r-especial',
                expiresAt: DateTime.now().add(const Duration(days: 10)),
                esEspecial: true,
              ),
            ],
          ),
        );
        SharedPreferences.setMockInitialValues({
          'seen_reward_redemption_ids': ['r-normal', 'r-especial'],
        });

        await pumpScreen(tester, repository: repository);

        final normalDecoration =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('reward-slot-r-normal')),
                    )
                    .decoration
                as BoxDecoration?;
        final especialDecoration =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('reward-slot-r-especial')),
                    )
                    .decoration
                as BoxDecoration?;

        expect(normalDecoration?.border?.top.color, CeltasColors.orange);
        expect(especialDecoration?.border?.top.color, CeltasColors.gold);

        // Octava iteración: el ícono de regalo sigue el mismo criterio de
        // color que el borde — naranja normal, dorado solo especial.
        final normalIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('reward-slot-r-normal')),
            matching: find.byIcon(Icons.card_giftcard_rounded),
          ),
        );
        final especialIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('reward-slot-r-especial')),
            matching: find.byIcon(Icons.card_giftcard_rounded),
          ),
        );
        expect(normalIcon.color, CeltasColors.orange);
        expect(especialIcon.color, CeltasColors.gold);
      },
    );

    testWidgets(
      'octava iteración: un premio con estado "redeemed" NO desaparece de '
      '"Premios disponibles" — sigue en la lista, marcado como reclamado',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 5,
            hitos: const [],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-redeemed',
                expiresAt: DateTime.now().add(const Duration(days: 10)),
                esEspecial: false,
                estado: RewardRedemptionEstado.redeemed,
                usedAt: DateTime(2026, 9, 5),
              ),
            ],
          ),
        );
        SharedPreferences.setMockInitialValues({
          'seen_reward_redemption_ids': ['r-redeemed'],
        });

        await pumpScreen(tester, repository: repository);

        // Sigue presente — la fila NO se elimina al estar reclamada.
        expect(
          find.byKey(const ValueKey('reward-slot-r-redeemed')),
          findsOneWidget,
        );
        expect(find.text('✓ Reclamado'), findsOneWidget);
        expect(find.text('Reclamado el 5 sep 2026'), findsOneWidget);
        // El texto de vigencia ("Vence en...") ya no aplica a uno reclamado.
        expect(find.textContaining('Vence en'), findsNothing);
      },
    );

    testWidgets(
      'octava iteración: tocar un premio PENDING sigue navegando al canje '
      'normalmente (regresión: el nuevo estado no rompe el flujo existente)',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 5,
            hitos: const [],
            premiosDisponibles: [
              // `estado` omitido a propósito: el default (`pending`) es
              // justo el caso que este test cubre.
              RewardSlot(
                id: 'r-pending',
                expiresAt: DateTime.now().add(const Duration(days: 10)),
                esEspecial: false,
              ),
            ],
          ),
        );
        SharedPreferences.setMockInitialValues({
          'seen_reward_redemption_ids': ['r-pending'],
        });

        await pumpScreen(tester, repository: repository);

        await tester.tap(find.byKey(const ValueKey('reward-redeem-r-pending')));
        await tester.pumpAndSettle();

        expect(find.text('redeem-screen'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('reward-claimed-dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'octava iteración: tocar un premio REDEEMED muestra el modal '
      '"Premio reclamado" con la fecha real, en vez de navegar al canje',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 5,
            hitos: const [],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-redeemed',
                expiresAt: DateTime.now().add(const Duration(days: 10)),
                esEspecial: true,
                estado: RewardRedemptionEstado.redeemed,
                usedAt: DateTime(2026, 8, 20),
              ),
            ],
          ),
        );
        SharedPreferences.setMockInitialValues({
          'seen_reward_redemption_ids': ['r-redeemed'],
        });

        await pumpScreen(tester, repository: repository);

        await tester.tap(
          find.byKey(const ValueKey('reward-redeem-r-redeemed')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('reward-claimed-dialog')),
          findsOneWidget,
        );
        expect(find.text('Premio reclamado'), findsOneWidget);
        expect(
          find.text('Ya reclamaste este premio el 20 ago 2026.'),
          findsOneWidget,
        );
        // NUNCA navegó al canje real.
        expect(find.text('redeem-screen'), findsNothing);

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('reward-claimed-dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'octava iteración: un premio reclamado se ve desaturado (blanco y '
      'negro) — envuelto en ColorFiltered en vez de mantener sus colores '
      'naranja/dorado normales',
      (tester) async {
        final repository = MockRewardRepository();
        when(() => repository.getProgress()).thenAnswer(
          (_) async => RewardProgress(
            estrellasDelMes: 5,
            hitos: const [],
            premiosDisponibles: [
              RewardSlot(
                id: 'r-redeemed',
                expiresAt: DateTime.now().add(const Duration(days: 10)),
                esEspecial: false,
                estado: RewardRedemptionEstado.redeemed,
                usedAt: DateTime(2026, 9, 5),
              ),
            ],
          ),
        );
        SharedPreferences.setMockInitialValues({
          'seen_reward_redemption_ids': ['r-redeemed'],
        });

        await pumpScreen(tester, repository: repository);

        final colorFiltered = tester.widget<ColorFiltered>(
          find.ancestor(
            of: find.byKey(const ValueKey('reward-slot-r-redeemed')),
            matching: find.byType(ColorFiltered),
          ),
        );
        expect(colorFiltered.colorFilter, isNotNull);
      },
    );
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
      // Novena iteración: ya NO promete "15 días" (la vigencia real es
      // hasta fin del mes calendario en que se gana, ver
      // `getEndOfMonthInLima` en `rewards.service.ts`).
      expect(
        find.text('Tienes hasta fin de mes para reclamarlo'),
        findsOneWidget,
      );
      expect(find.textContaining('15 días'), findsNothing);
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

  group(
    'segunda iteración visual (fondo ambiental, header, sin naranja, '
    'responsive)',
    () {
      /// Viewport lógico real de teléfono (390×844, mismo patrón que
      /// `product_detail_screen_test.dart`) — el viewport 800×600 por
      /// defecto de los widget tests es mucho más ancho que un celular
      /// real y no habría detectado un overflow del nuevo header (subtítulo
      /// + "¡Gracias por ser parte!" a la derecha).
      void setPhoneViewport(WidgetTester tester) {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }

      testWidgets(
        'header + tablero con 15 hitos caben en un viewport de teléfono '
        'real (390×844 lógicos) sin overflow ni excepciones',
        (tester) async {
          setPhoneViewport(tester);
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => RewardProgress(
              estrellasDelMes: 4,
              hitos: List.generate(
                15,
                (i) => RewardMilestoneProgress(
                  estrellasRequeridas: i + 1,
                  alcanzado: i < 4,
                  esEspecial: i == 14,
                ),
              ),
              premiosDisponibles: [
                RewardSlot(
                  id: 'r-1',
                  expiresAt: DateTime.now().add(const Duration(days: 10)),
                  esEspecial: false,
                ),
              ],
            ),
          );
          SharedPreferences.setMockInitialValues({
            'seen_reward_redemption_ids': ['r-1'],
          });

          // `awaitSettle: false`: 4 hitos ya alcanzados → trofeo/glow en
          // loop infinito por diseño (mismo motivo que el resto de los
          // tests con hitos alcanzados en este archivo).
          await pumpScreen(tester, repository: repository, awaitSettle: false);

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'tablero con 30 hitos (máximo configurable de referencia en este '
        'grupo) sigue sin overflow en viewport de teléfono — scroll '
        'vertical, nunca estrellas diminutas',
        (tester) async {
          setPhoneViewport(tester);
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => RewardProgress(
              estrellasDelMes: 10,
              hitos: List.generate(
                30,
                (i) => RewardMilestoneProgress(
                  estrellasRequeridas: i + 1,
                  alcanzado: i < 10,
                  esEspecial: i == 29,
                ),
              ),
              premiosDisponibles: const [],
            ),
          );

          await pumpScreen(tester, repository: repository, awaitSettle: false);

          expect(tester.takeException(), isNull);
          expect(find.text('10 de 30 estrellas'), findsOneWidget);
        },
      );

      testWidgets(
        'grid de estrellas y sección "TU PROGRESO" comparten UN SOLO '
        'contenedor (quinta iteración: el grid ya no tiene su propio '
        'Container separado)',
        (tester) async {
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => const RewardProgress(
              estrellasDelMes: 3,
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

          // Ancestro `Container` con el relleno sólido `_cardDecoration`
          // (`color: CeltasColors.black`, sexta iteración — ya no hay
          // gradiente que buscar) tanto para el grid como para "TU
          // PROGRESO".
          final gridAncestorContainer = tester
              .widgetList<Container>(
                find.ancestor(
                  of: find.byKey(const ValueKey('milestone-cell-1')),
                  matching: find.byType(Container),
                ),
              )
              .firstWhere(
                (c) => (c.decoration as BoxDecoration?)?.color ==
                    CeltasColors.black,
              );
          final progressAncestorContainer = tester
              .widgetList<Container>(
                find.ancestor(
                  of: find.text('TU PROGRESO'),
                  matching: find.byType(Container),
                ),
              )
              .firstWhere(
                (c) => (c.decoration as BoxDecoration?)?.color ==
                    CeltasColors.black,
              );

          // Mismo objeto `_cardDecoration` (no dos cajas anidadas) —
          // confirma que el grid ya no está envuelto en su propia caja
          // decorada por separado.
          expect(
            identical(
              gridAncestorContainer.decoration,
              progressAncestorContainer.decoration,
            ),
            isTrue,
          );
        },
      );

      testWidgets(
        'badge "Premio N" alcanzado es naranja sólido (pedido explícito de '
        'tercera iteración, revierte el oscuro/translúcido de la segunda)',
        (tester) async {
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => const RewardProgress(
              estrellasDelMes: 5,
              hitos: [
                RewardMilestoneProgress(
                  estrellasRequeridas: 5,
                  alcanzado: true,
                  esEspecial: false,
                ),
              ],
              premiosDisponibles: [],
            ),
          );

          await pumpScreen(tester, repository: repository, awaitSettle: false);

          final premioTagContainer = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('Premio 1'),
                  matching: find.byType(Container),
                )
                .first,
          );
          final decoration = premioTagContainer.decoration as BoxDecoration?;
          expect(decoration?.color, CeltasColors.orange);
        },
      );

      testWidgets(
        'fondo sólido (sexta iteración): tarjeta del tablero y fila de '
        'premio disponible son CeltasColors.black sin degradado — probado '
        'en dispositivo real contra design-reference/estrellas/'
        'screenshot.png, un degradado dorado (incluso a alpha bajo) se veía '
        'demasiado amarillo sumado al glow de los medallones alcanzados',
        (tester) async {
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => RewardProgress(
              estrellasDelMes: 3,
              hitos: const [],
              premiosDisponibles: [
                RewardSlot(
                  id: 'r-1',
                  expiresAt: DateTime.now().add(const Duration(days: 5)),
                  esEspecial: false,
                ),
              ],
            ),
          );
          SharedPreferences.setMockInitialValues({
            'seen_reward_redemption_ids': ['r-1'],
          });

          await pumpScreen(tester, repository: repository);

          // Tarjeta del tablero (hitos vacío usa la misma `_cardDecoration`).
          final boardContainers = tester.widgetList<Container>(
            find.ancestor(
              of: find.text('3 estrellas este mes'),
              matching: find.byType(Container),
            ),
          );
          expect(
            boardContainers.any(
              (c) => (c.decoration as BoxDecoration?)?.color ==
                  CeltasColors.black,
            ),
            isTrue,
          );
          expect(
            boardContainers.every(
              (c) => (c.decoration as BoxDecoration?)?.gradient == null,
            ),
            isTrue,
          );

          // Fila de premio disponible.
          final slotContainer = tester.widget<Container>(
            find.byKey(const ValueKey('reward-slot-r-1')),
          );
          final slotDecoration = slotContainer.decoration as BoxDecoration?;
          expect(slotDecoration?.color, CeltasColors.black);
          expect(slotDecoration?.gradient, isNull);
        },
      );

      testWidgets(
        'anillo de progreso: el número actual se renderiza más grande que '
        'el "/total"',
        (tester) async {
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => const RewardProgress(
              estrellasDelMes: 12,
              hitos: [
                RewardMilestoneProgress(
                  estrellasRequeridas: 15,
                  alcanzado: false,
                  esEspecial: false,
                ),
              ],
              premiosDisponibles: [],
            ),
          );

          await pumpScreen(tester, repository: repository);

          final ringText = tester
              .widgetList<Text>(find.byType(Text))
              .firstWhere((t) => t.textSpan?.toPlainText() == '12/15');
          final spans = (ringText.textSpan! as TextSpan).children!;
          final currentSize = (spans[0] as TextSpan).style!.fontSize!;
          final totalSize = (spans[1] as TextSpan).style!.fontSize!;
          expect(currentSize, greaterThan(totalSize));
        },
      );

      testWidgets(
        'ícono de regalo (card_giftcard) aparece en cada fila de premio '
        'disponible',
        (tester) async {
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => RewardProgress(
              estrellasDelMes: 6,
              hitos: const [],
              premiosDisponibles: [
                RewardSlot(
                  id: 'r-1',
                  expiresAt: DateTime.now().add(const Duration(days: 5)),
                  esEspecial: false,
                ),
              ],
            ),
          );
          SharedPreferences.setMockInitialValues({
            'seen_reward_redemption_ids': ['r-1'],
          });

          await pumpScreen(tester, repository: repository);

          expect(
            find.byIcon(Icons.card_giftcard_rounded),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'no hay fila "Más estrellas, más premios" (eliminada en la quinta '
        'iteración): sin premios disponibles, la pantalla pasa directo del '
        'tablero a "Términos y condiciones"',
        (tester) async {
          final repository = MockRewardRepository();
          when(() => repository.getProgress()).thenAnswer(
            (_) async => const RewardProgress(
              estrellasDelMes: 2,
              hitos: [],
              premiosDisponibles: [],
            ),
          );

          await pumpScreen(tester, repository: repository);

          expect(find.text('Más estrellas, más premios'), findsNothing);
          expect(
            find.byKey(const ValueKey('rewards-redeem-cta')),
            findsNothing,
          );
          expect(find.text('Términos y condiciones'), findsOneWidget);
        },
      );
    },
  );
}
