import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// "1×", "1,4×": một chữ số thập phân, bỏ phần ",0".
String formatZoom(double zoom) {
  final tenths = (zoom * 10).round();
  final whole = tenths ~/ 10;
  final rest = tenths % 10;
  return rest == 0 ? '$whole×' : '$whole,$rest×';
}

/// Bắt thao tác chụm hai ngón tay trên khung ngắm.
class PinchZoomDetector extends StatelessWidget {
  const PinchZoomDetector({
    super.key,
    required this.enabled,
    required this.onStart,
    required this.onScale,
    required this.child,
  });

  final bool enabled;

  /// Gọi mỗi khi bắt đầu một lần chụm, kể cả khi vừa đặt thêm ngón thứ hai.
  final VoidCallback onStart;

  /// Tỉ lệ so với lúc bắt đầu chụm: lớn hơn 1 là hai ngón đang tách ra.
  final ValueChanged<double> onScale;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        if (enabled)
          _PinchRecognizer:
              GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
                () => _PinchRecognizer(debugOwner: this),
                (recognizer) {
                  recognizer.onStart = (_) => onStart();
                  recognizer.onUpdate = (details) {
                    if (details.pointerCount >= 2) onScale(details.scale);
                  };
                },
              ),
      },
      child: child,
    );
  }
}

/// Khung ngắm nằm trong bảng tin vuốt dọc. Ngón thứ hai vừa chạm vào là nhận
/// luôn thao tác, để bảng tin không hiểu hai ngón kéo dọc thành vuốt sang khoản
/// chi khác.
class _PinchRecognizer extends ScaleGestureRecognizer {
  _PinchRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final secondFinger = pointerCount >= 1;
    super.addAllowedPointer(event);
    if (secondFinger) resolve(GestureDisposition.accepted);
  }
}

/// Nút zoom ở góc khung ngắm: hiện mức zoom hiện tại, kể cả mức lẻ do chụm hai
/// ngón tay. Bấm để chuyển sang mức kế tiếp.
class ZoomButton extends StatelessWidget {
  const ZoomButton({super.key, required this.zoom, required this.onPressed});

  final double zoom;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = formatZoom(zoom);
    final zoomed = label != '1×';
    return Semantics(
      container: true,
      button: true,
      label: 'Zoom $label',
      hint: 'Bấm để đổi mức zoom',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: zoomed ? TachColors.mintLight : Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
