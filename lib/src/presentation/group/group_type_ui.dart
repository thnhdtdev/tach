import 'package:material_ui/material_ui.dart';

import '../../domain/entities/group.dart';

/// Cách gọi và biểu tượng của từng loại nhóm trong giao diện.
extension GroupTypeUi on GroupType {
  String get label => switch (this) {
    GroupType.room => 'Phòng trọ',
    GroupType.trip => 'Chuyến đi',
    GroupType.family => 'Gia đình',
  };

  IconData get icon => switch (this) {
    GroupType.room => Icons.bed_outlined,
    GroupType.trip => Icons.luggage_outlined,
    GroupType.family => Icons.house_outlined,
  };

  /// Gợi ý tên nhóm hiện trong ô nhập.
  String get nameHint => switch (this) {
    GroupType.room => 'Ví dụ: Trọ 12 Cầu Giấy',
    GroupType.trip => 'Ví dụ: Đà Lạt tháng 12',
    GroupType.family => 'Ví dụ: Nhà mình',
  };
}
