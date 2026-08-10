import 'package:celtas_mobile/features/home/data/models/banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Banner.fromJson', () {
    test('parsea el payload real de GET /banners/active', () {
      final json = {
        'id': '114473b7-0566-407d-af02-7e6f20be5351',
        'title': 'aprovecha la 2x1',
        'imageUrl':
            'https://res.cloudinary.com/qtptnqb4/image/upload/v1786309068/'
            'celtas/banners/jikvocw9wmymtdtm662t.webp',
        'actionType': 'none',
        'actionValue': null,
        'startDate': '2026-08-09T05:00:00.000Z',
        'endDate': '2026-08-12T04:59:59.999Z',
        'active': true,
        'order': 0,
        'createdAt': '2026-08-09T20:57:46.633Z',
        'updatedAt': '2026-08-09T20:57:48.872Z',
      };

      final banner = Banner.fromJson(json);

      expect(banner.id, '114473b7-0566-407d-af02-7e6f20be5351');
      expect(banner.title, 'aprovecha la 2x1');
      expect(banner.imageUrl, contains('res.cloudinary.com'));
      expect(banner.actionType, BannerActionType.none);
      expect(banner.actionValue, isNull);
      expect(banner.startDate, DateTime.utc(2026, 8, 9, 5));
      expect(banner.endDate, DateTime.utc(2026, 8, 12, 4, 59, 59, 999));
      expect(banner.active, isTrue);
      expect(banner.order, 0);
    });

    test('actionType se mapea a los 4 valores del enum', () {
      for (final (raw, expected) in [
        ('none', BannerActionType.none),
        ('category', BannerActionType.category),
        ('menuItem', BannerActionType.menuItem),
        ('external_url', BannerActionType.externalUrl),
      ]) {
        final banner = Banner.fromJson({
          'id': 'b-1',
          'title': 't',
          'actionType': raw,
          'active': true,
          'order': 0,
          'createdAt': '2026-08-09T20:57:46.633Z',
          'updatedAt': '2026-08-09T20:57:48.872Z',
        });
        expect(banner.actionType, expected, reason: 'raw=$raw');
      }
    });

    test('campos opcionales null → null (banner sin imagen ni fechas)', () {
      final banner = Banner.fromJson({
        'id': 'b-2',
        'title': 'solo texto',
        'actionType': 'none',
        'active': true,
        'order': 1,
        'createdAt': '2026-08-09T20:57:46.633Z',
        'updatedAt': '2026-08-09T20:57:48.872Z',
      });

      expect(banner.imageUrl, isNull);
      expect(banner.startDate, isNull);
      expect(banner.endDate, isNull);
      expect(banner.actionValue, isNull);
    });
  });
}