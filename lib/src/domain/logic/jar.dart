import '../entities/budget.dart';
import '../entities/expense.dart';
import '../entities/group.dart';

/// Phần của người dùng trong một khoản chi.
class JarEntry {
  const JarEntry({
    required this.group,
    required this.expense,
    required this.share,
  });

  final Group group;
  final Expense expense;
  final int share;
}

class JarGroupTotal {
  const JarGroupTotal({
    required this.group,
    required this.amount,
    required this.count,
  });

  final Group group;
  final int amount;
  final int count;
}

/// Mức chi của một ngày so với mức ngày của hũ.
enum DayLevel { under, over, doubled }

/// Những gì người dùng đã tiêu trong một tháng, tính trên mọi nhóm. Chỉ tính
/// phần của họ trong mỗi khoản, không tính số tiền họ trả hộ người khác.
class JarMonth {
  JarMonth({required DateTime month, required this.entries})
    : month = DateTime(month.year, month.month);

  final DateTime month;

  /// Mới nhất đứng đầu.
  final List<JarEntry> entries;

  int get spent => entries.fold(0, (sum, e) => sum + e.share);

  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  List<JarEntry> onDay(int day) => [
    for (final e in entries)
      if (e.expense.createdAt.day == day) e,
  ];

  /// Nhóm tiêu nhiều nhất đứng đầu.
  List<JarGroupTotal> get byGroup {
    final totals = <String, JarGroupTotal>{};
    for (final e in entries) {
      final before = totals[e.group.id];
      totals[e.group.id] = JarGroupTotal(
        group: e.group,
        amount: (before?.amount ?? 0) + e.share,
        count: (before?.count ?? 0) + 1,
      );
    }
    return totals.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Mức được tiêu mỗi ngày nếu chia đều hũ cho cả tháng.
  int dailyLimit(Budget budget) => budget.amount ~/ daysInMonth;

  DayLevel levelOf(int dayAmount, Budget budget) {
    final limit = dailyLimit(budget);
    if (dayAmount <= limit) return DayLevel.under;
    return dayAmount >= limit * 2 ? DayLevel.doubled : DayLevel.over;
  }
}

JarMonth jarMonth({
  required String meId,
  required Iterable<({Group group, List<Expense> expenses})> groups,
  required DateTime month,
  bool includePersonal = true,
}) {
  final entries = <JarEntry>[
    for (final g in groups)
      if (includePersonal || !g.group.isPersonal)
        for (final e in g.expenses)
          if (e.createdAt.year == month.year &&
              e.createdAt.month == month.month &&
              (e.splits[meId] ?? 0) > 0)
            JarEntry(group: g.group, expense: e, share: e.splits[meId]!),
  ]..sort((a, b) => b.expense.createdAt.compareTo(a.expense.createdAt));
  return JarMonth(month: month, entries: entries);
}

/// Mức áp dụng cho [month]: mức đặt riêng cho tháng đó, nếu không có thì mức
/// gần nhất trước đó còn bật "tự áp dụng cho tháng sau".
Budget? budgetFor(List<Budget> budgets, DateTime month) {
  final target = DateTime(month.year, month.month);
  Budget? latest;
  for (final b in budgets) {
    if (b.period == target) return b;
    final earlier = b.period.isBefore(target) && b.repeats;
    if (earlier && (latest == null || b.period.isAfter(latest.period))) {
      latest = b;
    }
  }
  return latest;
}
