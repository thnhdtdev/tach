import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'zoom_plan.dart';

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

  /// Mức zoom nhỏ nhất của mặt camera đang dùng: 0,5 nếu có ống kính góc siêu
  /// rộng, không thì 1. Biết được sau [open].
  double get minZoom;

  /// Mức zoom lớn nhất; bằng [minZoom] nếu camera không zoom được.
  double get maxZoom;

  /// Mức zoom camera đang thật sự dùng. Camera vừa mở luôn ở 1×.
  double get zoom;

  /// Đặt mức zoom, từ [minZoom] đến [maxZoom]. Qua mốc 1× camera tự đổi giữa
  /// ống kính chính và ống kính góc siêu rộng, nên hình xem trực tiếp có thể
  /// tắt một nhịp và [preview] cần được vẽ lại sau khi hàm này xong.
  ///
  /// Trả về trạng thái camera sau đó; khác [CameraStatus.ready] nếu ống kính
  /// mới không mở được hoặc camera đã bị đóng giữa chừng.
  Future<CameraStatus> setZoom(double level);

  /// Nhả camera để app khác dùng và đỡ tốn pin.
  Future<void> close();
}

/// Camera thật, dùng plugin `camera`.
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

  /// Mức zoom lớn nhất của ống kính chính.
  var _maxZoom = 1.0;
  var _zoom = 1.0;

  /// Tăng mỗi lần [close]; lần mở nào xong sau khi đã có lệnh đóng thì tự hủy.
  var _closes = 0;

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

  /// Mở ống kính chính hoặc ống kính góc siêu rộng (theo [_ultraWide]) của
  /// mặt camera đang chọn.
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

      // Máy chỉ có một camera thì dùng camera đó, dù hướng nào.
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
      // 1080p: ảnh vuông cắt ra được 1080 điểm ảnh mỗi cạnh, vừa khít khung ảnh
      // trên màn hình điện thoại. Mức 720p thấp hơn làm ảnh bị kéo giãn và mờ;
      // mức cao hơn làm hình xem trực tiếp nặng máy mà mắt không thấy khác.
      // Tắt âm thanh để không phải xin quyền micro; app chỉ chụp ảnh.
      final controller = CameraController(
        chosen,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();
      if (_closes != closesBefore) {
        // Màn chụp đã bị che trong lúc mở; không giữ camera chạy ngầm.
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

  /// Giao diện app là dọc, nên giữ ảnh chụp dọc dù người dùng xoay máy.
  Future<void> _lockPortrait(CameraController controller) async {
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on Exception {
      // Một số nền tảng không hỗ trợ khóa hướng; hình vẫn dùng được.
    }
  }

  /// Mức zoom lớn nhất của ống kính chính, chặn ở [_zoomCap].
  Future<double> _readMaxZoom(CameraController controller) async {
    try {
      final max = await controller.getMaxZoomLevel();
      return max.clamp(1.0, _zoomCap).toDouble();
    } on Exception {
      // Không đọc được thì coi như ống kính không zoom được.
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
      // Ví dụ bấm chụp đúng lúc camera đang đổi ống kính.
      throw CameraException('cameraNotReady', 'Camera chưa mở');
    }
    final file = await controller.takePicture();
    return file.readAsBytes();
  }

  @override
  Future<bool> setFlash(bool on) async {
    final controller = _controller;
    if (controller == null) return false;
    try {
      await controller.setFlashMode(on ? FlashMode.always : FlashMode.off);
      // Nhớ lại để bật tiếp khi camera đổi sang ống kính khác.
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
