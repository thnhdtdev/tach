import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/budget.dart';
import '../../domain/logic/jar.dart';
import '../jar/jar_view.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';

/// Lịch ảnh của một tháng: mỗi ô là ảnh và phần tiền của người dùng trong ngày,
/// tính trên mọi nhóm.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.state,
    required this.jar,
    required this.budget,
    required this.onDay,
  });

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  final LedgerState state;
  final JarMonth jar;
  final Budget? budget;
  final void Function(int day, List<JarEntry> entries) onDay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Thứ Hai là cột đầu; `weekday` của Dart cũng tính thứ Hai là 1.
    final blanks = jar.month.weekday - 1;
    final budget = this.budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= jar.daysInMonth; day++)
              _DayCell(
                day: day,
                entries: jar.onDay(day),
                state: state,
                level: budget == null
                    ? null
                    : jar.levelOf(
                        jar.onDay(day).fold(0, (sum, e) => sum + e.share),
                        budget,
                      ),
                isToday:
                    DateTime(jar.month.year, jar.month.month, day) == today,
                isFuture: DateTime(
                  jar.month.year,
                  jar.month.month,
                  day,
                ).isAfter(today),
                onTap: onDay,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _Legend(state: state, jar: jar, budget: budget),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entries,
    required this.state,
    required this.level,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final int day;
  final List<JarEntry> entries;
  final LedgerState state;
  final DayLevel? level;
  final bool isToday;
  final bool isFuture;
  final void Function(int day, List<JarEntry> entries) onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(10));
    const number = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1,
      color: Colors.white,
      shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)],
    );

    if (entries.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: isFuture ? null : TachColors.fill.withValues(alpha: 0.05),
          borderRadius: radius,
          border: Border.all(
            color: isToday ? Colors.white : TachColors.hairline,
            width: isToday ? 2 : 1,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Text(
              '$day',
              style: number.copyWith(color: TachColors.soft, shadows: const []),
            ),
          ),
        ),
      );
    }

    final amount = entries.fold(0, (sum, e) => sum + e.share);
    final withPhoto = entries.where((e) => e.expense.hasPhoto).firstOrNull;
    final edge = level == null ? TachColors.mint : levelColor(level!);
    final groups = {for (final e in entries) e.group.id: e.group}.values;

    return Semantics(
      button: true,
      label: 'Ngày $day, ${formatVnd(amount)}, ${entries.length} khoản',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTap(day, entries),
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: isToday ? Colors.white : edge, width: 2),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (withPhoto != null)
                  ExpensePhoto(
                    photoUrl: withPhoto.expense.photoUrl,
                    photoBytes: withPhoto.expense.photoBytes,
                  )
                else
                  ColoredBox(color: edge.withValues(alpha: 0.22)),
                if (withPhoto != null)
                  const ColoredBox(color: Color(0x40000000)),
                Positioned(
                  top: 4,
                  right: 4,
                  left: 4,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatShortVnd(amount),
                          style: number.copyWith(
                            fontSize: 10,
                            shadows: const [],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: Text('$day', style: number),
                ),
                Positioned(
                  right: 5,
                  bottom: 6,
                  child: Row(
                    children: [
                      for (final group in groups.take(3))
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: BoxDecoration(
                            color: groupTone(state, group),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0x99000000),
                              width: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.state, required this.jar, required this.budget});

  final LedgerState state;
  final JarMonth jar;
  final Budget? budget;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final budget = this.budget;

    Widget item(Color color, String label, {bool round = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(round ? 5 : 3),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: text.bodySmall),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        if (budget != null) ...[
          item(
            levelColor(DayLevel.under),
            'đến ${formatShortVnd(jar.dailyLimit(budget))}',
          ),
          item(levelColor(DayLevel.over), 'vượt mức ngày'),
          item(levelColor(DayLevel.doubled), 'gấp đôi'),
        ],
        for (final total in jar.byGroup)
          item(
            groupTone(state, total.group),
            groupLabel(total.group),
            round: true,
          ),
      ],
    );
  }
}

/// Các khoản của một ngày, mở khi chạm vào ô lịch. Đóng lại với khoản được
/// chọn.
class DayEntriesSheet extends StatelessWidget {
  const DayEntriesSheet({
    super.key,
    required this.state,
    required this.date,
    required this.entries,
  });

  final LedgerState state;
  final DateTime date;
  final List<JarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = entries.fold(0, (sum, e) => sum + e.share);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                'Ngày ${date.day} tháng ${date.month}',
                style: text.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Phần của bạn: ${formatVnd(total)}',
                style: text.bodyMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in entries)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 2,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox.square(
                          dimension: 48,
                          child: ExpensePhoto(
                            photoUrl: entry.expense.photoUrl,
                            photoBytes: entry.expense.photoBytes,
                          ),
                        ),
                      ),
                      title: Text(
                        entry.expense.note.isEmpty
                            ? 'Khoản chi'
                            : entry.expense.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: groupTone(state, entry.group),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              entry.share == entry.expense.amount
                                  ? groupLabel(entry.group)
                                  : '${groupLabel(entry.group)}, cả khoản '
                                        '${formatShortVnd(entry.expense.amount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        formatVnd(entry.share),
                        style: text.titleMedium,
                      ),
                      onTap: () => Navigator.of(context).pop(entry),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
