import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/domain/entities/expense.dart';
import 'package:tach/src/domain/logic/recap.dart';

Expense _expense(
  String id,
  DateTime at,
  int amount, {
  String payer = 'an',
  bool photo = false,
}) => Expense(
  id: id,
  payerId: payer,
  amount: amount,
  note: id,
  splits: {payer: amount},
  createdAt: at,
  photoBytes: photo ? Uint8List(1) : null,
);

void main() {
  final november = DateTime(2026, 11);
  final expenses = [
    _expense('trứng', DateTime(2026, 11, 2), 30000, photo: true),
    _expense('lẩu', DateTime(2026, 11, 14), 320000, payer: 'mia', photo: true),
    _expense('mạng', DateTime(2026, 11, 20), 250000, payer: 'leo'),
    _expense('gạo', DateTime(2026, 11, 30, 23), 95000, photo: true),
    _expense('tháng 10', DateTime(2026, 10, 31), 999000, photo: true),
    _expense('tháng 12', DateTime(2026, 12, 1), 888000, payer: 'mia'),
  ];

  test('chỉ tính các khoản trong tháng', () {
    final recap = monthRecap(expenses: expenses, month: november);
    expect(recap.total, 30000 + 320000 + 250000 + 95000);
    expect(recap.count, 4);
    expect(recap.photoCount, 3);
    expect(recap.isEmpty, isFalse);
  });

  test('ảnh nổi bật: chỉ khoản có ảnh, khoản lớn đứng đầu', () {
    final recap = monthRecap(expenses: expenses, month: november);
    expect(recap.highlights.map((e) => e.id), ['lẩu', 'gạo', 'trứng']);
  });

  test('người chi nhiều nhất xếp theo tổng tiền đã trả', () {
    final recap = monthRecap(expenses: expenses, month: november);
    expect(recap.payers, [
      (memberId: 'mia', paid: 320000),
      (memberId: 'leo', paid: 250000),
      (memberId: 'an', paid: 125000),
    ]);
  });

  test('nhiều ảnh thì chỉ giữ số ảnh vừa một tấm tổng kết', () {
    final many = [
      for (var day = 1; day <= 9; day++)
        _expense('k$day', DateTime(2026, 11, day), day * 1000, photo: true),
    ];
    final recap = monthRecap(expenses: many, month: november);
    expect(recap.photoCount, 9);
    expect(recap.highlights, hasLength(MonthRecap.maxHighlights));
    expect(recap.highlights.first.id, 'k9');
  });

  test('tháng chưa có khoản nào', () {
    final recap = monthRecap(expenses: expenses, month: DateTime(2026, 9));
    expect(recap.isEmpty, isTrue);
    expect(recap.total, 0);
    expect(recap.highlights, isEmpty);
    expect(recap.payers, isEmpty);
  });
}
