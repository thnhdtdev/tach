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
  /// Mở camera đang chọn (mặc định là camera sau). Gọi lại được sau [close].
  Future<CameraStatus> open();

  /// Máy có cả camera trước và sau để đổi qua lại không. Biết được sau [open].
  bool get canFlip;

  /// Đang dùng camera trước (camera quay về phía người cầm máy).
  bool get isFront;

  /// Đổi giữa camera trước và sau rồi mở camera mới.
  Future<CameraStatus> flip();

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
  var _lens = CameraLensDirection.back;
  var _canFlip = false;

  @override
  bool get canFlip => _canFlip;

  @override
  bool get isFront => _lens == CameraLensDirection.front;

  @override
  Future<CameraStatus> flip() {
    _lens = isFront ? CameraLensDirection.back : CameraLensDirection.front;
    return open();
  }

  @override
  Future<CameraStatus> open() async {
    await close();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return CameraStatus.unavailable;

      bool has(CameraLensDirection lens) =>
          cameras.any((c) => c.lensDirection == lens);
      _canFlip =
          has(CameraLensDirection.back) && has(CameraLensDirection.front);

      // Máy chỉ có một camera thì dùng camera đó, dù hướng nào.
      final chosen = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      _lens = chosen.lensDirection;
      // Tắt âm thanh để không phải xin quyền micro; app chỉ chụp ảnh.
      final controller = CameraController(
        chosen,
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
