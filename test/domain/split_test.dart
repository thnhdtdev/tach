import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/domain/logic/split.dart';

void main() {
  group('splitEqually', () {
    test('chia hết thì mỗi người một phần bằng nhau', () {
      final shares = splitEqually(
        amount: 30000,
        participantIds: ['a', 'b', 'c', 'd'],
        payerId: 'b',
      );
      expect(shares, {'a': 7500, 'b': 7500, 'c': 7500, 'd': 7500});
    });

    test('phần dư tính cho người trả', () {
      final shares = splitEqually(
        amount: 10000,
        participantIds: ['a', 'b', 'c'],
        payerId: 'c',
      );
      expect(shares, {'a': 3333, 'b': 3333, 'c': 3334});
    });

    test('người trả không tham gia chia thì người đầu tiên nhận phần dư', () {
      final shares = splitEqually(
        amount: 10000,
        participantIds: ['a', 'b', 'c'],
        payerId: 'x',
      );
      expect(shares, {'a': 3334, 'b': 3333, 'c': 3333});
    });

    test('tổng các phần luôn bằng số tiền gốc', () {
      for (final amount in [1, 999, 10000, 123457, 486000]) {
        for (var people = 1; people <= 7; people++) {
          final ids = [for (var i = 0; i < people; i++) 'u$i'];
          final shares = splitEqually(
            amount: amount,
            participantIds: ids,
            payerId: 'u0',
          );
          expect(shares.values.reduce((a, b) => a + b), amount);
        }
      }
    });

    test('báo lỗi khi không có ai chia', () {
      expect(
        () => splitEqually(amount: 1000, participantIds: [], payerId: 'a'),
        throwsArgumentError,
      );
    });
  });
}
