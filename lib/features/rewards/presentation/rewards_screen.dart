import 'dart:async';
import 'dart:math';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/rewards/application/reward_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:celtas_mobile/features/rewards/data/seen_rewards_storage.dart';
import 'package:celtas_mobile/features/rewards/presentation/widgets/reward_terms_sheet.dart';
import 'package:celtas_mobile/shared/utils/spanish_date.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Programa de Estrellas (mockup `estrellas01progreso.dc.html`), esquema de
/// HITOS configurables desde el admin (ej. 5, 8, 15 estrellas) en vez del
/// viejo "cada N estrellas = 1 premio".
///
/// `GET /rewards/progress` — estrellas acumuladas este mes, progreso de cada
/// hito del tablero, premios disponibles sin usar/sin vencer, y la promoción
/// de estrellas dobles vigente hoy, si hay alguna.
///
/// **Corrección sobre el mockup**: la tarjeta de premio disponible del
/// mockup original nombraba un producto específico ("Hamburguesa Perio").
/// Eso no es correcto contra el backend real: un premio ganado
/// (`RewardRedemption`) no está atado a ningún producto hasta que se
/// canjea — `GET /rewards/progress` nunca expone nombre de producto para
/// `premiosDisponibles`. La tarjeta usa copy genérico ("Premio disponible").
///
/// Celebración/confeti: no hay push/evento del backend que avise "se generó
/// un premio nuevo" — se detecta comparando `premiosDisponibles` contra
/// `SeenRewardsStorage` (mismo patrón de persistencia local que
/// `NotificationHistoryRepository`), y se muestra UNA vez por premio. Si en
/// una misma tanda hay premios normales Y el especial, se muestra primero la
/// celebración normal (si hay) y luego la especial — ningún premio nuevo se
/// pierde sin celebrar.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  final _seenStorage = SeenRewardsStorage();
  List<RewardSlot>? _pendingNormal;
  List<RewardSlot>? _pendingSpecial;
  int? _specialThreshold;

  /// Compara `premiosDisponibles` contra lo ya visto y, si hay alguno nuevo,
  /// dispara el overlay de celebración una sola vez (marca como visto de
  /// inmediato para no repetirlo en el próximo refresh/apertura). Si un
  /// overlay ya está visible (normal o especial), no vuelve a calcular —
  /// evita pisarlo con una segunda tanda mientras el usuario todavía lo está
  /// viendo.
  Future<void> _maybeCelebrate(RewardProgress progress) async {
    if (_pendingNormal != null || _pendingSpecial != null) return;
    if (progress.premiosDisponibles.isEmpty) return;
    final seen = await _seenStorage.load();
    final unseen = progress.premiosDisponibles
        .where((slot) => !seen.contains(slot.id))
        .toList();
    if (unseen.isEmpty) return;
    await _seenStorage.markSeen(unseen.map((slot) => slot.id));
    if (!mounted) return;

    final normal = unseen.where((s) => !s.esEspecial).toList();
    final special = unseen.where((s) => s.esEspecial).toList();
    setState(() {
      _pendingNormal = normal.isEmpty ? null : normal;
      _pendingSpecial = special.isEmpty ? null : special;
      _specialThreshold = special.isEmpty
          ? null
          : _highestReachedSpecialThreshold(progress);
    });
  }

  /// Umbral del hito especial recién alcanzado, para el copy del overlay
  /// dorado ("Completaste las N estrellas del mes...") sin hardcodear el
  /// número. `null` si por alguna razón `hitos` no trae ningún especial
  /// alcanzado (no debería pasar si el backend acaba de generar el premio,
  /// pero no debe crashear la celebración si pasa).
  int? _highestReachedSpecialThreshold(RewardProgress progress) {
    final reached = progress.hitos
        .where((h) => h.esEspecial && h.alcanzado)
        .map((h) => h.estrellasRequeridas);
    return reached.isEmpty ? null : reached.reduce(max);
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(rewardProgressProvider);

    ref.listen<AsyncValue<RewardProgress>>(rewardProgressProvider, (
      previous,
      next,
    ) {
      final progress = next.valueOrNull;
      if (progress != null) unawaited(_maybeCelebrate(progress));
    });

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 14, 24, 4),
                  child: _RewardsHeader(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: CeltasColors.orange,
                    backgroundColor: CeltasColors.surface,
                    onRefresh: () async {
                      ref.invalidate(rewardProgressProvider);
                      try {
                        await ref.read(rewardProgressProvider.future);
                      } catch (_) {
                        // El estado de error ya se muestra en el `.when` de
                        // abajo.
                      }
                    },
                    child: progressAsync.when(
                      loading: () => ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [SlowBackendNotice()],
                      ),
                      error: (error, _) => ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _RewardsError(
                            message: error is ApiException
                                ? error.message
                                : 'No se pudo cargar tu progreso.',
                            onRetry: () =>
                                ref.invalidate(rewardProgressProvider),
                          ),
                        ],
                      ),
                      data: (progress) => ListView(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                        children: [
                          if (progress.promocionActiva case final promo?) ...[
                            _PromotionBanner(promotion: promo),
                            const SizedBox(height: 16),
                          ],
                          _ProgressCard(progress: progress),
                          if (progress.premiosDisponibles.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Premios disponibles',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: CeltasColors.cream),
                            ),
                            const SizedBox(height: 10),
                            for (final slot in progress.premiosDisponibles) ...[
                              _RewardSlotCard(slot: slot),
                              const SizedBox(height: 10),
                            ],
                          ],
                          const SizedBox(height: 20),
                          Center(
                            child: GestureDetector(
                              key: const ValueKey('rewards-terms-link'),
                              onTap: () => RewardTermsSheet.show(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 15,
                                    color: CeltasColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Términos y condiciones',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          fontSize: 12.5,
                                          color: CeltasColors.textMuted,
                                          decoration: TextDecoration.underline,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_pendingNormal != null)
          _RewardUnlockOverlay(
            isSpecial: false,
            specialThreshold: null,
            onDismiss: () => setState(() => _pendingNormal = null),
          )
        else if (_pendingSpecial != null)
          _RewardUnlockOverlay(
            isSpecial: true,
            specialThreshold: _specialThreshold,
            onDismiss: () => setState(() {
              _pendingSpecial = null;
              _specialThreshold = null;
            }),
          ),
      ],
    );
  }
}

class _RewardsHeader extends StatelessWidget {
  const _RewardsHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROGRAMA DE LEALTAD',
          style: textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: CeltasColors.textLabel,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Mis Estrellas',
          style: textTheme.headlineSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: CeltasColors.cream,
          ),
        ),
      ],
    );
  }
}

class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner({required this.promotion});

  final RewardPromotion promotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeltasColors.surfaceSelected,
        border: Border.all(color: CeltasColors.orange),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_rounded, size: 20, color: CeltasColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  color: CeltasColors.cream,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(
                    text: '¡Estrellas dobles! ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: CeltasColors.orange,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Hasta el ${formatLongDateFromYmd(promotion.endDate)} '
                        'ganas el doble por cada compra',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ordena los hitos NO especiales ascendente por `estrellasRequeridas` y les
/// asigna "Premio 1", "Premio 2"... por posición — nunca por umbral fijo, el
/// admin puede agregar/quitar hitos libremente. Clave del mapa:
/// `estrellasRequeridas` (único por hito).
Map<int, int> _premioNumbers(List<RewardMilestoneProgress> hitos) {
  final normales = hitos.where((h) => !h.esEspecial).toList()
    ..sort((a, b) => a.estrellasRequeridas.compareTo(b.estrellasRequeridas));
  return {
    for (var i = 0; i < normales.length; i++)
      normales[i].estrellasRequeridas: i + 1,
  };
}

/// El hito no alcanzado más cercano (menor `estrellasRequeridas`), para el
/// texto de apoyo "Te faltan N estrellas...". `null` si ya se alcanzaron
/// todos los hitos del mes.
RewardMilestoneProgress? _nextPending(List<RewardMilestoneProgress> hitos) {
  final pending = hitos.where((h) => !h.alcanzado).toList()
    ..sort((a, b) => a.estrellasRequeridas.compareTo(b.estrellasRequeridas));
  return pending.isEmpty ? null : pending.first;
}

/// Tarjeta de progreso: tablero DINÁMICO según `progress.hitos` (ya no una
/// grilla fija de 15 estrellas en 3 filas). `totalStars` es el umbral más
/// alto configurado; filas de 5 estrellas, la última puede quedar
/// incompleta. Comparte 3 `AnimationController`s (trofeo/glow/confetti)
/// entre TODAS las celdas de hito para no multiplicar tickers si hay varios
/// hitos alcanzados a la vez.
class _ProgressCard extends StatefulWidget {
  const _ProgressCard({required this.progress});

  final RewardProgress progress;

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard>
    with TickerProviderStateMixin {
  late final AnimationController _trophyController;
  late final Animation<double> _trophyScale;
  late final AnimationController _glowController;
  late final Animation<double> _glowOpacity;
  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    // Efecto de "trofeo" (`.trophy`/`@keyframes pulse-scale` del mockup):
    // escala 1.0→1.16 en loop, 1.7s. Arranca detenido — `_syncAnimations`
    // decide si hace falta según `widget.progress.hitos` (sin esto, un
    // `AnimationController` en loop infinito nunca deja asentar
    // `pumpAndSettle`, incluso en pantallas sin ningún hito alcanzado).
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _trophyScale = Tween<double>(begin: 1, end: 1.16).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.easeInOut),
    );
    // Resplandor pulsante (`@keyframes pulse-glow`), compartido por el
    // glow del trofeo y el del hito especial pendiente.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _glowOpacity = Tween<double>(begin: 0.75, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    // Loop continuo (no reverse) para el parpadeo escalonado del confetti
    // lateral de cada trofeo — cada acento lee un `phase` propio sobre este
    // mismo controller en vez de tener el suyo.
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant _ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimations();
  }

  /// Arranca/detiene cada loop según haga falta para `widget.progress.hitos`
  /// actual — nunca deja un `AnimationController` en loop infinito sin un
  /// hito real que lo necesite.
  void _syncAnimations() {
    final hitos = widget.progress.hitos;
    final hasTrophy = hitos.any((h) => h.alcanzado);
    final hasPendingSpecial = hitos.any((h) => h.esEspecial && !h.alcanzado);

    if (hasTrophy) {
      if (!_trophyController.isAnimating) {
        _trophyController.repeat(reverse: true);
      }
      if (!_confettiController.isAnimating) _confettiController.repeat();
    } else {
      _trophyController.stop();
      _confettiController.stop();
    }

    if (hasTrophy || hasPendingSpecial) {
      if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _trophyController.dispose();
    _glowController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final hitos = progress.hitos;
    final textTheme = Theme.of(context).textTheme;

    if (hitos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CeltasColors.card,
          border: Border.all(color: CeltasColors.cardBorder),
          borderRadius: BorderRadius.circular(CeltasRadii.card),
        ),
        child: Text(
          '${progress.estrellasDelMes} estrellas este mes',
          textAlign: TextAlign.center,
          style: textTheme.titleSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: CeltasColors.cream,
          ),
        ),
      );
    }

    final totalStars = hitos.map((h) => h.estrellasRequeridas).reduce(max);
    final rows = (totalStars / 5).ceil();
    final hitosByStar = {for (final h in hitos) h.estrellasRequeridas: h};
    final premioNumbers = _premioNumbers(hitos);
    final nextPending = _nextPending(hitos);
    final remaining = nextPending == null
        ? 0
        : nextPending.estrellasRequeridas - progress.estrellasDelMes;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CeltasColors.card,
        border: Border.all(color: CeltasColors.cardBorder),
        borderRadius: BorderRadius.circular(CeltasRadii.card),
      ),
      child: Column(
        children: [
          Column(
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row > 0) const SizedBox(height: 7),
                _MilestoneRow(
                  startStar: row * 5 + 1,
                  endStar: min((row + 1) * 5, totalStars),
                  filledUpTo: progress.estrellasDelMes,
                  hitosByStar: hitosByStar,
                  premioNumbers: premioNumbers,
                  trophyScale: _trophyScale,
                  glowOpacity: _glowOpacity,
                  confetti: _confettiController,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${progress.estrellasDelMes} de $totalStars estrellas',
            style: textTheme.titleSmall?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: CeltasColors.cream,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nextPending == null
                ? '¡Alcanzaste todas las metas de este mes!'
                : 'Te faltan $remaining estrella${remaining == 1 ? '' : 's'} '
                      'para desbloquear tu próximo premio',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: CeltasColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de hasta 5 estrellas (`startStar`..`endStar` inclusive), todas
/// alineadas por abajo (mismo efecto que `align-items:flex-end` en el
/// mockup) porque las celdas de hito son más altas por la etiqueta+tallo.
class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.startStar,
    required this.endStar,
    required this.filledUpTo,
    required this.hitosByStar,
    required this.premioNumbers,
    required this.trophyScale,
    required this.glowOpacity,
    required this.confetti,
  });

  final int startStar;
  final int endStar;
  final int filledUpTo;
  final Map<int, RewardMilestoneProgress> hitosByStar;
  final Map<int, int> premioNumbers;
  final Animation<double> trophyScale;
  final Animation<double> glowOpacity;
  final Animation<double> confetti;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var star = startStar; star <= endStar; star++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MilestoneCell(
                  starNumber: star,
                  filled: star <= filledUpTo,
                  hito: hitosByStar[star],
                  premioNumber: premioNumbers[star],
                  trophyScale: trophyScale,
                  glowOpacity: glowOpacity,
                  confetti: confetti,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Una celda del tablero: estrella normal (42px, sin cambios) si `hito` es
/// `null`, o una de las 4 combinaciones (alcanzado × especial) si coincide
/// con un hito.
class _MilestoneCell extends StatelessWidget {
  const _MilestoneCell({
    required this.starNumber,
    required this.filled,
    required this.hito,
    required this.premioNumber,
    required this.trophyScale,
    required this.glowOpacity,
    required this.confetti,
  });

  final int starNumber;
  final bool filled;
  final RewardMilestoneProgress? hito;
  final int? premioNumber;
  final Animation<double> trophyScale;
  final Animation<double> glowOpacity;
  final Animation<double> confetti;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('milestone-cell-$starNumber'),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final hito = this.hito;
    if (hito == null) {
      return _StarDot(filled: filled, pop: false);
    }

    if (hito.alcanzado) {
      final color = hito.esEspecial ? CeltasColors.gold : CeltasColors.orange;
      final label = hito.esEspecial ? '★ Especial' : 'Premio $premioNumber';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MilestoneTag(label: label, background: color, glow: true),
          Container(width: 2, height: 9, color: color),
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: glowOpacity,
                  builder: (context, child) =>
                      Opacity(opacity: glowOpacity.value, child: child),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: 0.42),
                          color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                ..._confettiAccents(color, confetti),
                AnimatedBuilder(
                  animation: trophyScale,
                  builder: (context, child) =>
                      Transform.scale(scale: trophyScale.value, child: child),
                  child: Icon(Icons.star_rounded, size: 50, color: color),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (hito.esEspecial) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MilestoneTag(
            label: '★ Especial',
            background: CeltasColors.gold,
            glow: true,
          ),
          Container(width: 2, height: 9, color: CeltasColors.gold),
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: glowOpacity,
                  builder: (context, child) =>
                      Opacity(opacity: glowOpacity.value, child: child),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          CeltasColors.gold.withValues(alpha: 0.4),
                          CeltasColors.gold.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.star_outline_rounded,
                  size: 46,
                  color: CeltasColors.gold,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // No alcanzado + normal: mismo tamaño que una celda normal sin relleno,
    // sin trofeo ni glow — solo la etiqueta en tono apagado.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MilestoneTag(
          label: 'Premio $premioNumber',
          background: CeltasColors.borderStrong,
          textColor: CeltasColors.textMuted,
        ),
        Container(width: 2, height: 9, color: CeltasColors.borderStrong),
        const _StarDot(filled: false, pop: false),
      ],
    );
  }
}

/// Etiqueta "Premio N" / "★ Especial" arriba de una celda de hito.
class _MilestoneTag extends StatelessWidget {
  const _MilestoneTag({
    required this.label,
    required this.background,
    this.textColor = CeltasColors.black,
    this.glow = false,
  });

  final String label;
  final Color background;
  final Color textColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: background.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// 4 acentos tipo confetti (mini estrellas + "cintas") alrededor del trofeo,
/// cada uno con su propio ángulo fijo y fase de parpadeo sobre el `confetti`
/// controller compartido — replica el `.confetti > div { animation: twinkle
/// ... }` del mockup sin crear un `AnimationController` por acento.
List<Widget> _confettiAccents(Color color, Animation<double> confetti) {
  Widget accent({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double angleDeg,
    required double phase,
    required double size,
    required bool isStar,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: angleDeg * pi / 180,
        child: AnimatedBuilder(
          animation: confetti,
          builder: (context, child) {
            final t = (confetti.value + phase) % 1.0;
            final twinkle = (1 - (2 * (t - 0.5).abs())).clamp(0.0, 1.0);
            return Opacity(
              opacity: 0.35 + 0.65 * twinkle,
              child: Transform.scale(
                scale: 0.75 + 0.25 * twinkle,
                child: child,
              ),
            );
          },
          child: isStar
              ? Icon(Icons.star_rounded, size: size, color: color)
              : Container(
                  width: size * 0.22,
                  height: size,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ),
      ),
    );
  }

  return [
    accent(top: -8, left: 2, angleDeg: -20, phase: 0, size: 11, isStar: true),
    accent(
      top: -4,
      right: -6,
      angleDeg: 28,
      phase: 0.2,
      size: 16,
      isStar: false,
    ),
    accent(
      left: -8,
      bottom: -2,
      angleDeg: 24,
      phase: 0.45,
      size: 14,
      isStar: false,
    ),
    accent(
      right: 0,
      bottom: -4,
      angleDeg: 18,
      phase: 0.7,
      size: 9,
      isStar: true,
    ),
  ];
}

class _StarDot extends StatelessWidget {
  const _StarDot({required this.filled, required this.pop});

  final bool filled;
  final bool pop;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      filled ? Icons.star_rounded : Icons.star_outline_rounded,
      size: 42,
      color: filled ? CeltasColors.orange : CeltasColors.borderStrong,
    );
    if (!pop) return icon;
    // Animación de "pop" sutil de un solo disparo (no periódica) para la
    // última estrella rellenada — se ejecuta una vez al montarse el widget.
    return TweenAnimationBuilder<double>(
      key: const ValueKey('reward-star-pop'),
      tween: Tween(begin: 0.35, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: icon,
    );
  }
}

/// Tarjeta de un premio ganado y todavía sin canjear. Con `slot.esEspecial`,
/// borde más grueso + resplandor dorado, pill "★ ESPECIAL", y botón
/// "Canjear" dorado en vez de naranja.
class _RewardSlotCard extends StatelessWidget {
  const _RewardSlotCard({required this.slot});

  final RewardSlot slot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final special = slot.esEspecial;
    return Container(
      key: ValueKey('reward-slot-${slot.id}'),
      padding: EdgeInsets.fromLTRB(14, special ? 20 : 14, 14, 14),
      decoration: BoxDecoration(
        color: CeltasColors.surfaceSelected,
        border: Border.all(color: CeltasColors.gold, width: special ? 1.5 : 1),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
        boxShadow: special
            ? [
                BoxShadow(
                  color: CeltasColors.gold.withValues(alpha: 0.3),
                  blurRadius: 22,
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (special)
            Positioned(
              top: -14,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CeltasColors.gold,
                  borderRadius: BorderRadius.circular(CeltasRadii.pill),
                ),
                child: Text(
                  '★ ESPECIAL',
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: CeltasColors.black,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CeltasColors.surface,
                  borderRadius: BorderRadius.circular(CeltasRadii.control),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 22,
                  color: CeltasColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      special
                          ? 'Premio especial disponible'
                          : 'Premio disponible',
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CeltasColors.cream,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDaysRemaining(slot.expiresAt),
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CeltasColors.redLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                key: ValueKey('reward-redeem-${slot.id}'),
                onTap: () => context.push(
                  '/rewards/redeem/${slot.id}${special ? '?especial=true' : ''}',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: special ? CeltasColors.gold : CeltasColors.orange,
                    borderRadius: BorderRadius.circular(CeltasRadii.input),
                  ),
                  child: Text(
                    'Canjear',
                    style: textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: CeltasColors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardsError extends StatelessWidget {
  const _RewardsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        border: Border.all(color: CeltasColors.border),
        borderRadius: BorderRadius.circular(CeltasRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: CeltasColors.redLight),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }
}

/// Overlay de celebración: confeti de un solo disparo (2-3s, sin loop) +
/// tarjeta anclada abajo. Variante normal (mockup `estrellas02desbloqueo.
/// png`, sin cambios) o especial dorada (`estrellas02desbloqueodorado.
/// dc.html`) según `isSpecial`.
class _RewardUnlockOverlay extends StatefulWidget {
  const _RewardUnlockOverlay({
    required this.isSpecial,
    required this.specialThreshold,
    required this.onDismiss,
  });

  final bool isSpecial;

  /// `estrellasRequeridas` del hito especial recién alcanzado, para el copy
  /// del overlay dorado. `null` si no se pudo determinar (no debería pasar,
  /// ver `_highestReachedSpecialThreshold`) — cae a un copy sin número.
  final int? specialThreshold;
  final VoidCallback onDismiss;

  @override
  State<_RewardUnlockOverlay> createState() => _RewardUnlockOverlayState();
}

class _RewardUnlockOverlayState extends State<_RewardUnlockOverlay> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    )..play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final special = widget.isSpecial;
    final accent = special ? CeltasColors.gold : CeltasColors.orange;
    final description = special
        ? (widget.specialThreshold != null
              ? 'Completaste las ${widget.specialThreshold} estrellas del mes. '
                    'Ya puedes canjear tu premio especial.'
              : 'Completaste la meta especial del mes. Ya puedes canjear tu '
                    'premio especial.')
        : 'Ya puedes canjear tu premio.';

    return Positioned.fill(
      child: Material(
        color: CeltasColors.black.withValues(alpha: 0.85),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 24,
                maxBlastForce: 22,
                minBlastForce: 10,
                gravity: 0.25,
                colors: special
                    ? const [CeltasColors.gold, CeltasColors.cream]
                    : const [
                        CeltasColors.orange,
                        CeltasColors.gold,
                        CeltasColors.cream,
                      ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  key: ValueKey(
                    special
                        ? 'reward-unlock-card-special'
                        : 'reward-unlock-card',
                  ),
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: CeltasColors.card,
                    border: Border.all(
                      color: special
                          ? CeltasColors.gold
                          : CeltasColors.cardBorder,
                      width: special ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(CeltasRadii.card),
                    boxShadow: special
                        ? [
                            BoxShadow(
                              color: CeltasColors.gold.withValues(alpha: 0.35),
                              blurRadius: 46,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (special) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: CeltasColors.gold,
                            borderRadius: BorderRadius.circular(
                              CeltasRadii.pill,
                            ),
                          ),
                          child: Text(
                            '★ PREMIO ESPECIAL',
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: CeltasColors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: CeltasColors.surfaceSelected,
                          shape: BoxShape.circle,
                          border: special
                              ? Border.all(color: CeltasColors.gold, width: 1.5)
                              : null,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 34,
                          color: CeltasColors.gold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: TextSpan(
                          style: textTheme.headlineSmall?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: CeltasColors.cream,
                          ),
                          children: [
                            const TextSpan(text: '¡Lo '),
                            TextSpan(
                              text: 'lograste',
                              style: TextStyle(color: accent),
                            ),
                            const TextSpan(text: '!'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: CeltasColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: CeltasColors.surface,
                          border: Border.all(color: CeltasColors.border),
                          borderRadius: BorderRadius.circular(CeltasRadii.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: CeltasColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tienes 15 días para reclamarla',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CeltasColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          key: const ValueKey('reward-unlock-view'),
                          onTap: widget.onDismiss,
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(
                                CeltasRadii.input,
                              ),
                            ),
                            child: Text(
                              'Ver mis premios',
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: CeltasColors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        key: const ValueKey('reward-unlock-continue'),
                        onTap: () {
                          widget.onDismiss();
                          context.go('/home');
                        },
                        child: Text(
                          'Seguir comprando',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            color: CeltasColors.textMuted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
