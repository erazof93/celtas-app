import 'package:celtas_mobile/features/rewards/data/models/reward_catalog_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato verificado contra `RewardsService.getCatalog`
/// (`backend-celtas/src/modules/rewards/rewards.service.ts`): `id` acá es el
/// `MenuItem.id` real, no un id de premio.
void main() {
  test('fromJson parsea el contrato real con description/image presentes', () {
    final json = {
      'id': 'i-1',
      'name': 'Berserker Burger',
      'description': 'Doble carne, cheddar, bacon',
      'price': 15.5,
      'image': 'https://res.cloudinary.com/celtas/burger.jpg',
    };

    final item = RewardCatalogItem.fromJson(json);

    expect(item.id, 'i-1');
    expect(item.name, 'Berserker Burger');
    expect(item.description, 'Doble carne, cheddar, bacon');
    expect(item.price, 15.5);
    expect(item.image, 'https://res.cloudinary.com/celtas/burger.jpg');
  });

  test('description/image null no crashea el parseo', () {
    final json = {
      'id': 'i-2',
      'name': "Odin's Wings x8",
      'description': null,
      'price': 7.2,
      'image': null,
    };

    final item = RewardCatalogItem.fromJson(json);

    expect(item.description, isNull);
    expect(item.image, isNull);
  });
}
