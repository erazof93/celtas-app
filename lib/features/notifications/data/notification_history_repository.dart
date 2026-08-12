import 'dart:convert';

import 'package:celtas_mobile/features/notifications/data/models/notification_history_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Historial local de notificaciones push recibidas.
///
/// Persistido con `shared_preferences` (no `flutter_secure_storage`: no es
/// dato sensible como el `refreshToken`, así que no aplica esa restricción
/// ya documentada en la skill del proyecto). Guarda el más reciente primero
/// y recorta a [maxItems] para no crecer sin límite.
class NotificationHistoryRepository {
  static const _key = 'notification_history';

  /// Público: `NotificationHistoryNotifier.add()` también lo usa para
  /// recortar la lista en memoria, no solo lo persistido acá.
  static const maxItems = 30;

  Future<List<NotificationHistoryItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map(
          (encoded) => NotificationHistoryItem.fromJson(
            jsonDecode(encoded) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> save(List<NotificationHistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final capped = items.take(maxItems).toList();
    await prefs.setStringList(_key, [
      for (final item in capped) jsonEncode(item.toJson()),
    ]);
  }
}
