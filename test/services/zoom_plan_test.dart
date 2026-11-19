import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/services/camera/zoom_plan.dart';

void main() {
  ZoomPlan plan(
    double level, {
    bool hasUltraWide = true,
    bool onUltraWide = false,
    double maxZoom = 6,
  }) => planZoom(
    level,
    hasUltraWide: hasUltraWide,
    onUltraWide: onUltraWide,
    maxZoom: maxZoom,
  );

  test('từ 1× trở lên dùng ống kính chính với đúng mức đó', () {
    for (final level in [1.0, 2.0, 3.7, 6.0]) {
      final p = plan(level);
      expect(p.ultraWide, isFalse);
      expect(p.lensZoom, level);
      expect(p.zoom, level);
    }
  });

  test('dưới 1× dùng ống kính góc siêu rộng, phóng gấp đôi cho khớp', () {
    final half = plan(0.5);
    expect(half.ultraWide, isTrue);
    expect(half.lensZoom, 1.0);
    expect(half.zoom, 0.5);

    final p = plan(0.7);
    expect(p.ultraWide, isTrue);
    expect(p.lensZoom, moreOrLessEquals(1.4));
    expect(p.zoom, 0.7);
  });

  test('chặn ở hai đầu dải zoom', () {
    expect(plan(0.1).zoom, 0.5);
    expect(plan(20).zoom, 6.0);
    expect(plan(20, maxZoom: 3.5).zoom, 3.5);
  });

  test('quanh 1× có khoảng đệm để không đổi ống kính liên tục', () {
    final staying = plan(0.95);
    expect(staying.ultraWide, isFalse);
    expect(staying.zoom, 1.0);
    expect(plan(0.9).ultraWide, isTrue);

    final wide = plan(0.95, onUltraWide: true);
    expect(wide.ultraWide, isTrue);
    expect(wide.lensZoom, moreOrLessEquals(1.9));
    expect(plan(1.0, onUltraWide: true).ultraWide, isFalse);
  });

  test('máy không có ống kính góc siêu rộng: không xuống dưới 1×', () {
    final p = plan(0.5, hasUltraWide: false);
    expect(p.ultraWide, isFalse);
    expect(p.zoom, 1.0);
    expect(p.lensZoom, 1.0);
  });

  test('camera không zoom được: luôn là 1×', () {
    final p = plan(4, hasUltraWide: false, maxZoom: 1);
    expect(p.zoom, 1.0);
    expect(p.lensZoom, 1.0);
  });
}
