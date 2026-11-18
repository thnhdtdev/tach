import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum AvatarSource { gallery, camera }

/// Lấy ảnh đại diện từ thư viện hoặc camera của máy.
abstract interface class AvatarPicker {
  /// Trả về dữ liệu ảnh, hoặc `null` nếu người dùng hủy.
  Future<Uint8List?> pick(AvatarSource source);
}

class ImagePickerAvatarPicker implements AvatarPicker {
  /// Avatar chỉ hiện ở cỡ nhỏ nên thu ảnh lại để nhẹ bộ nhớ và nhẹ khi tải lên.
  static const _maxSide = 512.0;

  final _picker = ImagePicker();

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    final file = await _picker.pickImage(
      source: source == AvatarSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }
}
