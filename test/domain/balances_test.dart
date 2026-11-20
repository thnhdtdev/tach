import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/domain/entities/expense.dart';
import 'package:tach/src/domain/entities/settlement.dart';
import 'package:tach/src/domain/logic/balances.dart';
import 'package:tach/src/domain/logic/split.dart';

Expense _expense(String payer, int amount, List<String> among) {
  return Expense(
    id: '$payer-$amount',
    payerId: payer,
    amount: amount,
    note: '',
    splits: splitEqually(amount: amount, participantIds: among, payerId: payer),
    createdAt: DateTime(2026, 11, 1),
  );
}

Settlement _settlement(
  String from,
  String to,
  int amount,
  SettlementStatus status,
) {
  return Settlement(
    id: '$from-$to',
    fromId: from,
    toId: to,
    amount: amount,
    transferCode: '',
    status: status,
    createdAt: DateTime(2026, 11, 2),
  );
}

void main() {
  const members = ['a', 'b', 'c'];

  group('netBalances', () {
    test('người trả được nhận lại phần của người khác', () {
      final net = netBalances(
        memberIds: members,
        expenses: [_expense('a', 30000, members)],
      );
      expect(net, {'a': 20000, 'b': -10000, 'c': -10000});
    });

    test('tổng số dư của cả nhóm luôn bằng 0', () {
      final net = netBalances(
        memberIds: members,
        expenses: [
          _expense('a', 10000, members),
          _expense('b', 45500, ['a', 'b']),
          _expense('c', 7, members),
        ],
      );
      expect(net.values.reduce((x, y) => x + y), 0);
    });

    test('chỉ lần trả đã xác nhận mới làm giảm nợ', () {
      final expenses = [_expense('a', 30000, members)];
      final pending = netBalances(
        memberIds: members,
        expenses: expenses,
        settlements: [_settlement('b', 'a', 10000, SettlementStatus.pending)],
      );
      expect(pending['b'], -10000);

      final confirmed = netBalances(
        memberIds: members,
        expenses: expenses,
        settlements: [_settlement('b', 'a', 10000, SettlementStatus.confirmed)],
      );
      expect(confirmed, {'a': 10000, 'b': 0, 'c': -10000});
    });
  });

  group('simplifyDebts', () {
    test('gộp nợ bắc cầu: A nợ B, B nợ C thành A trả thẳng C', () {
      final transfers = simplifyDebts({'a': -50000, 'b': 0, 'c': 50000});
      expect(transfers, [
        const Transfer(fromId: 'a', toId: 'c', amount: 50000),
      ]);
    });

    test('ghép người nợ nhiều nhất với người được nhận nhiều nhất', () {
      final transfers = simplifyDebts({
        'an': -266000,
        'minh': -186000,
        'lan': 330000,
        'hung': 122000,
      });
      expect(transfers, [
        const Transfer(fromId: 'an', toId: 'lan', amount: 266000),
        const Transfer(fromId: 'minh', toId: 'hung', amount: 122000),
        const Transfer(fromId: 'minh', toId: 'lan', amount: 64000),
      ]);
    });

    test('số lần chuyển không quá n − 1 và trả hết mọi khoản nợ', () {
      final net = {'a': -700, 'b': -300, 'c': 450, 'd': 250, 'e': 300};
      final transfers = simplifyDebts(net);
      expect(transfers.length, lessThanOrEqualTo(net.length - 1));

      final after = {...net};
      for (final t in transfers) {
        after[t.fromId] = after[t.fromId]! + t.amount;
        after[t.toId] = after[t.toId]! - t.amount;
      }
      expect(after.values, everyElement(0));
    });

    test('không ai nợ ai thì không có lần chuyển nào', () {
      expect(simplifyDebts({'a': 0, 'b': 0}), isEmpty);
    });
  });
}
