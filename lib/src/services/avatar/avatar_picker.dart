import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum AvatarSource { gallery, camera }

abstract interface class AvatarPicker {
  Future<Uint8List?> pick(AvatarSource source);
}

class ImagePickerAvatarPicker implements AvatarPicker {
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
