import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tach/src/presentation/feed/feed_background.dart';

double _contrastWithWhite(Color color) =>
    1.05 / (color.computeLuminance() + 0.05);

void main() {
  test('nền giữ tông màu của ảnh và chữ trắng vẫn dễ đọc', () {
    for (final photo in const [
      Color(0xFFBE9678),
      Color(0xFF2E6BD6),
      Color(0xFFFFF27A),
      Color(0xFFFFFFFF),
      Color(0xFF101010),
    ]) {
      final tint = photoTint(photo);

      // 4,5:1 là mức tối thiểu cho chữ thường theo WCAG AA.
      expect(_contrastWithWhite(tint.bottom), greaterThan(4.5));
      expect(
        tint.bottom.computeLuminance(),
        greaterThan(tint.top.computeLuminance()),
      );
    }

    const box = Color(0xFFBE9678);
    final brown = HSLColor.fromColor(photoTint(box).bottom);
    expect(brown.hue, closeTo(HSLColor.fromColor(box).hue, 2));
    expect(brown.saturation, greaterThan(0.2));
  });

  test('ảnh sáng cho nền sáng hơn ảnh tối', () {
    final white = photoTint(const Color(0xFFF2F2F2)).bottom;
    final dark = photoTint(const Color(0xFF202020)).bottom;

    expect(
      HSLColor.fromColor(white).lightness,
      greaterThan(HSLColor.fromColor(dark).lightness + 0.12),
    );
  });

  test('ảnh xám thì nền xám, không tự thêm màu', () {
    final tint = HSLColor.fromColor(photoTint(const Color(0xFF808080)).bottom);
    expect(tint.saturation, lessThan(0.02));
  });
}
