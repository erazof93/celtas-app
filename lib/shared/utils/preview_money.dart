/// Aritmética de centavos para previews. El backend recalcula el pedido y
/// sigue siendo la autoridad de los importes finales.
abstract final class PreviewMoney {
  // Number.EPSILON del helper money.util.ts del backend.
  static const _epsilon = 2.220446049250313e-16;

  /// Importes no negativos: midpoint hacia arriba, como en el backend.
  static int toCents(double value) =>
      ((value + _epsilon * value) * 100).round();

  static double fromCents(int cents) => cents / 100;

  static double normalize(double value) => fromCents(toCents(value));

  /// Redondea el descuento una vez y lo limita al subtotal en centavos.
  static int discountCents(
    int subtotalCents,
    double value, {
    required bool percentage,
  }) {
    final raw = percentage
        ? (subtotalCents * (value.clamp(0, 100) * 100).round() / 10000)
              .round()
        : toCents(value);
    return raw.clamp(0, subtotalCents);
  }
}
