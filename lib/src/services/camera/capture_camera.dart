import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

enum CameraStatus {
  /// Đang mở, hoặc đang tạm nghỉ khi màn camera bị che.
  starting,

  /// Đã có hình xem trực tiếp, chụp được.
  ready,

  /// Người dùng chưa cho phép app dùng camera.
  denied,

  /// Máy không có camera (ví dụ trình giả lập) hoặc camera không mở được.
  unavailable,
}

/// Camera của màn chụp khoản chi.
abstract interface class CaptureCamera {
  /// Mở camera sau của máy. Gọi lại được sau khi [close].
  Future<CameraStatus> open();

  /// Hình xem trực tiếp, lấp đầy khung chứa. Chỉ dùng khi đã [CameraStatus.ready].
  Widget preview();

  /// Chụp một tấm và trả về dữ liệu ảnh JPEG.
  Future<Uint8List> takePhoto();

  /// Bật hoặc tắt đèn flash khi chụp. Trả về `false` nếu máy không hỗ trợ.
  Future<bool> setFlash(bool on);

  /// Nhả camera để app khác dùng và đỡ tốn pin.
  Future<void> close();
}

/// Camera thật, dùng plugin `camera`.
class PluginCaptureCamera implements CaptureCamera {
  CameraController? _controller;

  @override
  Future<CameraStatus> open() async {
    await close();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return CameraStatus.unavailable;

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // Tắt âm thanh để không phải xin quyền micro; app chỉ chụp ảnh.
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      await _lockPortrait(controller);
      return CameraStatus.ready;
    } on CameraException catch (error) {
      return switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => CameraStatus.denied,
        _ => CameraStatus.unavailable,
      };
    } on PlatformException {
      return CameraStatus.unavailable;
    } on MissingPluginException {
      return CameraStatus.unavailable;
    }
  }

  /// Giao diện app là dọc, nên giữ ảnh chụp dọc dù người dùng xoay máy.
  Future<void> _lockPortrait(CameraController controller) async {
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on Exception {
      // Một số nền tảng không hỗ trợ khóa hướng; hình vẫn dùng được.
    }
  }

  @override
  Widget preview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);

    // Cảm biến báo kích thước theo chiều ngang; đảo lại cho màn hình dọc rồi
    // phóng cho kín khung, phần thừa bị cắt.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Future<Uint8List> takePhoto() async {
    final controller = _controller;
    if (controller == null) throw StateError('Camera chưa mở');
    final file = await controller.takePicture();
    return file.readAsBytes();
  }

  @override
  Future<bool> setFlash(bool on) async {
    final controller = _controller;
    if (controller == null) return false;
    try {
      await controller.setFlashMode(on ? FlashMode.always : FlashMode.off);
      return true;
    } on CameraException {
      return false;
    }
  }

  @override
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
