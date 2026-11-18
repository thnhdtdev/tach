import '../entities/expense.dart';
import '../entities/settlement.dart';

/// Số dư ròng của từng người: tổng đã trả trừ tổng phần phải chịu.
///
/// Số dương là được nhận, số âm là phải trả. Chỉ các lần trả nợ đã được xác
/// nhận mới làm thay đổi số dư.
Map<String, int> netBalances({
  required Iterable<String> memberIds,
  required Iterable<Expense> expenses,
  Iterable<Settlement> settlements = const [],
}) {
  final net = {for (final id in memberIds) id: 0};
  void add(String id, int delta) => net[id] = (net[id] ?? 0) + delta;

  for (final expense in expenses) {
    add(expense.payerId, expense.amount);
    expense.splits.forEach((userId, share) => add(userId, -share));
  }
  for (final settlement in settlements) {
    if (settlement.status != SettlementStatus.confirmed) continue;
    add(settlement.fromId, settlement.amount);
    add(settlement.toId, -settlement.amount);
  }
  return net;
}

/// Gộp nợ chéo thành ít lần chuyển khoản.
///
/// Cách tham lam: mỗi vòng ghép người nợ nhiều nhất với người được nhận nhiều
/// nhất và chuyển phần nhỏ hơn trong hai số. Kết quả có tối đa n − 1 lần
/// chuyển. Khi bằng nhau thì xếp theo id để kết quả ổn định.
List<Transfer> simplifyDebts(Map<String, int> net) {
  final debtors = <String, int>{};
  final creditors = <String, int>{};
  net.forEach((id, value) {
    if (value < 0) debtors[id] = -value;
    if (value > 0) creditors[id] = value;
  });

  String largest(Map<String, int> side) {
    final ids = side.keys.toList()
      ..sort((a, b) {
        final byAmount = side[b]!.compareTo(side[a]!);
        return byAmount != 0 ? byAmount : a.compareTo(b);
      });
    return ids.first;
  }

  final transfers = <Transfer>[];
  while (debtors.isNotEmpty && creditors.isNotEmpty) {
    final from = largest(debtors);
    final to = largest(creditors);
    final owed = debtors[from]!;
    final due = creditors[to]!;
    final amount = owed < due ? owed : due;

    transfers.add(Transfer(fromId: from, toId: to, amount: amount));
    if (owed == amount) {
      debtors.remove(from);
    } else {
      debtors[from] = owed - amount;
    }
    if (due == amount) {
      creditors.remove(to);
    } else {
      creditors[to] = due - amount;
    }
  }
  return transfers;
}
