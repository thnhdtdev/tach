import 'dart:typed_data';
import 'dart:ui';

/// Màu trung bình của phần vuông ở giữa một khung hình BGRA, là phần hiện trong
/// khung ngắm. Chỉ lấy mẫu một lưới điểm thưa vì khung hình có vài triệu điểm.
Color? averageBgraColor(
  Uint8List bytes, {
  required int width,
  required int height,
  required int bytesPerRow,
}) {
  if (width <= 0 || height <= 0 || bytesPerRow < width * 4) return null;
  if (bytes.length < bytesPerRow * height) return null;

  const steps = 16;
  final side = width < height ? width : height;
  final left = (width - side) ~/ 2;
  final top = (height - side) ~/ 2;
  var red = 0, green = 0, blue = 0;
  for (var row = 0; row < steps; row++) {
    final y = top + side * (2 * row + 1) ~/ (2 * steps);
    for (var column = 0; column < steps; column++) {
      final x = left + side * (2 * column + 1) ~/ (2 * steps);
      final offset = y * bytesPerRow + x * 4;
      blue += bytes[offset];
      green += bytes[offset + 1];
      red += bytes[offset + 2];
    }
  }
  const count = steps * steps;
  return Color.fromARGB(255, red ~/ count, green ~/ count, blue ~/ count);
}
