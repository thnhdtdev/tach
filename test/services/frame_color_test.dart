import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/services/camera/frame_color.dart';

Uint8List _bgra(
  int width,
  int height,
  int bytesPerRow,
  (int, int, int) Function(int x, int y) rgbAt,
) {
  final bytes = Uint8List(bytesPerRow * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b) = rgbAt(x, y);
      final offset = y * bytesPerRow + x * 4;
      bytes[offset] = b;
      bytes[offset + 1] = g;
      bytes[offset + 2] = r;
      bytes[offset + 3] = 255;
    }
  }
  return bytes;
}

void main() {
  test('đọc đúng thứ tự kênh màu BGRA, kể cả khi mỗi dòng có byte đệm', () {
    final color = averageBgraColor(
      _bgra(64, 64, 64 * 4 + 16, (_, _) => (200, 120, 40)),
      width: 64,
      height: 64,
      bytesPerRow: 64 * 4 + 16,
    );

    expect((color!.r * 255).round(), 200);
    expect((color.g * 255).round(), 120);
    expect((color.b * 255).round(), 40);
  });

  test('khung hình ngang chỉ tính phần vuông ở giữa', () {
    final color = averageBgraColor(
      _bgra(
        192,
        64,
        192 * 4,
        (x, _) => x >= 64 && x < 128 ? (0, 0, 255) : (255, 0, 0),
      ),
      width: 192,
      height: 64,
      bytesPerRow: 192 * 4,
    );

    expect(color!.b, 1);
    expect(color.r, 0);
  });

  test('dữ liệu thiếu thì trả về null thay vì đọc tràn', () {
    expect(
      averageBgraColor(Uint8List(100), width: 64, height: 64, bytesPerRow: 256),
      isNull,
    );
  });
}
