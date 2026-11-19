/// Mức zoom của ống kính góc siêu rộng khi chưa phóng: nó nhìn rộng gấp đôi ống
/// kính chính.
const ultraWideZoom = 0.5;

/// Đang ở ống kính chính thì phải thu nhỏ xuống dưới mức này mới đổi sang ống
/// kính góc siêu rộng. Chiều ngược lại đổi ở đúng 1×. Khoảng đệm này để camera
/// không đổi ống kính liên tục khi hai ngón tay rung quanh mốc 1×.
const switchToUltraWideBelow = 0.92;

/// Cách camera thực hiện một mức zoom.
class ZoomPlan {
  const ZoomPlan({
    required this.ultraWide,
    required this.lensZoom,
    required this.zoom,
  });

  /// Dùng ống kính góc siêu rộng thay cho ống kính chính.
  final bool ultraWide;

  /// Mức zoom đặt cho ống kính đó. Mỗi ống kính tự tính từ 1.
  final double lensZoom;

  /// Mức zoom người dùng thấy sau khi thực hiện, có thể khác mức yêu cầu khi bị
  /// chặn ở hai đầu hoặc nằm trong khoảng đệm quanh 1×.
  final double zoom;
}

/// Chọn ống kính và mức zoom của ống kính cho mức zoom [level] người dùng muốn.
///
/// [maxZoom] là mức lớn nhất của ống kính chính. Có ống kính góc siêu rộng thì
/// dải zoom kéo dài xuống [ultraWideZoom].
ZoomPlan planZoom(
  double level, {
  required bool hasUltraWide,
  required bool onUltraWide,
  required double maxZoom,
}) {
  final min = hasUltraWide ? ultraWideZoom : 1.0;
  final max = maxZoom < 1 ? 1.0 : maxZoom;
  final target = level.clamp(min, max).toDouble();

  final switchBelow = onUltraWide ? 1.0 : switchToUltraWideBelow;
  if (hasUltraWide && target < switchBelow) {
    return ZoomPlan(
      ultraWide: true,
      lensZoom: target / ultraWideZoom,
      zoom: target,
    );
  }
  final zoom = target < 1 ? 1.0 : target;
  return ZoomPlan(ultraWide: false, lensZoom: zoom, zoom: zoom);
}
