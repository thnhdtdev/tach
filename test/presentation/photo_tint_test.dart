import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tach/src/presentation/feed/feed_background.dart';

void main() {
  test('nền giữ tông màu của ảnh nhưng đủ tối cho chữ trắng', () {
    for (final photo in const [
      Color(0xFFBE9678),
      Color(0xFF2E6BD6),
      Color(0xFFF2F2F2),
      Color(0xFF101010),
    ]) {
      final tint = photoTint(photo);

      expect(tint.top.computeLuminance(), lessThan(0.05));
      expect(tint.bottom.computeLuminance(), lessThan(0.05));
      expect(
        tint.bottom.computeLuminance(),
        greaterThan(tint.top.computeLuminance()),
      );
    }

    final brown = HSLColor.fromColor(photoTint(const Color(0xFFBE9678)).bottom);
    expect(
      brown.hue,
      closeTo(HSLColor.fromColor(const Color(0xFFBE9678)).hue, 2),
    );
    expect(brown.saturation, greaterThan(0.2));
  });

  test('ảnh xám thì nền xám, không tự thêm màu', () {
    final tint = HSLColor.fromColor(photoTint(const Color(0xFF808080)).bottom);
    expect(tint.saturation, lessThan(0.02));
  });
}
