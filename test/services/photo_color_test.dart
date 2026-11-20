import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tach/src/services/photo/photo_color.dart';

Uint8List _png(int width, int height, img.Color Function(int x, int y) at) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel.set(at(pixel.x, pixel.y));
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('ảnh một màu thì trả về đúng màu đó', () async {
    final color = await averagePhotoColor(
      _png(80, 80, (_, _) => img.ColorRgb8(200, 120, 40)),
    );

    expect(color, isNotNull);
    expect((color!.r * 255).round(), closeTo(200, 2));
    expect((color.g * 255).round(), closeTo(120, 2));
    expect((color.b * 255).round(), closeTo(40, 2));
  });

  test('ảnh dọc chỉ tính phần vuông ở giữa', () async {
    final color = await averagePhotoColor(
      _png(
        60,
        180,
        (_, y) => y >= 60 && y < 120
            ? img.ColorRgb8(0, 0, 255)
            : img.ColorRgb8(255, 0, 0),
      ),
    );

    expect(color!.b, greaterThan(0.8));
    expect(color.r, lessThan(0.2));
  });

  test('dữ liệu không phải ảnh thì trả về null', () async {
    expect(await averagePhotoColor(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
