import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tach/src/services/photo/photo_compressor.dart';

Uint8List _redLeftBlueRight() {
  final image = img.Image(width: 96, height: 64);
  for (final pixel in image) {
    if (pixel.x < 48) {
      pixel.setRgb(255, 0, 0);
    } else {
      pixel.setRgb(0, 0, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('cắt vuông ở giữa và giữ nguyên chiều trái phải', () async {
    final square = img.decodeJpg(await squareJpeg(_redLeftBlueRight()))!;

    expect((square.width, square.height), (64, 64));
    expect(square.getPixel(8, 32).r, greaterThan(200));
    expect(square.getPixel(56, 32).b, greaterThan(200));
  });

  test('lật ảnh trái phải cho camera trước', () async {
    final square = img.decodeJpg(
      await squareJpeg(_redLeftBlueRight(), mirror: true),
    )!;

    expect((square.width, square.height), (64, 64));
    expect(square.getPixel(8, 32).b, greaterThan(200));
    expect(square.getPixel(56, 32).r, greaterThan(200));
  });
}
