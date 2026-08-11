import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder del checkout — se completa en el módulo 5.
///
/// El flujo real: selector de dirección, resumen con descuento, `POST /orders`
/// con `items` + `addressId`/`addressSnapshot` + `couponCode` opcional, y al
/// recibir la respuesta se abre el `whatsappUrl` con `url_launcher`. Nunca hay
/// pago dentro de la app.
class CheckoutPlaceholderScreen extends StatelessWidget {
  const CheckoutPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CeltasSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Checkout',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'El checkout llega en el módulo 5: dirección de entrega, '
                'resumen con descuento y confirmación por WhatsApp.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CeltasColors.textMuted,
                    ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  foregroundColor: CeltasColors.orange,
                ),
                child: const Text('VOLVER AL CARRITO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}