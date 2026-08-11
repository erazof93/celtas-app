import 'package:celtas_mobile/features/coupons/data/models/coupon_status.dart';
import 'package:celtas_mobile/features/coupons/data/models/user_coupon.dart';
import 'package:celtas_mobile/features/coupons/data/models/validated_coupon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserCoupon buildCoupon({
    CouponStatus status = CouponStatus.active,
    required DateTime expiresAt,
  }) =>
      UserCoupon(
        id: 'c-1',
        code: 'VIKINGO10',
        discountType: CouponDiscountType.percentage,
        discountValue: 10,
        status: status,
        expiresAt: expiresAt,
      );

  test('fromJson parsea el contrato real del backend', () {
    final json = {
      'id': 'c-1',
      'code': 'VIKINGO10',
      'discountType': 'percentage',
      'discountValue': 10.0,
      'status': 'active',
      'expiresAt': '2026-12-31T00:00:00.000Z',
      'usedAt': null,
    };

    final coupon = UserCoupon.fromJson(json);

    expect(coupon.discountType, CouponDiscountType.percentage);
    expect(coupon.status, CouponStatus.active);
    expect(coupon.usedAt, isNull);
  });

  test('effectiveStatus: active con expiresAt futuro sigue active', () {
    final coupon = buildCoupon(
      expiresAt: DateTime.now().add(const Duration(days: 5)),
    );

    expect(coupon.effectiveStatus, CouponStatus.active);
  });

  test(
      'effectiveStatus: active con expiresAt pasado se muestra como expired '
      '(el backend solo actualiza status con un cron diario, puede seguir '
      "'active' hasta 24h después de vencer)", () {
    final coupon = buildCoupon(
      expiresAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    expect(coupon.effectiveStatus, CouponStatus.expired);
  });

  test('effectiveStatus: used se respeta aunque expiresAt ya haya pasado '
      '(un cupón usado no debería "revertirse" a expirado)', () {
    final coupon = buildCoupon(
      status: CouponStatus.used,
      expiresAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    expect(coupon.effectiveStatus, CouponStatus.used);
  });

  test('effectiveStatus: expired explícito se respeta', () {
    final coupon = buildCoupon(
      status: CouponStatus.expired,
      expiresAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(coupon.effectiveStatus, CouponStatus.expired);
  });
}
