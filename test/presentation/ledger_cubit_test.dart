import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/datasource/sample/sample_group_repository.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/domain/entities/settlement.dart';
import 'package:tach/src/presentation/ledger/ledger_cubit.dart';

void main() {
  late LedgerCubit cubit;

  setUp(() async {
    cubit = LedgerCubit(SampleGroupRepository());
    await cubit.load();
  });

  tearDown(() => cubit.close());

  test('dữ liệu mẫu: bạn cần trả Lan 266.000đ sau khi gộp nợ', () {
    final state = cubit.state;
    expect(state.myNet, -266000);
    expect(state.transfers, hasLength(3));
    final mine = state.transfers.singleWhere((t) => t.fromId == state.meId);
    expect(state.member(mine.toId).name, 'Lan');
    expect(mine.amount, 266000);
  });

  test('ghi khoản mới: khoản đứng đầu bảng tin và số dư cập nhật', () {
    final before = cubit.state.myNet;
    final everyone = cubit.state.group.members.map((m) => m.id).toList();

    final expense = cubit.addExpense(
      amount: 30000,
      note: 'Rau',
      participantIds: everyone,
    );

    expect(cubit.state.expenses.first.id, expense.id);
    expect(expense.splits[cubit.state.meId], 7500);
    expect(cubit.state.myNet, before + 22500);
  });

  test('thả cảm xúc: chạm lại thì gỡ', () {
    final id = cubit.state.expenses.first.id;
    final me = cubit.state.meId;

    cubit.toggleReaction(id, '👍');
    expect(cubit.state.expenses.first.reactions[me], '👍');
    cubit.toggleReaction(id, '👍');
    expect(cubit.state.expenses.first.reactions.containsKey(me), isFalse);
  });

  test('bình luận trống bị bỏ qua, câu trả lời giữ id bình luận gốc', () {
    final expense = cubit.state.expenses.first;
    final count = expense.comments.length;

    cubit.addComment(expense.id, '   ');
    expect(cubit.state.expenses.first.comments, hasLength(count));

    cubit.addComment(expense.id, 'Để mình nấu', parentId: 'c-2');
    final added = cubit.state.expenses.first.comments.last;
    expect(added.text, 'Để mình nấu');
    expect(added.parentId, 'c-2');
  });

  test(
    'đổi tên: tên mới dùng trong nội dung chuyển khoản, tên trống bị bỏ qua',
    () {
      cubit.renameMe('  Ánh  ');
      expect(cubit.state.member(cubit.state.meId).name, 'Ánh');

      cubit.renameMe('   ');
      expect(cubit.state.member(cubit.state.meId).name, 'Ánh');

      final transfer = cubit.state.transfers.singleWhere(
        (t) => t.fromId == cubit.state.meId,
      );
      expect(cubit.transferCodeFor(transfer), startsWith('TRO12 ANH T'));
    },
  );

  test('đặt và gỡ tài khoản nhận tiền chỉ đổi hồ sơ của mình', () {
    final me = cubit.state.meId;
    final othersBefore = [
      for (final m in cubit.state.group.members)
        if (m.id != me) m.bank?.accountNumber,
    ];

    cubit.setMyBank(
      const BankAccount(
        bin: '970436',
        bankName: 'Vietcombank',
        accountNumber: '123456789',
        holderName: 'NGUYEN VAN AN',
      ),
    );
    expect(cubit.state.member(me).bank?.bankName, 'Vietcombank');

    cubit.setMyBank(null);
    expect(cubit.state.member(me).bank, isNull);
    expect([
      for (final m in cubit.state.group.members)
        if (m.id != me) m.bank?.accountNumber,
    ], othersBefore);
    expect(cubit.state.myNet, -266000);
  });

  test('đặt và gỡ ảnh đại diện, giữ nguyên tên và tài khoản', () {
    final me = cubit.state.meId;
    final bytes = Uint8List.fromList([1, 2, 3]);

    cubit.setMyAvatar(bytes);
    expect(cubit.state.member(me).avatarBytes, bytes);
    expect(cubit.state.member(me).bank?.bankName, 'MB Bank');

    cubit.renameMe('Ánh');
    expect(cubit.state.member(me).avatarBytes, bytes);

    cubit.setMyAvatar(null);
    expect(cubit.state.member(me).avatarBytes, isNull);
    expect(cubit.state.member(me).name, 'Ánh');
  });

  test('báo đã chuyển thì chờ xác nhận; xác nhận xong mới hết nợ', () {
    final transfer = cubit.state.transfers.singleWhere(
      (t) => t.fromId == cubit.state.meId,
    );

    cubit.markTransferred(transfer);
    final pending = cubit.state.pendingFor(transfer);
    expect(pending, isNotNull);
    expect(pending!.transferCode, 'TRO12 AN T${DateTime.now().month}');
    expect(cubit.state.myNet, -266000);

    cubit.markTransferred(transfer);
    expect(
      cubit.state.settlements.where(
        (s) => s.status == SettlementStatus.pending,
      ),
      hasLength(1),
    );

    cubit.confirmReceived(pending.id);
    expect(cubit.state.myNet, 0);
  });
}
