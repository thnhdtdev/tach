import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

Future<Uint8List> squareJpeg(
  Uint8List bytes, {
  int side = 1080,
  int quality = 85,
  bool mirror = false,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);

  final shortest = descriptor.width < descriptor.height
      ? descriptor.width
      : descriptor.height;
  final target = shortest < side ? shortest : side;
  final scale = target / shortest;
  final codec = await descriptor.instantiateCodec(
    targetWidth: (descriptor.width * scale).round(),
    targetHeight: (descriptor.height * scale).round(),
  );
  final frame = await codec.getNextFrame();
  final decoded = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (mirror) {
    canvas
      ..translate(target.toDouble(), 0)
      ..scale(-1, 1);
  }
  canvas.drawImageRect(
    decoded,
    ui.Rect.fromCenter(
      center: ui.Offset(decoded.width / 2, decoded.height / 2),
      width: target.toDouble(),
      height: target.toDouble(),
    ),
    ui.Rect.fromLTWH(0, 0, target.toDouble(), target.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final square = await picture.toImage(target, target);
  final pixels = await square.toByteData();

  decoded.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  picture.dispose();
  square.dispose();
  if (pixels == null) throw const FormatException('Không đọc được ảnh');

  // Nén JPEG tốn vài chục mili giây; chạy ở luồng khác để giao diện không giật.
  final rgba = pixels.buffer;
  return Isolate.run(() {
    final image = img.Image.fromBytes(
      width: target,
      height: target,
      bytes: rgba,
      numChannels: 4,
    );
    return img.encodeJpg(image, quality: quality);
  });
}
