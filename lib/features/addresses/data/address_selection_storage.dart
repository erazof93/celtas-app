import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la "dirección seleccionada actual" del cliente (la que el Home
/// muestra en el header y el checkout pre-selecciona). Es un concepto distinto
/// de `Address.isDefault` (la favorita marcada con ⭐): el tap en una tarjeta
/// solo cambia esta selección, nunca `isDefault`.
///
/// `SharedPreferences` (no `flutter_secure_storage`): un UUID de dirección no
/// es dato sensible — mismo criterio que `CartStorage` /
/// `NotificationHistoryRepository` / `SeenRewardsStorage`.
class AddressSelectionStorage {
  /// [_prefs] se pasa ya inicializado desde `main()` (igual que `CartStorage`)
  /// para que [load] sea síncrono. Sin override (`_prefs == null`): [load]
  /// devuelve `null` y [save]/[clear] resuelven la instancia perezosamente.
  AddressSelectionStorage([this._prefs]);

  static const _key = 'selected_address_id';

  final SharedPreferences? _prefs;

  String? load() => _prefs?.getString(_key);

  Future<void> save(String id) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_key, id);
    } catch (_) {
      // best-effort: perder esta preferencia no debe romper nada.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // best-effort
    }
  }
}

/// Se sobreescribe en `main()` con `AddressSelectionStorage(prefs)` para la
/// lectura síncrona al arrancar. El default deja el modo degradado: no hidrata
/// al abrir, pero sí escribe.
final addressSelectionStorageProvider = Provider<AddressSelectionStorage>(
  (ref) => AddressSelectionStorage(),
);
