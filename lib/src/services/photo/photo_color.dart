import 'dart:typed_data';
import 'dart:ui' as ui;

/// Màu trung bình của phần vuông ở giữa ảnh, là phần hiện trong bảng tin.
/// Trả về `null` nếu dữ liệu không phải ảnh đọc được.
Future<ui.Color?> averagePhotoColor(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final pixels = await image.toByteData();
    final width = image.width;
    final height = image.height;
    image.dispose();
    codec.dispose();
    if (pixels == null) return null;

    final side = width < height ? width : height;
    final left = (width - side) ~/ 2;
    final top = (height - side) ~/ 2;
    var red = 0, green = 0, blue = 0;
    for (var y = top; y < top + side; y++) {
      for (var x = left; x < left + side; x++) {
        final offset = (y * width + x) * 4;
        red += pixels.getUint8(offset);
        green += pixels.getUint8(offset + 1);
        blue += pixels.getUint8(offset + 2);
      }
    }
    final count = side * side;
    return ui.Color.fromARGB(255, red ~/ count, green ~/ count, blue ~/ count);
  } on Exception {
    return null;
  }
}
