import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/domain/entities/expense.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/domain/entities/settlement.dart';
import 'package:tach/src/domain/repositories/group_repository.dart';
import 'package:tach/src/presentation/ledger/ledger_cubit.dart';

class _FakeServer implements GroupRepository {
  static const me = Member(id: 'u-an', name: 'An');
  static const minh = Member(id: 'u-minh', name: 'Minh');

  final calls = <String>[];
  var offline = false;
  var loads = 0;

  final groups = <String, GroupSnapshot>{
    'g-1': const GroupSnapshot(
      group: Group(
        id: 'g-1',
        name: 'Trọ 12',
        code: 'TRO12',
        type: GroupType.room,
        inviteCode: 'K7M2QP',
        createdBy: 'u-an',
        members: [me, minh],
      ),
    ),
  };

  static const _friends = GroupSnapshot(
    group: Group(
      id: 'g-2',
      name: 'Đà Lạt',
      code: 'DALAT',
      type: GroupType.trip,
      inviteCode: 'DL2026',
      createdBy: 'u-minh',
      members: [minh, me],
    ),
  );

  Future<void> _call(String name) async {
    // Nhường lượt như một lần gọi mạng thật.
    await Future<void>.delayed(Duration.zero);
    if (offline) throw Exception('Mất mạng');
    calls.add(name);
  }

  @override
  bool get persists => true;

  /// Các nhóm đang được theo dõi; rỗng khi không ai nghe.
  var watched = <String>{};
  final _changes = StreamController<void>.broadcast();

  void changeFromSomeoneElse() => _changes.add(null);

  @override
  Stream<void> watchGroups(Set<String> groupIds) {
    late final StreamController<void> forwarded;
    StreamSubscription<void>? source;
    forwarded = StreamController<void>(
      onListen: () {
        watched = groupIds;
        source = _changes.stream.listen(forwarded.add);
      },
      onCancel: () async {
        watched = {};
        await source?.cancel();
      },
    );
    return forwarded.stream;
  }

  @override
  Future<LedgerSnapshot> load() async {
    await Future<void>.delayed(Duration.zero);
    if (offline) throw Exception('Mất mạng');
    loads++;
    return LedgerSnapshot(me: me, groups: groups.values.toList());
  }

  @override
  Future<void> createGroup(Group group) async {
    await _call('createGroup ${group.name}');
    groups[group.id] = GroupSnapshot(group: group);
  }

  @override
  Future<String?> joinGroup(String inviteCode) async {
    await _call('joinGroup $inviteCode');
    if (inviteCode != _friends.group.inviteCode) return null;
    groups[_friends.group.id] = _friends;
    return _friends.group.id;
  }

  @override
  Future<void> renameGroup(String groupId, String name) =>
      _call('renameGroup $name');

  @override
  Future<void> leaveGroup(String groupId) async {
    await _call('leaveGroup $groupId');
    groups.remove(groupId);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _call('deleteGroup $groupId');
    groups.remove(groupId);
  }

  @override
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _call('deleteExpense');
    final group = groups[groupId]!;
    groups[groupId] = GroupSnapshot(
      group: group.group,
      expenses: [
        for (final e in group.expenses)
          if (e.id != expenseId) e,
      ],
      settlements: group.settlements,
    );
  }

  @override
  Future<void> addExpense(String groupId, Expense expense) async {
    await _call('addExpense ${expense.note}');
    final group = groups[groupId]!;
    groups[groupId] = GroupSnapshot(
      group: group.group,
      expenses: [...group.expenses, expense],
      settlements: group.settlements,
    );
  }

  @override
  Future<void> setReaction(String expenseId, String? emoji) =>
      _call('setReaction $emoji');

  @override
  Future<void> addComment(String expenseId, Comment comment) =>
      _call('addComment ${comment.text}');

  @override
  Future<void> saveProfile(Member me) => _call('saveProfile ${me.name}');

  @override
  Future<void> setAvatar(Uint8List? bytes) => _call('setAvatar');

  @override
  Future<void> addSettlement(String groupId, Settlement settlement) =>
      _call('addSettlement ${settlement.amount}');

  @override
  Future<void> confirmSettlement(String settlementId) =>
      _call('confirmSettlement');
}

void main() {
  late _FakeServer server;
  late LedgerCubit cubit;

  setUp(() async {
    server = _FakeServer();
    cubit = LedgerCubit(server);
    await cubit.load();
  });

  tearDown(() => cubit.close());

  Future<void> settle() => pumpEventQueue();

  test('mỗi thay đổi hiện ngay rồi ghi lên máy chủ theo đúng thứ tự', () async {
    final expense = cubit.addExpense(
      amount: 30000,
      note: 'Trứng',
      participantIds: ['u-an', 'u-minh'],
    );
    cubit
      ..setReaction(expense.id, '👍')
      ..addComment(expense.id, 'Rẻ ghê')
      ..renameGroup('Trọ 12A')
      ..renameMe('An Nguyễn');

    expect(cubit.state.expenses.single.comments.single.text, 'Rẻ ghê');
    expect(cubit.state.group.name, 'Trọ 12A');
    expect(server.calls, isEmpty);

    await settle();
    expect(server.calls, [
      'addExpense Trứng',
      'setReaction 👍',
      'addComment Rẻ ghê',
      'renameGroup Trọ 12A',
      'saveProfile An Nguyễn',
    ]);
  });

  test('id của khoản chi, bình luận và nhóm là UUID để máy chủ nhận', () {
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final expense = cubit.addExpense(
      amount: 1000,
      note: '',
      participantIds: ['u-an'],
    );
    cubit.addComment(expense.id, 'a');
    final group = cubit.createGroup(name: 'Mới', type: GroupType.family);

    expect(expense.id, matches(uuid));
    expect(
      cubit.state.ledgers.first.expenses.single.comments.single.id,
      matches(uuid),
    );
    expect(group.id, matches(uuid));
  });

  test('ghi không được: báo lỗi và quay về dữ liệu trên máy chủ', () async {
    var failures = 0;
    final subscription = cubit.saveFailures.listen((_) => failures++);
    addTearDown(subscription.cancel);

    server.offline = true;
    cubit.addExpense(amount: 30000, note: 'Trứng', participantIds: ['u-an']);
    expect(cubit.state.expenses, hasLength(1));

    await settle();
    expect(failures, 1);
    // Mất mạng nên chưa tải lại được; giao diện giữ nguyên, không trắng màn.
    expect(cubit.state.loadFailed, isFalse);
    expect(cubit.state.hasGroup, isTrue);

    server.offline = false;
    cubit.renameGroup('Trọ 12A');
    await settle();
    await cubit.refresh();
    expect(cubit.state.expenses, isEmpty);
    expect(server.calls, ['renameGroup Trọ 12A']);
  });

  test('lần tải đầu thất bại thì báo, thử lại được', () async {
    final offline = _FakeServer()..offline = true;
    final fresh = LedgerCubit(offline);
    addTearDown(fresh.close);

    await fresh.load();
    expect(fresh.state.loadFailed, isTrue);
    expect(fresh.state.needsName, isFalse);

    offline.offline = false;
    await fresh.retryLoad();
    expect(fresh.state.loadFailed, isFalse);
    expect(fresh.state.group.name, 'Trọ 12');
  });

  test('vào nhóm bằng mã mời: mở luôn nhóm mới, sai mã thì báo', () async {
    expect(await cubit.joinGroup('abcdef'), JoinGroupResult.notFound);
    expect(cubit.state.groups, hasLength(1));

    expect(await cubit.joinGroup(' dl2026 '), JoinGroupResult.joined);
    expect(cubit.state.groups.map((g) => g.name), ['Trọ 12', 'Đà Lạt']);
    expect(cubit.state.group.name, 'Đà Lạt');

    server.offline = true;
    expect(await cubit.joinGroup('DL2026'), JoinGroupResult.failed);
  });

  test('tải lại giữ nguyên nhóm đang mở và chờ các lần ghi dở', () async {
    await cubit.joinGroup('DL2026');
    cubit
      ..switchGroup('g-2')
      ..addExpense(amount: 50000, note: 'Xăng', participantIds: ['u-an']);

    await cubit.refresh();
    expect(cubit.state.group.name, 'Đà Lạt');
    // Khoản vừa ghi đã lên máy chủ trước khi tải lại nên không bị mất.
    expect(cubit.state.expenses.single.note, 'Xăng');
  });

  test(
    'xóa khoản vừa ghi: xóa trên máy chủ sau khi khoản đã ghi xong',
    () async {
      final expense = cubit.addExpense(
        amount: 30000,
        note: 'Trứng',
        participantIds: ['u-an', 'u-minh'],
      );
      cubit.deleteExpense(expense.id);
      expect(cubit.state.expenses, isEmpty);

      await settle();
      expect(server.calls, ['addExpense Trứng', 'deleteExpense']);
      expect(server.groups['g-1']!.expenses, isEmpty);
    },
  );

  test('người khác ghi khoản chi: tự tải lại, vài tín hiệu liền nhau chỉ tải một lần', () async {
    await settle();
    expect(server.watched, {'g-1'});
    final loadsBefore = server.loads;

    final group = server.groups['g-1']!;
    server.groups['g-1'] = GroupSnapshot(
      group: group.group,
      expenses: [
        Expense(
          id: 'e-minh',
          payerId: 'u-minh',
          amount: 30000,
          note: 'Trứng',
          splits: const {'u-an': 15000, 'u-minh': 15000},
          createdAt: DateTime(2026, 11, 19),
        ),
      ],
    );
    server
      ..changeFromSomeoneElse()
      ..changeFromSomeoneElse()
      ..changeFromSomeoneElse();
    expect(cubit.state.expenses, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(cubit.state.expenses.single.note, 'Trứng');
    expect(cubit.state.myNet, -15000);
    expect(server.loads, loadsBefore + 1);
  });

  test('vào thêm nhóm thì theo dõi cả nhóm mới, đăng xuất thì ngừng', () async {
    await settle();
    expect(server.watched, {'g-1'});

    await cubit.joinGroup('DL2026');
    await settle();
    expect(server.watched, {'g-1', 'g-2'});

    cubit.reset();
    await settle();
    expect(server.watched, isEmpty);
  });

  test('rời nhóm và xóa nhóm gọi đúng hàm trên máy chủ', () async {
    expect(cubit.leaveGroup(), isTrue);
    await settle();
    expect(server.calls, ['leaveGroup g-1']);
    expect(cubit.state.hasGroup, isFalse);

    final group = cubit.createGroup(name: 'Nhà', type: GroupType.family);
    expect(cubit.deleteGroup(), isTrue);
    await settle();
    expect(server.calls.sublist(1), [
      'createGroup Nhà',
      'deleteGroup ${group.id}',
    ]);
  });

  test('đăng xuất: về trạng thái chưa tải', () {
    cubit.reset();
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.hasGroup, isFalse);
  });
}
