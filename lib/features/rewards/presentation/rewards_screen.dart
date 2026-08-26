import 'dart:async';

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

/// Programa de Estrellas (mockup `estrellas-01-progreso.png`).
///
/// `GET /rewards/progress` — progreso hacia el próximo premio, premios
/// disponibles sin usar/sin vencer, y la promoción de estrellas dobles
/// vigente hoy, si hay alguna.
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
/// `NotificationHistoryRepository`), y se muestra UNA vez por premio.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  final _seenStorage = SeenRewardsStorage();
  List<RewardSlot>? _newlyUnlocked;

  /// Compara `premiosDisponibles` contra lo ya visto y, si hay alguno nuevo,
  /// dispara el overlay de celebración una sola vez (marca como visto de
  /// inmediato para no repetirlo en el próximo refresh/apertura). Si el
  /// overlay ya está visible, no vuelve a calcular — evita pisarlo con una
  /// segunda tanda mientras el usuario todavía lo está viendo.
  Future<void> _maybeCelebrate(RewardProgress progress) async {
    if (_newlyUnlocked != null || progress.premiosDisponibles.isEmpty) return;
    final seen = await _seenStorage.load();
    final unseen = progress.premiosDisponibles
        .where((slot) => !seen.contains(slot.id))
        .toList();
    if (unseen.isEmpty) return;
    await _seenStorage.markSeen(unseen.map((slot) => slot.id));
    if (!mounted) return;
    setState(() => _newlyUnlocked = unseen);
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
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
        ),
        if (_newlyUnlocked != null)
          _RewardUnlockOverlay(
            onDismiss: () => setState(() => _newlyUnlocked = null),
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
                    text: 'Hasta el ${formatLongDateFromYmd(promotion.endDate)} '
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

/// Grilla de estrellas + texto de apoyo. Filled = `estrellasPorPremio -
/// estrellasParaProximoPremio`, salvo `estrellasParaProximoPremio == 0`, que
/// es ambiguo: el backend calcula `estrellasDelMes % estrellasPorPremio`, y
/// ese resto da `0` tanto si el cliente recién cruzó un múltiplo exacto
/// (premio nuevo esperando) como si todavía no tiene ninguna estrella este
/// mes (`estrellasDelMes == 0`, ej. un usuario que nunca hizo un pedido). La
/// única señal del lado del cliente para distinguirlos es
/// `premiosDisponibles`: si hay un premio sin usar/sin vencer, es porque
/// realmente se cruzó un múltiplo hace poco.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final RewardProgress progress;

  @override
  Widget build(BuildContext context) {
    final remaining = progress.estrellasParaProximoPremio;
    final total = progress.estrellasPorPremio;
    final hasUnclaimedReward = progress.premiosDisponibles.isNotEmpty;
    final justUnlocked = remaining == 0 && hasUnclaimedReward;
    final filled = justUnlocked ? total : (remaining == 0 ? 0 : total - remaining);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CeltasColors.card,
        border: Border.all(color: CeltasColors.cardBorder),
        borderRadius: BorderRadius.circular(CeltasRadii.card),
      ),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (var i = 0; i < total; i++)
                _StarDot(filled: i < filled, pop: i == filled - 1),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$filled de $total estrellas',
            style: textTheme.titleSmall?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: CeltasColors.cream,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            remaining == 0
                ? (justUnlocked
                    ? '¡Ya puedes desbloquear tu próximo premio!'
                    : 'Empieza a comprar para ganar tu primera estrella')
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

class _RewardSlotCard extends StatelessWidget {
  const _RewardSlotCard({required this.slot});

  final RewardSlot slot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: ValueKey('reward-slot-${slot.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CeltasColors.surfaceSelected,
        border: Border.all(color: CeltasColors.gold),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
      ),
      child: Row(
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
                  'Premio disponible',
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
            onTap: () => context.push('/rewards/redeem/${slot.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: CeltasColors.orange,
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

/// Overlay de celebración (mockup `estrellas-02-desbloqueo.png`): confeti de
/// un solo disparo (2-3s, sin loop) + tarjeta anclada abajo. A diferencia del
/// mockup (que animaba en loop solo para la demo estática), acá el confeti
/// se dispara una única vez al montarse.
class _RewardUnlockOverlay extends StatefulWidget {
  const _RewardUnlockOverlay({required this.onDismiss});

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
                colors: const [
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
                  key: const ValueKey('reward-unlock-card'),
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: CeltasColors.card,
                    border: Border.all(color: CeltasColors.cardBorder),
                    borderRadius: BorderRadius.circular(CeltasRadii.card),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: CeltasColors.surfaceSelected,
                          shape: BoxShape.circle,
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
                          children: const [
                            TextSpan(text: '¡Lo '),
                            TextSpan(
                              text: 'lograste',
                              style: TextStyle(color: CeltasColors.orange),
                            ),
                            TextSpan(text: '!'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ya puedes canjear tu premio.',
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
                          borderRadius: BorderRadius.circular(
                            CeltasRadii.pill,
                          ),
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
                              color: CeltasColors.orange,
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
