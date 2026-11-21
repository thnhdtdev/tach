import '../entities/expense.dart';

/// Tổng kết chi tiêu một tháng của một nhóm, để dựng ảnh ghép chia sẻ.
class MonthRecap {
  const MonthRecap({
    required this.month,
    required this.total,
    required this.count,
    required this.photoCount,
    required this.highlights,
    required this.payers,
  });

  static const maxHighlights = 5;
  static const maxPayers = 3;

  final DateTime month;
  final int total;
  final int count;
  final int photoCount;

  /// Các khoản có ảnh đáng nhớ nhất tháng, khoản lớn đứng đầu.
  final List<Expense> highlights;

  /// Những người chi nhiều nhất, kèm tổng số tiền họ đã trả.
  final List<({String memberId, int paid})> payers;

  bool get isEmpty => count == 0;
}

MonthRecap monthRecap({
  required List<Expense> expenses,
  required DateTime month,
}) {
  final inMonth = [
    for (final e in expenses)
      if (e.createdAt.year == month.year && e.createdAt.month == month.month) e,
  ];
  final withPhoto = [
    for (final e in inMonth)
      if (e.hasPhoto) e,
  ]..sort((a, b) => b.amount.compareTo(a.amount));

  final paid = <String, int>{};
  for (final e in inMonth) {
    paid[e.payerId] = (paid[e.payerId] ?? 0) + e.amount;
  }
  final payers = [
    for (final entry in paid.entries) (memberId: entry.key, paid: entry.value),
  ]..sort((a, b) => b.paid.compareTo(a.paid));

  return MonthRecap(
    month: DateTime(month.year, month.month),
    total: inMonth.fold(0, (sum, e) => sum + e.amount),
    count: inMonth.length,
    photoCount: withPhoto.length,
    highlights: withPhoto.take(MonthRecap.maxHighlights).toList(),
    payers: payers.take(MonthRecap.maxPayers).toList(),
  );
}
