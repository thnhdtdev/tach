import 'package:material_ui/material_ui.dart';

/// Bảng màu của Tach.
///
/// Xanh bạc hà chỉ dùng cho nút bấm, số tiền và điểm nhấn. Trạng thái
/// "Đã trả" dùng xanh dương để không lẫn với màu chính.
abstract final class TachColors {
  /// Màu thương hiệu chính (xanh bạc hà).
  static const mint = Color(0xFF12A594);

  /// Chữ đậm và số tiền cỡ nhỏ trên nền sáng.
  static const mintDeep = Color(0xFF0B5F55);

  /// Điểm nhấn và số tiền trên nền tối.
  static const mintLight = Color(0xFF7EE0CF);

  /// Nền nhạt cho các khối cần nổi bật.
  static const mintWash = Color(0xFFD5F5EF);

  /// Trạng thái "Đã trả".
  static const paid = Color(0xFF185FA5);

  /// Chữ đặt trên nút xanh bạc hà (chữ trắng không đủ tương phản).
  static const onMint = Color(0xFF04231F);

  static const ink = Color(0xFF14201E);
  static const inkSoft = Color(0xFF5B6B68);
  static const line = Color(0xFFE4EAE8);
  static const paper = Color(0xFFFFFFFF);

  /// Nền của các màn camera và bảng tin.
  static const night = Color(0xFF000000);
  static const nightRaised = Color(0xFF1C1C1E);

  /// Màu nền avatar, gán theo thứ tự thành viên trong nhóm.
  static const avatarTones = [
    Color(0xFF7EE0CF),
    Color(0xFFF6C0A8),
    Color(0xFFCDBDF5),
    Color(0xFFF3D98B),
    Color(0xFFA9D0F5),
    Color(0xFFF5B5CC),
  ];
}
