import 'dart:async';

import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Aviso para estados de carga que dependen de una request a la API.
///
/// Render pone a dormir el backend free tier tras inactividad: la primera
/// request tras un rato puede tardar 30-50s. Este widget aparece a los 5
/// segundos de estar montado para explicar que el servidor está despertando,
/// en vez de dejar un spinner indefinido sin contexto.
class SlowBackendNotice extends StatefulWidget {
  const SlowBackendNotice({super.key});

  @override
  State<SlowBackendNotice> createState() => _SlowBackendNoticeState();
}

class _SlowBackendNoticeState extends State<SlowBackendNotice> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CeltasColors.surface,
        borderRadius: BorderRadius.circular(CeltasRadii.input),
        border: Border.all(color: CeltasColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 16,
            color: CeltasColors.gold,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'El servidor está despertando, puede tardar unos segundos…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CeltasColors.textMuted,
                    fontSize: 12,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}