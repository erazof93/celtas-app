import 'package:celtas_mobile/features/rewards/data/seen_rewards_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('load() sin datos previos devuelve un set vacío', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SeenRewardsStorage();

    expect(await storage.load(), isEmpty);
  });

  test('markSeen() y load() hacen roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SeenRewardsStorage();

    await storage.markSeen(['r-1', 'r-2']);
    final loaded = await storage.load();

    expect(loaded, {'r-1', 'r-2'});
  });

  test('markSeen() sucesivos acumulan en vez de reemplazar', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SeenRewardsStorage();

    await storage.markSeen(['r-1']);
    await storage.markSeen(['r-2']);
    final loaded = await storage.load();

    expect(loaded, {'r-1', 'r-2'});
  });

  test('marcar el mismo id dos veces no lo duplica (es un set)', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SeenRewardsStorage();

    await storage.markSeen(['r-1']);
    await storage.markSeen(['r-1']);
    final loaded = await storage.load();

    expect(loaded, {'r-1'});
  });
}
