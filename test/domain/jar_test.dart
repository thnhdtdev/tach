import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/domain/entities/budget.dart';
import 'package:tach/src/domain/entities/expense.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/domain/logic/jar.dart';

Group _group(String id, {GroupType type = GroupType.room}) => Group(
  id: id,
  name: id,
  code: 'G',
  type: type,
  inviteCode: 'AAAAAA',
  createdBy: 'me',
  members: const [],
);

Expense _expense(
  String id,
  DateTime at, {
  required int amount,
  required Map<String, int> splits,
  String payer = 'me',
}) => Expense(
  id: id,
  payerId: payer,
  amount: amount,
  note: id,
  splits: splits,
  createdAt: at,
);

void main() {
  final september = DateTime(2026, 9);
  final home = _group('Nhà');
  final trip = _group('Đà Lạt', type: GroupType.trip);
  final mine = _group('Riêng tôi', type: GroupType.personal);

  JarMonth jar({bool includePersonal = true}) => jarMonth(
    meId: 'me',
    month: september,
    includePersonal: includePersonal,
    groups: [
      (
        group: home,
        expenses: [
          // Mình trả cả bữa 600k nhưng chỉ chịu 150k.
          _expense(
            'lẩu',
            DateTime(2026, 9, 12, 19),
            amount: 600000,
            splits: {'me': 150000, 'a': 150000, 'b': 150000, 'c': 150000},
          ),
          // Người khác trả, mình vẫn chịu một nửa.
          _expense(
            'điện',
            DateTime(2026, 9, 30, 23, 59),
            amount: 400000,
            splits: {'me': 200000, 'a': 200000},
            payer: 'a',
          ),
          // Khoản mình không có phần.
          _expense(
            'quà',
            DateTime(2026, 9, 5),
            amount: 90000,
            splits: {'a': 90000},
          ),
          // Tháng khác.
          _expense(
            'tháng 10',
            DateTime(2026, 10, 1),
            amount: 50000,
            splits: {'me': 50000},
          ),
        ],
      ),
      (
        group: trip,
        expenses: [
          _expense(
            'xăng',
            DateTime(2026, 9, 12, 8),
            amount: 800000,
            splits: {'me': 800000},
          ),
        ],
      ),
      (
        group: mine,
        expenses: [
          _expense(
            'phở',
            DateTime(2026, 9, 1, 7),
            amount: 35000,
            splits: {'me': 35000},
          ),
        ],
      ),
    ],
  );

  test('hũ chỉ cộng phần của mình trong tháng, trên mọi nhóm', () {
    final month = jar();
    expect(month.spent, 150000 + 200000 + 800000 + 35000);
    expect(month.entries.map((e) => e.expense.id), [
      'điện',
      'lẩu',
      'xăng',
      'phở',
    ]);
    expect(month.daysInMonth, 30);
  });

  test('theo nhóm: nhóm tiêu nhiều đứng đầu, kèm số khoản', () {
    final totals = jar().byGroup;
    expect(totals.map((t) => (t.group.id, t.amount, t.count)), [
      ('Đà Lạt', 800000, 1),
      ('Nhà', 350000, 2),
      ('Riêng tôi', 35000, 1),
    ]);
  });

  test('tắt "tính cả khoản Chỉ mình tôi" thì khoản riêng không vào hũ', () {
    final month = jar(includePersonal: false);
    expect(month.spent, 150000 + 200000 + 800000);
    expect(month.onDay(1), isEmpty);
  });

  test('theo ngày: gộp các nhóm trong cùng một ngày', () {
    final day = jar().onDay(12);
    expect(day.map((e) => e.group.id), ['Nhà', 'Đà Lạt']);
    expect(day.fold(0, (sum, e) => sum + e.share), 950000);
  });

  test('mức ngày: dưới mức, vượt mức, gấp đôi', () {
    final month = jar();
    final budget = Budget(period: september, amount: 3000000);
    expect(month.dailyLimit(budget), 100000);
    expect(month.levelOf(0, budget), DayLevel.under);
    expect(month.levelOf(100000, budget), DayLevel.under);
    expect(month.levelOf(100001, budget), DayLevel.over);
    expect(month.levelOf(199999, budget), DayLevel.over);
    expect(month.levelOf(200000, budget), DayLevel.doubled);
  });

  group('mức hũ áp dụng cho một tháng', () {
    final july = Budget(period: DateTime(2026, 7), amount: 4000000);
    final august = Budget(
      period: DateTime(2026, 8, 15),
      amount: 5000000,
      repeats: false,
    );

    test('lấy mức đặt riêng cho tháng đó', () {
      expect(budgetFor([july, august], DateTime(2026, 8))!.amount, 5000000);
    });

    test('không có thì lấy mức gần nhất còn bật tự áp dụng', () {
      expect(budgetFor([july, august], september)!.amount, 4000000);
    });

    test('tháng trước khi đặt hũ thì chưa có mức', () {
      expect(budgetFor([july, august], DateTime(2026, 6)), isNull);
    });

    test('mức không tự áp dụng thì chỉ dùng cho đúng tháng của nó', () {
      expect(budgetFor([august], september), isNull);
    });
  });
}
