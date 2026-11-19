import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:share_plus/share_plus.dart';

import 'photo_compressor.dart';

abstract interface class PhotoSharer {
  /// Mở bảng chia sẻ của máy với ảnh vuông của một khoản chi. [origin] là vùng
  /// trên màn hình để iPad neo bảng chia sẻ vào.
  Future<void> share(Uint8List photo, {ui.Rect? origin});
}

class SystemPhotoSharer implements PhotoSharer {
  @override
  Future<void> share(Uint8List photo, {ui.Rect? origin}) async {
    final square = await _squared(photo);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(square, mimeType: 'image/jpeg')],
        fileNameOverrides: const ['tach.jpg'],
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Ảnh vừa chụp còn nguyên khổ của camera; ảnh tải từ máy chủ đã vuông sẵn.
  Future<Uint8List> _squared(Uint8List photo) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(photo);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final isSquare = descriptor.width == descriptor.height;
    descriptor.dispose();
    buffer.dispose();
    return isSquare ? photo : squareJpeg(photo, quality: 92);
  }
}
