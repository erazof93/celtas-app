import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Banner informativo de "local cerrado", con el mensaje real que ya arma
/// `GET /settings/business-hours` (horario de hoy o motivo del cierre
/// manual) — nunca reconstruido a mano acá.
///
/// Mismo patrón visual de "notice" que el resto de la app (card + ícono +
/// texto, ej. `_MissingAddressNotice` del checkout), en tono `redLight` (no
/// gold) porque a diferencia de "te falta elegir una dirección" esto no es
/// algo que el cliente pueda corregir por su cuenta — mismo tono que usa el
/// resto de la app para estados negativos (ej. `cancelado` en
/// `OrderStatusBadge`).
///
/// Compartido entre el aviso preventivo del checkout (`checkout_screen.dart`)
/// y el cartel del Home (`home_screen.dart`) — mismo bloque visual, cada
/// pantalla decide dónde y cuándo mostrarlo según su propia fuente de
/// [BusinessHours].
class BusinessClosedNotice extends StatelessWidget {
  const BusinessClosedNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CeltasColors.redLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CeltasRadii.input),
        border: Border.all(color: CeltasColors.redLight, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: CeltasColors.redLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CeltasColors.redLight,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
