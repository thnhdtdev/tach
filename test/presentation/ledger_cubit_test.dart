import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/datasource/sample/sample_group_repository.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/domain/entities/settlement.dart';
import 'package:tach/src/domain/repositories/group_repository.dart';
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

  test('xóa khoản mình ghi: khoản mất khỏi bảng tin, số dư tính lại', () {
    final before = cubit.state.myNet;
    final mine = cubit.state.expenses.firstWhere(
      (e) => e.payerId == cubit.state.meId,
    );
    final count = cubit.state.expenses.length;

    cubit.deleteExpense(mine.id);

    expect(cubit.state.expenses, hasLength(count - 1));
    expect(cubit.state.expenses.any((e) => e.id == mine.id), isFalse);
    final owedToMe = mine.amount - (mine.splits[cubit.state.meId] ?? 0);
    expect(cubit.state.myNet, before - owedToMe);
  });

  test('khoản người khác ghi thì không xóa được', () {
    final theirs = cubit.state.expenses.firstWhere(
      (e) => e.payerId != cubit.state.meId,
    );
    final count = cubit.state.expenses.length;

    cubit.deleteExpense(theirs.id);

    expect(cubit.state.expenses, hasLength(count));
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

  test(
    'đặt cảm xúc bất kỳ từ bảng emoji, đặt lại thì thay thế, null thì gỡ',
    () {
      final id = cubit.state.expenses.first.id;
      final me = cubit.state.meId;

      cubit.setReaction(id, '🥳');
      expect(cubit.state.expenses.first.reactions[me], '🥳');
      expect(cubit.state.expenses.first.reactions, hasLength(3));

      cubit.setReaction(id, '🍳');
      expect(cubit.state.expenses.first.reactions[me], '🍳');
      expect(cubit.state.expenses.first.reactions, hasLength(3));

      cubit.setReaction(id, null);
      expect(cubit.state.expenses.first.reactions.containsKey(me), isFalse);
    },
  );

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

  group('nhiều nhóm', () {
    test('tạo nhóm: chỉ có mình, mở luôn nhóm mới, nhóm cũ giữ nguyên', () {
      final me = cubit.state.meId;
      final group = cubit.createGroup(
        name: '  Đà Lạt tháng 12  ',
        type: GroupType.trip,
      );

      expect(group.name, 'Đà Lạt tháng 12');
      expect(group.code, 'DALATTHA');
      expect(group.type, GroupType.trip);
      expect(group.inviteCode, matches(RegExp(r'^[A-HJ-KM-NP-Z2-9]{6}$')));
      expect(group.members.map((m) => m.id), [me]);

      expect(cubit.state.currentGroupId, group.id);
      expect(cubit.state.expenses, isEmpty);
      expect(cubit.state.transfers, isEmpty);
      expect(cubit.state.myNet, 0);
      expect(cubit.state.groups.map((g) => g.name), [
        'Trọ 12',
        'Đà Lạt tháng 12',
      ]);

      cubit.switchGroup('g-tro12');
      expect(cubit.state.group.name, 'Trọ 12');
      expect(cubit.state.expenses, hasLength(8));
      expect(cubit.state.myNet, -266000);
    });

    test('khoản ghi ở nhóm mới không lẫn sang nhóm cũ', () {
      final me = cubit.state.meId;
      final trip = cubit.createGroup(name: 'Đà Lạt', type: GroupType.trip);
      cubit.addExpense(amount: 50000, note: 'Xăng', participantIds: [me]);
      expect(cubit.state.expenses, hasLength(1));

      cubit.switchGroup('g-tro12');
      expect(cubit.state.expenses, hasLength(8));
      expect(cubit.state.expenses.any((e) => e.note == 'Xăng'), isFalse);

      cubit.switchGroup(trip.id);
      expect(cubit.state.expenses.single.note, 'Xăng');
    });

    test('đổi tên áp dụng cho hồ sơ ở mọi nhóm', () {
      final me = cubit.state.meId;
      cubit.createGroup(name: 'Nhà mình', type: GroupType.family);
      cubit.renameMe('Ánh');

      for (final group in cubit.state.groups) {
        expect(group.members.firstWhere((m) => m.id == me).name, 'Ánh');
      }
    });

    test('mở nhóm không tồn tại thì giữ nguyên nhóm đang mở', () {
      cubit.switchGroup('khong-co');
      expect(cubit.state.group.name, 'Trọ 12');
    });
  });

  group('đổi tên và rời nhóm', () {
    test('đổi tên nhóm giữ nguyên mã chuyển khoản, bỏ qua tên trống', () {
      cubit.renameGroup('  Nhà trọ Cầu Giấy ');
      expect(cubit.state.group.name, 'Nhà trọ Cầu Giấy');
      expect(cubit.state.group.code, 'TRO12');

      cubit.renameGroup('   ');
      expect(cubit.state.group.name, 'Nhà trọ Cầu Giấy');
    });

    test('còn nợ thì không rời nhóm được', () {
      expect(cubit.state.canLeaveGroup, isFalse);
      expect(cubit.leaveGroup(), isFalse);
      expect(cubit.state.group.name, 'Trọ 12');
      expect(cubit.state.groups, hasLength(1));
    });

    test('rời nhóm đã sòng phẳng thì mở nhóm còn lại', () {
      cubit.createGroup(name: 'Đà Lạt', type: GroupType.trip);
      expect(cubit.state.canLeaveGroup, isTrue);

      expect(cubit.leaveGroup(), isTrue);
      expect(cubit.state.groups.map((g) => g.name), ['Trọ 12']);
      expect(cubit.state.group.name, 'Trọ 12');
      expect(cubit.state.expenses, hasLength(8));
    });

    test('rời nhóm cuối cùng: không còn nhóm nhưng hồ sơ vẫn còn', () async {
      final solo = LedgerCubit(_SoloGroupRepository());
      addTearDown(solo.close);
      await solo.load();

      expect(solo.leaveGroup(), isTrue);
      expect(solo.state.hasGroup, isFalse);
      expect(solo.state.expenses, isEmpty);
      expect(solo.state.myNet, 0);
      expect(solo.state.me.name, 'An');

      solo.renameMe('Ánh');
      final group = solo.createGroup(name: 'Nhà mình', type: GroupType.family);
      expect(solo.state.group.id, group.id);
      expect(group.members.single.name, 'Ánh');
    });
  });

  group('xóa nhóm', () {
    test('nhóm còn khoản chưa trả xong thì chưa xóa được', () {
      expect(cubit.state.isGroupCreator, isTrue);
      expect(cubit.state.canDeleteGroup, isFalse);
      expect(cubit.deleteGroup(), isFalse);
      expect(cubit.state.groups, hasLength(1));
    });

    test('người tạo xóa nhóm đã sòng phẳng thì mở nhóm còn lại', () {
      final trip = cubit.createGroup(name: 'Đà Lạt', type: GroupType.trip);
      expect(trip.createdBy, cubit.state.meId);
      expect(cubit.state.canDeleteGroup, isTrue);

      expect(cubit.deleteGroup(), isTrue);
      expect(cubit.state.groups.map((g) => g.name), ['Trọ 12']);
      expect(cubit.state.group.name, 'Trọ 12');
    });

    test('nhóm vừa có khoản chi chưa chia xong thì khóa xóa lại', () async {
      final solo = LedgerCubit(_SoloGroupRepository());
      addTearDown(solo.close);
      await solo.load();
      final mine = solo.createGroup(name: 'Nhà mình', type: GroupType.family);
      expect(solo.state.canDeleteGroup, isTrue);

      solo.addExpense(amount: 50000, note: 'Rau', participantIds: ['u-an']);
      expect(solo.state.canDeleteGroup, isTrue);
      expect(solo.state.group.id, mine.id);
    });

    test('không phải người tạo thì không xóa được dù đã sòng phẳng', () async {
      final solo = LedgerCubit(_SoloGroupRepository());
      addTearDown(solo.close);
      await solo.load();

      expect(solo.state.transfers, isEmpty);
      expect(solo.state.isGroupCreator, isFalse);
      expect(solo.deleteGroup(), isFalse);
      expect(solo.state.hasGroup, isTrue);
    });
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

/// Nhóm hai người chưa có khoản chi nào, do Minh tạo. Kế thừa bản mẫu để dùng
/// lại các hàm ghi không làm gì.
class _SoloGroupRepository extends SampleGroupRepository {
  @override
  Future<LedgerSnapshot> load() async {
    const me = Member(id: 'u-an', name: 'An');
    return const LedgerSnapshot(
      me: me,
      groups: [
        GroupSnapshot(
          group: Group(
            id: 'g-solo',
            name: 'Một mình',
            code: 'MOTMINH',
            type: GroupType.room,
            inviteCode: 'ABCDEF',
            createdBy: 'u-minh',
            members: [
              me,
              Member(id: 'u-minh', name: 'Minh'),
            ],
          ),
        ),
      ],
    );
  }
}
