import 'package:material_ui/material_ui.dart';

import '../../domain/entities/group.dart';

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

  String get nameHint => switch (this) {
    GroupType.room => 'Ví dụ: Trọ 12 Cầu Giấy',
    GroupType.trip => 'Ví dụ: Đà Lạt tháng 12',
    GroupType.family => 'Ví dụ: Nhà mình',
  };
}
