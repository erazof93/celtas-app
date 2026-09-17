import 'dart:async';
import 'dart:math';

import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/rewards/application/reward_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_progress.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_redemption_estado.dart';
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
          body: Stack(
            children: [
              const Positioned.fill(child: _AmbientBackground()),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 14, 24, 4),
                      child: _RewardsHeader(),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: CeltasColors.gold,
                        backgroundColor: CeltasColors.surface,
                        onRefresh: () async {
                          ref.invalidate(rewardProgressProvider);
                          try {
                            await ref.read(rewardProgressProvider.future);
                          } catch (_) {
                            // El estado de error ya se muestra en el
                            // `.when` de abajo.
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
                            padding: const EdgeInsets.fromLTRB(
                              24,
                              10,
                              24,
                              24,
                            ),
                            children: [
                              if (progress.promocionActiva
                                  case final promo?) ...[
                                _PromotionBanner(promotion: promo),
                                const SizedBox(height: 16),
                              ],
                              _ProgressCard(progress: progress),
                              if (progress
                                  .premiosDisponibles
                                  .isNotEmpty) ...[
                                const SizedBox(height: 16),
                                for (final slot
                                    in progress.premiosDisponibles) ...[
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 12.5,
                                              color: CeltasColors.textMuted,
                                              decoration:
                                                  TextDecoration.underline,
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
            ],
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

/// Capa decorativa detrás de todo el contenido (fondo + arcos dorados en
/// las esquinas + un par de resplandores radiales muy tenues) — `IgnorePointer`
/// para que nunca intercepte el scroll/tap del contenido real que va encima.
/// Ningún dato: es 100% estética, replica el "charcoal con iluminación
/// dorada ambiental" del mockup de referencia
/// (`design-reference/estrellas/screenshot.png`) sin depender de imágenes ni
/// de un `ImageFilter.blur` (costoso) — los círculos mayormente fuera de
/// pantalla, con solo un borde dorado fino y relleno transparente, dejan ver
/// apenas el arco que les toca dentro del viewport.
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CeltasColors.black, CeltasColors.card],
          ),
        ),
        child: Stack(
          children: [
            // Arco dorado fino, esquina superior izquierda.
            Positioned(
              top: -170,
              left: -170,
              child: _cornerArc(),
            ),
            // Arco dorado fino, esquina inferior derecha.
            Positioned(
              bottom: -170,
              right: -170,
              child: _cornerArc(),
            ),
            // Resplandor ambiental muy tenue detrás de la tarjeta principal
            // (zona superior), NO un fondo amarillo — alpha bajo a propósito.
            Positioned(
              top: 140,
              right: -80,
              child: _glowBlob(220),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerArc() => Container(
    width: 340,
    height: 340,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: CeltasColors.gold.withValues(alpha: 0.22),
        width: 1.2,
      ),
    ),
  );

  Widget _glowBlob(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          CeltasColors.gold.withValues(alpha: 0.07),
          CeltasColors.gold.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _RewardsHeader extends StatelessWidget {
  const _RewardsHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: CeltasColors.textLabel,
                  ),
                  const SizedBox(width: 6),
                  // `Flexible` + una sola línea con ellipsis: en un
                  // viewport angosto, con la columna decorativa de la
                  // derecha compitiendo por espacio, este label NUNCA debe
                  // forzar un `RenderFlex overflowed` — se trunca antes que
                  // desbordar.
                  Flexible(
                    child: Text(
                      'PROGRAMA DE LEALTAD',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: CeltasColors.textLabel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Mis Estrellas',
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: CeltasColors.cream,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cada compra te acerca a más beneficios',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: CeltasColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        // Decoración del header ("¡Gracias por ser parte!" del mockup) — solo
        // estilo (itálica + tracking + dorado), sin traer una fuente
        // caligráfica nueva vía Google Fonts solo para este detalle (evita
        // una dependencia/descarga de red innecesaria para un elemento
        // puramente decorativo, sin datos). Ancho acotado (96px) A
        // PROPÓSITO: sin este límite, en un viewport angosto esta columna
        // (de tamaño natural, sin `Expanded`) le quitaba demasiado espacio
        // al lado izquierdo y el label "PROGRAMA DE LEALTAD" desbordaba
        // (`RenderFlex overflowed`, hallado con un viewport real de
        // teléfono en el widget test).
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 10),
          child: SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¡Gracias\npor ser parte!',
                  textAlign: TextAlign.right,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: CeltasColors.textLabel,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                const Icon(
                  Icons.favorite_border_rounded,
                  size: 13,
                  color: CeltasColors.textLabel,
                ),
              ],
            ),
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
        border: Border.all(color: CeltasColors.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_rounded, size: 20, color: CeltasColors.gold),
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
                      color: CeltasColors.gold,
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
        decoration: _cardDecoration,
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
      decoration: _cardDecoration,
      child: Column(
        children: [
          // El grid ya NO tiene su propio `Container` con degradado —
          // quinta iteración: un solo contenedor (`_cardDecoration`) para
          // todo el tablero (grid + separador + progreso), en vez de una
          // caja anidada que antes duplicaba el fondo dorado tenue.
          for (var row = 0; row < rows; row++) ...[
            // 4px (no 7px): las celdas de hito ya no cargan tag+tallo
            // encima del ícono, así que son ~20px más bajas y no
            // necesitan tanto aire entre filas.
            if (row > 0) const SizedBox(height: 4),
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
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _StarsProgressRing(
                current: progress.estrellasDelMes,
                total: totalStars,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eyebrow dorado ("ESTRELLA ACTUAL" del mockup) — copy
                    // genérico, sin inventar un "nombre" de hito: el
                    // contrato real (`RewardMilestoneProgress`) no expone
                    // ningún campo de nombre/etiqueta por hito, así que el
                    // dato real que le sigue abajo es el conteo real.
                    Text(
                      'TU PROGRESO',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: CeltasColors.textLabel,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                          : 'Te faltan $remaining '
                                'estrella${remaining == 1 ? '' : 's'} para '
                                'desbloquear tu próximo premio',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: CeltasColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Decoración compartida de la tarjeta del tablero: gradiente diagonal
/// (dorado casi imperceptible arriba-izquierda @5% → negro abajo-derecha)
/// + borde dorado oscuro + resplandor ambiental muy leve, en vez del borde
/// casi invisible (`cardBorder`, apenas más claro que el fondo) que tenía
/// antes — mismo lenguaje "premium oscuro + acento dorado" del mockup de
/// referencia (`design-reference/estrellas/screenshot.png`), sin tocar el
/// resto del tema global. `textLabel` (dorado apagado, no `gold` puro) es
/// el que más se acerca al `#8B7355` del mockup una vez mezclado con el
/// fondo oscuro.
///
/// Sexta iteración (comparado en dispositivo real contra `design-reference/
/// estrellas/screenshot.png`): incluso a 0.02 de alpha, el degradado se veía
/// muy dorado en pantalla — con varios medallones de hito alcanzados (cada
/// uno con su propio glow radial de ~60px) sumados al degradado de fondo, el
/// tinte se percibía mucho más fuerte que en un preview aislado. Se
/// reemplaza el degradado por un relleno sólido `CeltasColors.black` — el
/// fondo del mockup de referencia es prácticamente negro puro, el dorado
/// vive SOLO en el borde y en los acentos (estrellas, medallones), nunca en
/// el relleno de la tarjeta.
final BoxDecoration _cardDecoration = BoxDecoration(
  color: CeltasColors.black,
  border: Border.all(color: CeltasColors.textLabel.withValues(alpha: 0.6)),
  borderRadius: BorderRadius.circular(CeltasRadii.banner),
  boxShadow: [
    BoxShadow(
      color: CeltasColors.gold.withValues(alpha: 0.08),
      blurRadius: 24,
      spreadRadius: 1,
    ),
  ],
);

/// Anillo de progreso "N/Total" (equivalente dinámico del círculo "1/15" del
/// mockup) — `total` es SIEMPRE `hitos.map((h) => h.estrellasRequeridas).
/// reduce(max)` calculado por `_ProgressCardState.build`, nunca un valor
/// fijo: el admin puede configurar cualquier cantidad de hitos con
/// cualquier umbral. `current` grande y blanco, `/total` chico y gris
/// (mismo contraste tipográfico del mockup) — envuelto en `FittedBox` para
/// que nunca desborde el círculo sin importar cuántos dígitos tenga
/// (`current`/`total` son dinámicos, un admin puede configurar hitos de
/// 3 dígitos).
class _StarsProgressRing extends StatelessWidget {
  const _StarsProgressRing({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 5,
              color: CeltasColors.border,
            ),
          ),
          SizedBox(
            width: 68,
            height: 68,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 5,
              color: CeltasColors.gold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$current',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: CeltasColors.cream,
                      ),
                    ),
                    TextSpan(
                      text: '/$total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CeltasColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila de hasta 5 estrellas (`startStar`..`endStar` inclusive), todas
/// centradas verticalmente entre sí — pedido explícito tras verse en
/// dispositivo real: con alineación por abajo (`flex-end`), las celdas de
/// hito alcanzado/especial (más altas, 68-78px, para darle espacio a la
/// etiqueta superpuesta) quedaban visualmente más arriba que las estrellas
/// sueltas (48-54px) de la misma fila en vez de parejas.
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

  /// Columnas fijas por fila — SIEMPRE 5, aunque la última fila tenga menos
  /// estrellas (ej. 18 hitos → última fila con solo 16-18, 3 estrellas). Sin
  /// esto, un `Row` con menos de 5 `Expanded` reparte el ancho completo
  /// entre esos pocos hijos (cada uno 1/N en vez de 1/5), así que la última
  /// fila queda desalineada de las columnas de arriba y su última celda
  /// termina empujada casi contra el borde derecho de la tarjeta — bug real
  /// encontrado con un tablero de 18 hitos en dispositivo real.
  static const _columnsPerRow = 5;

  @override
  Widget build(BuildContext context) {
    final starCount = endStar - startStar + 1;
    return Row(
      // `crossAxisAlignment` por defecto de `Row` ya es `center` — antes
      // esto se pisaba explícitamente con `.end` (ver doc de esta clase).
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
        // Relleno invisible para que una fila incompleta (la última, si el
        // total de hitos no es múltiplo de 5) conserve el mismo ancho de
        // columna que las filas completas de arriba.
        for (var i = starCount; i < _columnsPerRow; i++)
          const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}

/// Una celda del tablero: estrella normal (42px, sin cambios) si `hito` es
/// `null`, o una de las 4 combinaciones (alcanzado × especial) si coincide
/// con un hito. En las 4 combinaciones de hito, la etiqueta (mismo estilo de
/// `_MilestoneTag`) va CENTRADA ENCIMA de la estrella dentro del mismo
/// `Stack` que ya usan el glow y el confetti — sin tallo ni columna
/// separada — así que el ícono se agranda lo necesario para que la etiqueta
/// no quede recortada.
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
      // Cuarta iteración: el medallón vuelve a diferenciar especial
      // (dorado) de normal (naranja) — mismo color que su badge — en vez
      // de ser siempre dorado.
      final starColor = hito.esEspecial ? CeltasColors.gold : CeltasColors.orange;
      final badgeColor = starColor;
      final glowAlpha = hito.esEspecial ? 0.6 : 0.42;
      final label = hito.esEspecial ? 'Especial' : 'Premio $premioNumber';
      return SizedBox(
        width: 78,
        height: 78,
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
                      starColor.withValues(alpha: glowAlpha),
                      starColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            ..._confettiAccents(starColor, confetti),
            AnimatedBuilder(
              animation: trophyScale,
              builder: (context, child) =>
                  Transform.scale(scale: trophyScale.value, child: child),
              // Medallón translúcido (cuarta iteración): el círculo ya NO
              // es un relleno sólido del color del ícono — es el MISMO
              // color pero al 40% de opacidad, con un degradado interno
              // muy suave negro → color y un borde fino de 1px, para que
              // el dorado/naranja quede como acento y no como un disco
              // sólido dominante. El ícono en sí SÍ es del color pleno
              // (con glow), ya no negro sobre el círculo.
              child: Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CeltasColors.black,
                      starColor.withValues(alpha: 0.4),
                    ],
                  ),
                  border: Border.all(color: starColor),
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: 30,
                  color: starColor,
                  shadows: [
                    Shadow(
                      color: starColor.withValues(alpha: glowAlpha),
                      blurRadius: hito.esEspecial ? 20 : 16,
                    ),
                  ],
                ),
              ),
            ),
            // Solo `top`: SIN `left`/`right` — el `Stack` (alignment:
            // center) centra el badge horizontalmente usando su ancho
            // NATURAL, sin apretarlo al ancho de esta celda (ver doc de
            // `_MilestoneTag`).
            Positioned(
              top: 0,
              child: _MilestoneTag(
                label: label,
                background: badgeColor,
                glow: true,
                border: hito.esEspecial ? null : CeltasColors.orange,
                showStarIcon: hito.esEspecial,
              ),
            ),
          ],
        ),
      );
    }

    if (hito.esEspecial) {
      return SizedBox(
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
            // Anillo dorado (contorno, sin relleno) para el hito especial
            // pendiente — mismo lenguaje de "medallón" que el trofeo
            // alcanzado, pero vacío por dentro para marcar que todavía no
            // se desbloqueó.
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CeltasColors.surface,
                border: Border.all(
                  color: CeltasColors.gold.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.star_outline_rounded,
                size: 26,
                color: CeltasColors.gold,
              ),
            ),
            const Positioned(
              top: 0,
              child: _MilestoneTag(
                label: 'Especial',
                background: CeltasColors.gold,
                glow: true,
                showStarIcon: true,
              ),
            ),
          ],
        ),
      );
    }

    // No alcanzado + normal: la estrella mantiene el mismo tamaño que una
    // celda normal sin relleno (sin trofeo ni glow) — solo se agranda el
    // Stack que la envuelve para darle espacio a la etiqueta apagada
    // superpuesta arriba.
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          const _StarDot(filled: false, pop: false),
          Positioned(
            top: 0,
            child: _MilestoneTag(
              label: 'Premio $premioNumber',
              background: CeltasColors.borderStrong,
              textColor: CeltasColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta "Premio N" / "Especial" arriba de una celda de hito. El
/// `Positioned` que la contiene ya NO fija `left`/`right` (ver el comentario
/// en cada `_MilestoneCell._content`) — solo `top`, así que el ancho de esta
/// etiqueta queda sin restricción y el `Stack` padre la centra horizontal
/// con su propio `alignment: Alignment.center` usando el ancho NATURAL del
/// pill. Fijar `left: 0, right: 0` (como antes) apretaba el pill al ancho de
/// la celda de la estrella (54-78px), demasiado angosto para "Premio 1" a
/// `fontSize: 10` — el texto se partía en 2 líneas en vez de mantenerse en
/// una sola.
class _MilestoneTag extends StatelessWidget {
  const _MilestoneTag({
    required this.label,
    required this.background,
    this.textColor = CeltasColors.black,
    this.glow = false,
    this.showStarIcon = false,
    this.border,
  });

  final String label;
  final Color background;
  final Color textColor;
  final bool glow;

  /// `true` para el hito especial: dibuja un `Icon(Icons.star_rounded)`
  /// real en vez de depender del carácter "★" dentro de `label` — ese
  /// glyph no está garantizado en el subset que trae `Manrope` vía Google
  /// Fonts y podía renderizar como un cuadro vacío en vez de una estrella.
  final bool showStarIcon;

  /// Borde muy fino opcional — usado por el badge "Premio N" (fondo oscuro
  /// translúcido) para darle un contorno sutil sin necesitar el glow
  /// dorado, que queda reservado para el badge "Especial".
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CeltasRadii.pill),
        border: border == null ? null : Border.all(color: border!),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showStarIcon) ...[
            Icon(Icons.star_rounded, size: 11, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
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
    // Fondo circular (48×48, mismo tamaño de celda que el mockup de
    // referencia) para que una estrella desbloqueada (relleno DORADO, no
    // naranja — mismo acento que el resto del tablero) se distinga de una
    // bloqueada (solo contorno gris tenue) de un vistazo, en vez de un
    // ícono suelto sin ningún fondo.
    final dot = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? CeltasColors.surfaceSelected : CeltasColors.surface,
        border: Border.all(
          color: filled
              ? CeltasColors.gold.withValues(alpha: 0.6)
              : CeltasColors.border,
        ),
      ),
      child: Icon(
        filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 24,
        color: filled ? CeltasColors.gold : CeltasColors.textSubtle,
      ),
    );
    if (!pop) return dot;
    // Animación de "pop" sutil de un solo disparo (no periódica) para la
    // última estrella rellenada — se ejecuta una vez al montarse el widget.
    return TweenAnimationBuilder<double>(
      key: const ValueKey('reward-star-pop'),
      tween: Tween(begin: 0.35, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: dot,
    );
  }
}

/// Decoración de [_RewardSlotCard] (fila "premio disponible").
///
/// Sexta iteración — mismo motivo que `_cardDecoration`: en dispositivo real
/// el degradado negro→dorado se leía como un tinte amarillento incluso a
/// alpha bajo, así que se reemplaza por relleno sólido `CeltasColors.black`
/// + borde de color, igual que el mockup de referencia
/// (`design-reference/estrellas/screenshot.png`).
///
/// Séptima iteración: el borde ya NO es siempre dorado — el dorado queda
/// reservado para el premio ESPECIAL (mismo criterio de color que el resto
/// del tablero: `CeltasColors.gold` = especial, `CeltasColors.orange` =
/// normal). Un premio normal con borde dorado se leía como si fuera
/// especial sin serlo.
BoxDecoration _slotCardDecoration({required bool especial}) => BoxDecoration(
  color: CeltasColors.black,
  border: Border.all(
    color: especial ? CeltasColors.gold : CeltasColors.orange,
  ),
  borderRadius: BorderRadius.circular(CeltasRadii.card),
);

/// Ícono circular izquierdo de [_RewardSlotCard] — mismo color que el borde
/// de la fila (`_slotCardDecoration`): naranja para un premio normal,
/// dorado solo para el especial.
Widget _slotCardIcon({required bool especial}) {
  final color = especial ? CeltasColors.gold : CeltasColors.orange;
  return Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: CeltasColors.surfaceSelected,
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.card_giftcard_rounded, size: 28, color: color),
  );
}

/// Matriz de saturación 0 (blanco y negro por luminancia — pesos estándar
/// Rec. 709) para [_RewardSlotCard] cuando `slot.estado == redeemed` —
/// "desaturar" un premio ya reclamado en vez de solo atenuar su opacidad,
/// para que se lea inequívocamente como "ya no accionable" incluso a
/// primer vistazo (naranja/dorado son justo los colores que distinguen un
/// premio accionable en el resto de la pantalla).
const List<double> _greyscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

/// Fila horizontal, "Más estrellas, más premios" (mockup) — un premio
/// ganado, en el mismo lenguaje visual elegante/discreto que el resto del
/// tablero. Toda la fila es el área táctil.
///
/// Octava iteración — el premio YA NO desaparece al canjearse
/// (`GET /rewards/progress` lo sigue devolviendo con `estado: redeemed`
/// hasta que vence): `onTap` bifurca según `slot.estado` — si está
/// `pending`, navega al canje real (`/rewards/redeem/:id[?especial=true]`,
/// sin cambios); si ya está `redeemed`, muestra un diálogo informativo en
/// vez de reabrir el canje (ya no hay nada que canjear).
class _RewardSlotCard extends StatelessWidget {
  const _RewardSlotCard({required this.slot});

  final RewardSlot slot;

  Future<void> _showClaimedDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('reward-claimed-dialog'),
        backgroundColor: CeltasColors.card,
        title: const Text('Premio reclamado'),
        content: Text(
          'Ya reclamaste este premio el ${formatLongDate(slot.usedAt!)}.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final special = slot.esEspecial;
    final claimed = slot.estado == RewardRedemptionEstado.redeemed;

    final card = Container(
      key: ValueKey('reward-slot-${slot.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _slotCardDecoration(especial: special),
      child: Row(
        children: [
          _slotCardIcon(especial: special),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        special
                            ? 'Premio especial disponible'
                            : 'Premio disponible',
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CeltasColors.cream,
                        ),
                      ),
                    ),
                    if (special) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CeltasColors.gold,
                          borderRadius: BorderRadius.circular(
                            CeltasRadii.pill,
                          ),
                        ),
                        child: Text(
                          '★ ESPECIAL',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: CeltasColors.black,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                    if (claimed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CeltasColors.surfaceSelected,
                          border: Border.all(color: CeltasColors.textSubtle),
                          borderRadius: BorderRadius.circular(
                            CeltasRadii.pill,
                          ),
                        ),
                        child: Text(
                          '✓ Reclamado',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: CeltasColors.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  claimed
                      ? 'Reclamado el ${formatLongDate(slot.usedAt!)}'
                      : formatDaysRemaining(slot.expiresAt),
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: claimed
                        ? CeltasColors.textMuted
                        : CeltasColors.redLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: CeltasColors.gold,
          ),
        ],
      ),
    );

    return GestureDetector(
      key: ValueKey('reward-redeem-${slot.id}'),
      onTap: claimed
          ? () => _showClaimedDialog(context)
          : () => context.push(
              '/rewards/redeem/${slot.id}${special ? '?especial=true' : ''}',
            ),
      child: claimed
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
              child: card,
            )
          : card,
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
            style: TextButton.styleFrom(foregroundColor: CeltasColors.gold),
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
    // Dorado en ambas variantes (antes el overlay normal usaba naranja) —
    // el naranja quedó fuera de la paleta de todo el módulo de estrellas en
    // esta segunda iteración; lo que sigue diferenciando "normal" de
    // "especial" es el pill "★ PREMIO ESPECIAL" + el borde/glow más fuerte
    // de la tarjeta, no el color del acento.
    const accent = CeltasColors.gold;
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
                colors: const [CeltasColors.gold, CeltasColors.cream],
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
                            const TextSpan(
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
                              'Tienes hasta fin de mes para reclamarlo',
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
