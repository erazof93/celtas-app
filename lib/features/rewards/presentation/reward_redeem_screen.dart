import 'package:cached_network_image/cached_network_image.dart';
import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/cart/application/cart_provider.dart';
import 'package:celtas_mobile/features/rewards/application/reward_providers.dart';
import 'package:celtas_mobile/features/rewards/data/models/reward_catalog_item.dart';
import 'package:celtas_mobile/shared/widgets/celtas_snackbar.dart';
import 'package:celtas_mobile/shared/widgets/slow_backend_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Canje de un premio ya desbloqueado (mockup `estrellas-03-canje.png`).
///
/// Ruta `/rewards/redeem/:redemptionId`, empujada sobre el shell (sin bottom
/// nav, mismo patrón que `/product/:id`). Muestra TODOS los productos reales
/// de `GET /rewards/catalog` — sin tarjetas "Próximamente" ni ningún
/// placeholder (esas del mockup solo comunicaban el concepto de catálogo
/// editable en la maqueta, no van en producción).
class RewardRedeemScreen extends ConsumerWidget {
  const RewardRedeemScreen({super.key, required this.redemptionId});

  final String redemptionId;

  Future<void> _redeem(
    BuildContext context,
    WidgetRef ref,
    RewardCatalogItem item,
  ) async {
    ref
        .read(cartProvider.notifier)
        .addRewardItem(item, rewardRedemptionId: redemptionId);
    showCeltasSnackBar(
      context,
      'Premio agregado: ${item.name}',
      // Mismo margen que `product_detail_screen.dart` para no tapar la
      // barra flotante del carrito.
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    );
    // El SnackBar vive en el ScaffoldMessenger raíz, sigue visible después
    // del pop — mismo patrón que `_addToCart` en `product_detail_screen.dart`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(rewardCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Canjear premio')),
      body: SafeArea(
        top: false,
        child: catalogAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: SlowBackendNotice(),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: _RedeemError(
              message: error is ApiException
                  ? error.message
                  : 'No se pudo cargar el catálogo de premios.',
              onRetry: () => ref.invalidate(rewardCatalogProvider),
            ),
          ),
          data: (items) => items.isEmpty
              ? const _EmptyCatalog()
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _CatalogCard(
                    item: items[index],
                    onTap: () => _redeem(context, ref, items[index]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.item, required this.onTap});

  final RewardCatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      key: ValueKey('reward-catalog-${item.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CeltasColors.card,
          border: Border.all(color: CeltasColors.cardBorder),
          borderRadius: BorderRadius.circular(CeltasRadii.card),
        ),
        child: Row(
          children: [
            _CatalogImage(imageUrl: item.image),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: CeltasColors.cream,
                    ),
                  ),
                  if (item.description case final description?
                      when description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: CeltasColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'S/ ${item.price.toStringAsFixed(2)}',
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: CeltasColors.textSubtle,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CeltasColors.surfaceSelected,
                          border: Border.all(color: CeltasColors.gold),
                          borderRadius: BorderRadius.circular(
                            CeltasRadii.badge,
                          ),
                        ),
                        child: Text(
                          'GRATIS',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: CeltasColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 22,
              color: CeltasColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogImage extends StatelessWidget {
  const _CatalogImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: CeltasColors.surface,
          borderRadius: BorderRadius.circular(CeltasRadii.control),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant,
          size: 20,
          color: CeltasColors.textSubtle,
        ),
      );
    }
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheDimension = (56 * devicePixelRatio).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(CeltasRadii.control),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: 56,
        height: 56,
        memCacheWidth: cacheDimension,
        memCacheHeight: cacheDimension,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 56,
          height: 56,
          color: CeltasColors.surface,
        ),
        errorWidget: (context, url, error) => Container(
          width: 56,
          height: 56,
          color: CeltasColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant,
            size: 20,
            color: CeltasColors.textSubtle,
          ),
        ),
      ),
    );
  }
}

class _RedeemError extends StatelessWidget {
  const _RedeemError({required this.message, required this.onRetry});

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

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CeltasSpacing.page),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.star_border_rounded,
              size: 40,
              color: CeltasColors.textSubtle,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay premios disponibles para canjear por ahora',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CeltasColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
