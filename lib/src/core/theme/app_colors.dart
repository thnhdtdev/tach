import 'package:material_ui/material_ui.dart';

abstract final class TachColors {
  static const mint = Color(0xFF12A594);

  static const mintDeep = Color(0xFF0B5F55);

  static const mintLight = Color(0xFF7EE0CF);

  /// "Đã trả". Bản sáng hơn của xanh dương thương hiệu (#185FA5) để đọc được
  /// trên nền tối.
  static const paid = Color(0xFF7DB8F2);

  /// Chữ đặt trên nút xanh bạc hà (chữ trắng không đủ tương phản).
  static const onMint = Color(0xFF04231F);

  static const danger = Color(0xFFFF8A80);

  /// Chữ trên nền màu nhạt: avatar chữ cái, mã QR.
  static const ink = Color(0xFF14201E);

  /// Nền của mọi màn và bảng trượt: xám đậm, không đen hẳn.
  static const night = Color(0xFF222222);

  /// Thẻ và hộp thoại nổi trên nền.
  static const nightRaised = Color(0xFF3A3A3C);

  /// Ô nhập, nhãn và thanh nằm trên nền tối: trắng 10%.
  static const fill = Color(0x1AFFFFFF);
  static const hairline = Color(0x24FFFFFF);

  /// Chữ phụ: trắng 62%.
  static const soft = Color(0x9EFFFFFF);

  /// Nền của icon và ô nhấn mạnh: xanh bạc hà 22%.
  static const mintTint = Color(0x3812A594);

  static const avatarTones = [
    Color(0xFF7EE0CF),
    Color(0xFFF6C0A8),
    Color(0xFFCDBDF5),
    Color(0xFFF3D98B),
    Color(0xFFA9D0F5),
    Color(0xFFF5B5CC),
  ];
}
