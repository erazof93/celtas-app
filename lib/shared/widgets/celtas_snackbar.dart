import 'package:celtas_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Muestra un SnackBar con el estilo estándar de Celtas (fondo
/// `CeltasColors.surface`, texto crema, `floating`), reemplazando cualquier
/// SnackBar visible en el `ScaffoldMessenger` más cercano.
///
/// Extraído tras encontrar el mismo bloque de "ocultar + mostrar" duplicado
/// en `lib/`: 5 sitios con la cascada literal
/// `ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(...)`
/// (`app_router.dart`, `home_screen.dart` — banner —,
/// `product_detail_screen.dart` ×2, `cart_screen.dart`), más un 6º sitio
/// funcionalmente idéntico en `home_screen.dart` (botón "+" rápido) que
/// llamaba a `hideCurrentSnackBar()`/`showSnackBar()` como dos sentencias
/// separadas en vez de la cascada — mismo bloque, forma distinta, por eso no
/// apareció al buscar solo la cascada literal.
///
/// `margin` queda en `null` por default porque solo 2 de los 6 sitios
/// originales pasaban un margen explícito (los dos "Agregado al carrito",
/// para no quedar tapados por `_CartSummaryBar`/`CeltasBottomNav`); el resto
/// dejaba que `SnackBar` calculara el suyo, y lo perdería si el default acá
/// fuera un `EdgeInsets` fijo.
void showCeltasSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = CeltasColors.surface,
  Duration duration = const Duration(seconds: 2),
  EdgeInsets? margin,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: CeltasColors.cream),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: margin,
      ),
    );
}
