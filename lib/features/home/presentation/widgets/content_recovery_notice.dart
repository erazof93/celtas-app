import 'package:celtas_mobile/core/network/api_client.dart';
import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// One recoverable notice for the content shown by Home or product detail.
class ContentRecoveryNotice extends StatelessWidget {
  const ContentRecoveryNotice({
    super.key,
    this.error,
    required this.hasPreviousData,
    required this.onRetry,
  });

  final Object? error;
  final bool hasPreviousData;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final kind = error is ApiException
        ? (error! as ApiException).kind
        : ApiErrorKind.other;
    final (title, description) = error == null
        ? ('Actualizando contenido', 'Consultando los datos más recientes…')
        : switch (kind) {
            ApiErrorKind.connection => (
              'No pudimos conectar',
              'Revisa tu conexión e inténtalo nuevamente',
            ),
            ApiErrorKind.timeout => (
              'La consulta está tardando demasiado',
              'Inténtalo de nuevo en un momento',
            ),
            ApiErrorKind.server => (
              'Servicio temporalmente no disponible',
              'Puedes explorar el contenido disponible e intentar nuevamente',
            ),
            ApiErrorKind.other => (
              'No pudimos actualizar el contenido',
              'Inténtalo nuevamente',
            ),
          };
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        borderRadius: BorderRadius.circular(CeltasRadii.input),
        border: Border.all(color: CeltasColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.titleSmall?.copyWith(color: CeltasColors.gold),
          ),
          const SizedBox(height: 4),
          Text(description, style: theme.bodySmall),
          if (hasPreviousData) ...[
            const SizedBox(height: 4),
            Text(
              'Contenido de la última consulta. Los precios y la disponibilidad pueden haber cambiado.',
              style: theme.bodySmall?.copyWith(color: CeltasColors.textMuted),
            ),
          ],
          if (error != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: CeltasColors.orange),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}
