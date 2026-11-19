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

  /// Mức zoom nhỏ nhất của ống kính đang mở: 1 với ống kính chính, 0,5 với
  /// ống kính góc siêu rộng. Biết được sau [open].
  double get minZoom;

  /// Mức zoom lớn nhất của ống kính đang mở; bằng [minZoom] nếu không zoom được.
  double get maxZoom;

  /// Đặt mức zoom, từ [minZoom] đến [maxZoom]. Ống kính vừa mở luôn ở [minZoom].
  Future<void> setZoom(double level);

  /// Mặt camera đang dùng có thêm ống kính góc siêu rộng (0,5×) không.
  bool get hasUltraWide;

  /// Đang dùng ống kính góc siêu rộng.
  bool get isUltraWide;

  /// Chuyển giữa ống kính chính và ống kính góc siêu rộng rồi mở ống kính mới.
  /// [open] và [flip] luôn quay về ống kính chính.
  Future<CameraStatus> useUltraWide(bool on);

  /// Nhả camera để app khác dùng và đỡ tốn pin.
  Future<void> close();
}

/// Camera thật, dùng plugin `camera`.
class PluginCaptureCamera implements CaptureCamera {
  /// Camera cho zoom số tới vài chục lần, nhưng quá mức này ảnh vỡ hạt, không
  /// còn đọc được hóa đơn.
  static const _zoomCap = 5.0;

  /// Ống kính góc siêu rộng nhìn rộng gấp đôi ống kính chính.
  static const _ultraWideFactor = 0.5;

  /// Phóng ống kính góc siêu rộng tới 1× thì kém nét hơn ống kính chính, nên
  /// dừng ngay trước đó.
  static const _ultraWideZoomCap = 0.9;

  CameraController? _controller;
  var _lens = CameraLensDirection.back;
  var _canFlip = false;
  var _hasUltraWide = false;
  var _ultraWide = false;
  var _maxZoom = 1.0;

  /// Mức zoom hiển thị ứng với mức 1 của ống kính đang mở.
  double get _lensFactor => _ultraWide ? _ultraWideFactor : 1;

  @override
  double get minZoom => _lensFactor;

  @override
  double get maxZoom => _maxZoom;

  @override
  bool get hasUltraWide => _hasUltraWide;

  @override
  bool get isUltraWide => _ultraWide;

  @override
  Future<CameraStatus> useUltraWide(bool on) {
    _ultraWide = on;
    return _openLens();
  }

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
      // Tắt âm thanh để không phải xin quyền micro; app chỉ chụp ảnh.
      final controller = CameraController(
        chosen,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      await _lockPortrait(controller);
      _maxZoom = await _readMaxZoom(controller);
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

  /// Mức zoom hiển thị lớn nhất của ống kính vừa mở.
  Future<double> _readMaxZoom(CameraController controller) async {
    final cap = _ultraWide ? _ultraWideZoomCap : _zoomCap;
    try {
      final max = await controller.getMaxZoomLevel() * _lensFactor;
      return max.clamp(minZoom, cap).toDouble();
    } on Exception {
      // Không đọc được thì coi như ống kính không zoom được.
      return minZoom;
    }
  }

  @override
  Future<void> setZoom(double level) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      // Camera tính mức zoom theo từng ống kính, bắt đầu từ 1.
      await controller.setZoomLevel(
        level.clamp(minZoom, _maxZoom).toDouble() / _lensFactor,
      );
    } on Exception {
      // Camera vừa bị đóng giữa chừng; lần mở sau sẽ về mức nhỏ nhất.
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
