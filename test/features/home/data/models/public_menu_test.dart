import 'package:celtas_mobile/features/home/data/models/public_menu_category.dart';
import 'package:celtas_mobile/features/home/data/models/public_menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublicMenuItem.fromJson', () {
    test('parsea el payload real de GET /menu', () {
      final json = {
        'id': '42838e20-9fc1-4e87-a4bb-25f6775a9b43',
        'name': 'Celtas Burgues Clasica',
        'description': 'doble carne, queso y jamon',
        'price': 15.5,
        'image':
            'https://res.cloudinary.com/qtptnqb4/image/upload/v1786308976/'
            'celtas/menu-items/osgmvtvkukbpipw08b4w.jpg',
      };

      final item = PublicMenuItem.fromJson(json);

      expect(item.id, '42838e20-9fc1-4e87-a4bb-25f6775a9b43');
      expect(item.name, 'Celtas Burgues Clasica');
      expect(item.description, 'doble carne, queso y jamon');
      expect(item.price, 15.5);
      expect(item.image, contains('res.cloudinary.com'));
    });

    test('description e image opcionales → null', () {
      final item = PublicMenuItem.fromJson({
        'id': 'i-1',
        'name': 'Sin foto',
        'price': 9.9,
      });

      expect(item.description, isNull);
      expect(item.image, isNull);
    });
  });

  group('PublicMenuCategory.fromJson', () {
    test('parsea categoría con items (payload real de GET /menu)', () {
      final json = {
        'id': '20447ec0-5792-49f4-8dc4-334ec5661ce8',
        'name': 'Hamburguesa',
        'description': 'Hamburguesa artesanales',
        'items': [
          {
            'id': '42838e20-9fc1-4e87-a4bb-25f6775a9b43',
            'name': 'Celtas Burgues Clasica',
            'description': 'doble carne, queso y jamon',
            'price': 15.5,
            'image': 'https://res.cloudinary.com/x.jpg',
          },
        ],
      };

      final category = PublicMenuCategory.fromJson(json);

      expect(category.id, '20447ec0-5792-49f4-8dc4-334ec5661ce8');
      expect(category.name, 'Hamburguesa');
      expect(category.description, 'Hamburguesa artesanales');
      expect(category.items, hasLength(1));
      expect(category.items.first.name, 'Celtas Burgues Clasica');
      expect(category.items.first.price, 15.5);
    });

    test('categoría sin items → lista vacía', () {
      final category = PublicMenuCategory.fromJson({
        'id': 'c-1',
        'name': 'Bebidas',
        'items': [],
      });

      expect(category.items, isEmpty);
      expect(category.description, isNull);
    });
  });
}