import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:celtas_mobile/features/orders/data/models/order_status.dart';
import 'package:celtas_mobile/features/orders/presentation/widgets/order_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paleta de statusColor — separación cromática entre los 5 estados', () {
    test('cada estado tiene un accentColor distinto de los otros 4', () {
      final colors = OrderStatus.values.map((s) => s.accentColor).toList();
      expect(colors.toSet(), hasLength(OrderStatus.values.length));
    });

    test('cancelado es el único estado que usa CeltasColors.redLight', () {
      for (final status in OrderStatus.values) {
        if (status == OrderStatus.cancelado) {
          expect(status.accentColor, CeltasColors.redLight);
        } else {
          expect(status.accentColor, isNot(CeltasColors.redLight));
        }
      }
    });

    test(
        'confirmado y en_camino ya no comparten color (bug del mockup '
        'original: mismo naranja, distinguibles solo por relleno/contorno)',
        () {
      expect(
        OrderStatus.confirmado.accentColor,
        isNot(OrderStatus.enCamino.accentColor),
      );
    });

    test('en_camino usa el color fuera de la paleta cálida documentado', () {
      expect(OrderStatus.enCamino.accentColor, CeltasColors.statusEnCamino);
    });
  });

  testWidgets('cada badge renderiza su label en mayúsculas', (tester) async {
    for (final status in OrderStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: OrderStatusBadge(status: status)),
        ),
      );

      expect(find.text(status.label.toUpperCase()), findsOneWidget);
    }
  });
}
