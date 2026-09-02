import 'dart:convert';

import 'package:celtas_mobile/features/cart/data/models/cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caché local del carrito en `SharedPreferences` (no es dato sensible —
/// mismo criterio que `SeenRewardsStorage` / `NotificationHistoryRepository`,
/// nunca `flutter_secure_storage`).
///
/// Solo se persisten los ítems NORMALES del menú. NO se guardan:
/// - ítems de premio (`rewardRedemptionId != null`): un `RewardRedemption`
///   es una entidad del backend que puede caducar; rehidratarlo llevaría a
///   un `POST /orders` rechazado.
/// - el cupón validado ni el aviso de cupón: el `ValidatedCoupon` quedaría
///   desactualizado (el backend lo revalida al crear el pedido).
///
/// El filtrado de premios lo hace quien llama (`CartState.toJsonForStorage`),
/// esta clase solo serializa/deserializa lo que recibe.
class CartStorage {
  /// [_prefs] se pasa ya inicializado desde `main()` para que [load] sea
  /// síncrono (lo necesita `CartNotifier.build()`, que no puede ser async).
  /// Si es `null` (default del provider sin override, o algunos tests),
  /// [load] devuelve vacío y [save] resuelve la instancia de forma perezosa.
  CartStorage([this._prefs]);

  static const storageKey = 'cart_v1';

  final SharedPreferences? _prefs;

  /// Lee el carrito guardado. Ante JSON corrupto, forma inesperada o
  /// cualquier error de decodificación devuelve lista vacía — una caché
  /// ilegible nunca debe romper el arranque de la app.
  List<CartItem> load() {
    final prefs = _prefs;
    if (prefs == null) return const [];
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const [];
      final items = decoded['items'];
      if (items is! List) return const [];
      return [
        for (final entry in items)
          if (entry is Map<String, dynamic>) CartItem.fromStorageJson(entry),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Guarda el snapshot ya filtrado (`CartState.toJsonForStorage`). Es
  /// best-effort: se llama fire-and-forget desde el notifier y cualquier
  /// error de escritura se traga a propósito (perder la caché del carrito
  /// no es un fallo que deba propagarse a la UI).
  ///
  /// Vaciar el carrito (`CartNotifier.clear`) pasa por acá con
  /// `{'items': []}` — no hay un `remove` aparte de la clave.
  Future<void> save(Map<String, dynamic> json) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(json));
    } catch (_) {
      // best-effort
    }
  }
}

/// Se sobreescribe en `main()` con `CartStorage(await
/// SharedPreferences.getInstance())` para habilitar la lectura síncrona en
/// `CartNotifier.build()`. El default (sin `SharedPreferences` pre-cargado)
/// deja la caché en modo degradado: no hidrata al abrir, pero sí escribe.
final cartStorageProvider = Provider<CartStorage>((ref) => CartStorage());
