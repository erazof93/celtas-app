const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// `"6 ago"` — fecha corta sin año, para listados donde el año no aporta
/// (historial de pedidos, siempre reciente).
String formatShortDate(DateTime date) => '${date.day} ${_months[date.month - 1]}';

/// `"31 ago 2026"` — fecha con año, para fechas que pueden estar lejos en el
/// futuro o el pasado (vencimiento/uso de cupones).
String formatLongDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// `"6 ago · 14:32"` — fecha corta + hora, para listados donde el momento
/// exacto importa (historial de notificaciones).
String formatShortDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatShortDate(date)} · $hour:$minute';
}

/// "31 dic 2026" a partir de un string plano `"YYYY-MM-DD"` (NO pasa por
/// `DateTime.parse` + zona horaria) — mismo formato que [formatLongDate],
/// para fechas que ya vienen así del backend (ej. `StarPromotion.endDate`)
/// y no deben correrse de día por huso horario al parsearlas.
String formatLongDateFromYmd(String ymd) {
  final parts = ymd.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  return '$day ${_months[month - 1]} $year';
}

/// "Vence en 12 días" / "Vence hoy" — para la vigencia de 15 días de un
/// premio ganado (`RewardRedemption.expiresAt`). Nunca debería llegar un
/// valor ya vencido (el backend solo devuelve `premiosDisponibles` con
/// `expiresAt > now`), pero si `days` da negativo por reloj desincronizado,
/// cae a "Vence hoy" en vez de mostrar un número negativo.
String formatDaysRemaining(DateTime expiresAt) {
  final days = expiresAt.difference(DateTime.now()).inDays;
  if (days <= 0) return 'Vence hoy';
  return 'Vence en $days día${days == 1 ? '' : 's'}';
}
