import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../photo/photo_compressor.dart';
import 'frame_color.dart';
import 'zoom_plan.dart';

enum CameraStatus {
  /// Đang mở, hoặc đang tạm nghỉ khi màn camera bị che.
  starting,

  ready,

  denied,

  unavailable,
}

abstract interface class CaptureCamera {
  Future<CameraStatus> open();

  bool get canFlip;

  bool get isFront;

  Future<CameraStatus> flip();

  Widget preview();

  Future<Uint8List> takePhoto();

  /// Màu trung bình của hình đang ngắm; `null` khi chưa lấy được.
  Future<Color?> previewColor();

  /// Trả về `false` nếu camera không có đèn flash.
  Future<bool> setFlash(bool on);

  double get minZoom;

  double get maxZoom;

  double get zoom;

  /// Qua mốc 1× camera tự đổi ống kính, nên [preview] cần được vẽ lại sau khi
  /// hàm này xong.
  Future<CameraStatus> setZoom(double level);

  Future<void> close();
}

class PluginCaptureCamera implements CaptureCamera {
  /// Camera cho zoom số tới vài chục lần, nhưng quá mức này ảnh vỡ hạt, không
  /// còn đọc được hóa đơn.
  static const _zoomCap = 6.0;

  CameraController? _controller;
  var _lens = CameraLensDirection.back;
  var _canFlip = false;
  var _hasUltraWide = false;
  var _ultraWide = false;
  var _flashOn = false;

  var _maxZoom = 1.0;
  var _zoom = 1.0;

  /// Tăng mỗi lần [close]; lần mở nào xong sau khi đã có lệnh đóng thì tự hủy.
  var _closes = 0;
  var _readingFrame = false;

  @override
  double get minZoom => _hasUltraWide ? ultraWideZoom : 1;

  @override
  double get maxZoom => _maxZoom;

  @override
  double get zoom => _zoom;

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
  Future<CameraStatus> open() {
    _ultraWide = false;
    return _openLens();
  }

  Future<CameraStatus> _openLens() async {
    await close();
    final closesBefore = _closes;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return CameraStatus.unavailable;

      bool has(CameraLensDirection lens) =>
          cameras.any((c) => c.lensDirection == lens);
      _canFlip =
          has(CameraLensDirection.back) && has(CameraLensDirection.front);

      if (!has(_lens)) _lens = cameras.first.lensDirection;
      final sameSide = [
        for (final c in cameras)
          if (c.lensDirection == _lens) c,
      ];
      CameraDescription? ofType(CameraLensType type) =>
          sameSide.where((c) => c.lensType == type).firstOrNull;

      // Máy báo từng ống kính (chính, tele, góc siêu rộng) thành một camera
      // riêng. Nền tảng không báo loại ống kính thì lấy camera đầu tiên.
      final main = ofType(CameraLensType.wide) ?? sameSide.first;
      final ultraWide = ofType(CameraLensType.ultraWide);
      _hasUltraWide = ultraWide != null && ultraWide != main;
      if (!_hasUltraWide) _ultraWide = false;
      final chosen = _ultraWide ? ultraWide! : main;
      // 720p làm ảnh vuông bị kéo giãn và mờ; cao hơn 1080p thì khung ngắm nặng
      // máy. Tắt âm thanh để khỏi xin quyền micro.
      final controller = CameraController(
        chosen,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      if (_closes != closesBefore) {
        await controller.dispose();
        return CameraStatus.starting;
      }
      _controller = controller;
      await _lockPortrait(controller);
      if (_ultraWide) {
        _zoom = ultraWideZoom;
      } else {
        _zoom = 1;
        _maxZoom = await _readMaxZoom(controller);
      }
      if (_flashOn) await setFlash(true);
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

  Future<void> _lockPortrait(CameraController controller) async {
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on Exception {
      // Một số nền tảng không hỗ trợ khóa hướng; hình vẫn dùng được.
    }
  }

  Future<double> _readMaxZoom(CameraController controller) async {
    try {
      final max = await controller.getMaxZoomLevel();
      return max.clamp(1.0, _zoomCap).toDouble();
    } on Exception {
      return 1;
    }
  }

  @override
  Future<CameraStatus> setZoom(double level) async {
    final plan = planZoom(
      level,
      hasUltraWide: _hasUltraWide,
      onUltraWide: _ultraWide,
      maxZoom: _maxZoom,
    );
    if (plan.ultraWide != _ultraWide) {
      _ultraWide = plan.ultraWide;
      final status = await _openLens();
      if (status != CameraStatus.ready) return status;
    }

    final controller = _controller;
    if (controller == null) return CameraStatus.starting;
    try {
      await controller.setZoomLevel(plan.lensZoom);
      _zoom = plan.zoom;
    } on Exception {
      // Camera vừa bị đóng giữa chừng; lần mở sau sẽ về 1×.
    }
    return CameraStatus.ready;
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
    if (controller == null) {
      throw CameraException('cameraNotReady', 'Camera chưa mở');
    }
    final front = isFront;
    final file = await controller.takePicture();
    final bytes = await file.readAsBytes();
    // Khung ngắm camera trước là hình soi gương còn ảnh chụp thì không; lật lại
    // để ảnh giống đúng lúc ngắm.
    return front ? squareJpeg(bytes, quality: 95, mirror: true) : bytes;
  }

  @override
  Future<Color?> previewColor() async {
    final controller = _controller;
    // Chỉ iOS: ở đó bật tắt luồng khung hình không đụng tới hình xem trực tiếp.
    // Android phải gắn thêm một luồng phân tích ảnh mỗi lần, chưa thử được.
    if (controller == null ||
        _readingFrame ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        controller.value.isTakingPicture ||
        controller.value.isStreamingImages) {
      return null;
    }

    // Mỗi khung hình nặng cỡ 8 MB, nên chỉ lấy một khung rồi tắt luồng ngay
    // thay vì để luồng chạy suốt.
    _readingFrame = true;
    final color = Completer<Color?>();
    try {
      await controller.startImageStream((image) {
        if (color.isCompleted) return;
        final plane = image.planes.first;
        color.complete(
          image.format.group == ImageFormatGroup.bgra8888
              ? averageBgraColor(
                  plane.bytes,
                  width: image.width,
                  height: image.height,
                  bytesPerRow: plane.bytesPerRow,
                )
              : null,
        );
      });
      return await color.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
    } on Exception {
      return null;
    } finally {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } on Exception {
        // Camera đã đóng trong lúc đọc; luồng khung hình đóng theo nó.
      }
      _readingFrame = false;
    }
  }

  @override
  Future<bool> setFlash(bool on) async {
    final controller = _controller;
    if (controller == null) return false;
    try {
      await controller.setFlashMode(on ? FlashMode.always : FlashMode.off);
      _flashOn = on;
      return true;
    } on CameraException {
      _flashOn = false;
      return false;
    }
  }

  @override
  Future<void> close() async {
    _closes++;
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
