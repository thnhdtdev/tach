import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/group.dart';
import '../../domain/logic/jar.dart';
import '../ledger/ledger_cubit.dart';

/// Màu đại diện của một nhóm trong lịch và chi tiết hũ.
Color groupTone(LedgerState state, Group group) {
  if (group.isPersonal) return const Color(0xFFB8B8B8);
  final index = state.groups.indexWhere((g) => g.id == group.id);
  return TachColors.avatarTones[(index < 0 ? 0 : index) %
      TachColors.avatarTones.length];
}

Color levelColor(DayLevel level) => switch (level) {
  DayLevel.under => TachColors.mint,
  DayLevel.over => TachColors.warn,
  DayLevel.doubled => TachColors.danger,
};

/// Màu thanh tiến độ: dưới 70% xanh, từ 70% vàng, vượt hũ thì đỏ.
Color progressColor(int spent, Budget budget) {
  if (spent > budget.amount) return TachColors.danger;
  return spent * 10 >= budget.amount * 7 ? TachColors.warn : TachColors.mint;
}

JarMonth jarOf(LedgerState state, DateTime month, Budget? budget) {
  return jarMonth(
    meId: state.meId,
    groups: [
      for (final l in state.ledgers) (group: l.group, expenses: l.expenses),
    ],
    month: month,
    includePersonal: budget?.includePersonal ?? true,
  );
}

String groupLabel(Group group) =>
    group.isPersonal ? 'Chỉ mình tôi' : group.name;
