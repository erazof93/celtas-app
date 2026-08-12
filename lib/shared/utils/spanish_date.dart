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
