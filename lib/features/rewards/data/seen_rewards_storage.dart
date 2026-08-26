import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda qué `RewardRedemption.id` ya mostraron la celebración de
/// desbloqueo en `RewardsScreen`, para no repetirla en cada apertura/refresh.
///
/// Persistido con `shared_preferences` (no es dato sensible, mismo criterio
/// que `NotificationHistoryRepository`). No hay push/evento del backend que
/// avise "se generó un premio nuevo" — la app lo detecta comparando
/// `premiosDisponibles` contra lo que ya vio acá.
class SeenRewardsStorage {
  static const _key = 'seen_reward_redemption_ids';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> markSeen(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    await prefs.setStringList(_key, {...current, ...ids}.toList());
  }
}
