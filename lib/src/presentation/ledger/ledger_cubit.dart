import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/transfer_code.dart';
import '../../core/ids/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/logic/balances.dart';
import '../../domain/logic/split.dart';
import '../../domain/repositories/group_repository.dart';

class GroupLedger {
  const GroupLedger({
    required this.group,
    this.expenses = const [],
    this.settlements = const [],
  });

  final Group group;

  /// Khoản chi của nhóm, mới nhất đứng đầu.
  final List<Expense> expenses;
  final List<Settlement> settlements;
}

const _noGroup = GroupLedger(
  group: Group(
    id: '',
    name: '',
    code: '',
    type: GroupType.room,
    inviteCode: '',
    createdBy: '',
    members: [],
  ),
);

class LedgerState {
  const LedgerState({
    required this.isLoading,
    required this.me,
    required this.ledgers,
    required this.currentGroupId,
    this.loadFailed = false,
  });

  const LedgerState.loading()
    : isLoading = true,
      loadFailed = false,
      me = const Member(id: '', name: ''),
      ledgers = const [],
      currentGroupId = '';

  const LedgerState.loadFailed()
    : isLoading = false,
      loadFailed = true,
      me = const Member(id: '', name: ''),
      ledgers = const [],
      currentGroupId = '';

  final bool isLoading;
  final bool loadFailed;

  final Member me;

  String get meId => me.id;

  final List<GroupLedger> ledgers;
  final String currentGroupId;

  GroupLedger get _current => ledgers.firstWhere(
    (l) => l.group.id == currentGroupId,
    orElse: () => _noGroup,
  );

  List<Group> get groups => [for (final l in ledgers) l.group];

  bool get needsName => !isLoading && !loadFailed && me.name.trim().isEmpty;

  bool get hasGroup => ledgers.isNotEmpty;

  Group get group => _current.group;

  List<Expense> get expenses => _current.expenses;
  List<Settlement> get settlements => _current.settlements;

  Member member(String id) {
    if (id == meId) return me;
    for (final m in group.members.followedBy(group.formerMembers)) {
      if (m.id == id) return m;
    }
    return Member(id: id, name: 'Người cũ');
  }

  String displayName(String id) => id == meId ? 'Bạn' : member(id).name;

  Color toneOf(String id) {
    final index = group.members.indexWhere((m) => m.id == id);
    final slot = index < 0 ? 0 : index % TachColors.avatarTones.length;
    return TachColors.avatarTones[slot];
  }

  Map<String, int> get net => netBalances(
    memberIds: group.members.map((m) => m.id),
    expenses: expenses,
    settlements: settlements,
  );

  List<Transfer> get transfers => simplifyDebts(net);

  int get myNet => net[meId] ?? 0;

  bool get canLeaveGroup => hasGroup && myNet == 0;

  bool get isGroupCreator => hasGroup && group.createdBy == meId;

  /// Chỉ người tạo nhóm xóa được nhóm, và chỉ khi cả nhóm đã sòng phẳng, để
  /// không ai mất dấu khoản nợ còn dang dở.
  bool get canDeleteGroup => isGroupCreator && transfers.isEmpty;

  int get totalSpent => expenses.fold(0, (sum, e) => sum + e.amount);

  Settlement? pendingFor(Transfer transfer) {
    for (final s in settlements) {
      if (s.status == SettlementStatus.pending &&
          s.fromId == transfer.fromId &&
          s.toId == transfer.toId) {
        return s;
      }
    }
    return null;
  }

  LedgerState copyWith({
    Group? group,
    List<Expense>? expenses,
    List<Settlement>? settlements,
  }) {
    final current = _current;
    return withLedgers([
      for (final l in ledgers)
        if (l.group.id == currentGroupId)
          GroupLedger(
            group: group ?? current.group,
            expenses: expenses ?? current.expenses,
            settlements: settlements ?? current.settlements,
          )
        else
          l,
    ]);
  }

  LedgerState withLedgers(
    List<GroupLedger> ledgers, {
    String? currentGroupId,
    Member? me,
  }) {
    return LedgerState(
      isLoading: isLoading,
      me: me ?? this.me,
      ledgers: ledgers,
      currentGroupId: currentGroupId ?? this.currentGroupId,
    );
  }
}

enum JoinGroupResult { joined, notFound, failed }

/// Mỗi thay đổi hiện ngay trên giao diện rồi mới ghi qua [GroupRepository].
/// Ghi không được thì báo qua [saveFailures] và tải lại để về đúng dữ liệu
/// đang có trên máy chủ.
class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this._repository, {Random? random})
    : _random = random ?? Random(),
      super(const LedgerState.loading());

  /// Bộ ký tự mã mời, bỏ các ký tự dễ đọc nhầm (0/O, 1/I/L).
  static const _inviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _inviteLength = 6;

  final GroupRepository _repository;
  final Random _random;

  final _saveFailures = StreamController<void>.broadcast();

  Stream<void> get saveFailures => _saveFailures.stream;

  /// Các lần ghi đang chờ, chạy lần lượt để giữ đúng thứ tự (ví dụ bình luận
  /// chỉ ghi sau khi khoản chi của nó đã ghi xong).
  Future<void> _writes = Future.value();

  String _newId() => newUuid(_random);

  @override
  Future<void> close() async {
    _refreshTimer?.cancel();
    await _groupChanges?.cancel();
    await _saveFailures.close();
    return super.close();
  }

  StreamSubscription<void>? _groupChanges;
  var _watchedGroups = const <String>{};
  var _watching = Future<void>.value();
  Timer? _refreshTimer;

  @override
  void onChange(Change<LedgerState> change) {
    super.onChange(change);
    final ids = {
      for (final ledger in change.nextState.ledgers) ledger.group.id,
    };
    if (!setEquals(ids, _watchedGroups)) _watch(ids);
  }

  void _watch(Set<String> groupIds) {
    _watchedGroups = groupIds;
    _watching = _watching.then((_) async {
      // Nhóm vừa tạo phải ghi xong lên máy chủ thì mới được phép theo dõi.
      await _writes;
      await _groupChanges?.cancel();
      _groupChanges = null;
      final superseded = !setEquals(groupIds, _watchedGroups);
      if (isClosed || superseded || groupIds.isEmpty) return;
      _groupChanges = _repository.watchGroups(groupIds).listen((_) {
        // Một thao tác có thể phát vài tín hiệu liền nhau; gom lại tải một lần.
        _refreshTimer?.cancel();
        _refreshTimer = Timer(const Duration(milliseconds: 400), refresh);
      });
    });
  }

  Future<void> load({String? openGroupId}) async {
    final LedgerSnapshot snapshot;
    try {
      snapshot = await _repository.load();
    } on Exception {
      // Đang có dữ liệu thì giữ nguyên; chưa có gì thì báo để người dùng thử lại.
      if (!isClosed && state.isLoading) emit(const LedgerState.loadFailed());
      return;
    }
    if (isClosed) return;

    final ledgers = [
      for (final g in snapshot.groups)
        GroupLedger(
          group: g.group,
          expenses: [...g.expenses]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          settlements: g.settlements,
        ),
    ];
    bool has(String? id) => ledgers.any((l) => l.group.id == id);
    final wanted = has(openGroupId) ? openGroupId! : state.currentGroupId;
    emit(
      LedgerState(
        isLoading: false,
        me: snapshot.me,
        ledgers: ledgers,
        currentGroupId: has(wanted)
            ? wanted
            : (ledgers.isEmpty ? '' : ledgers.first.group.id),
      ),
    );
  }

  Future<void> retryLoad() {
    emit(const LedgerState.loading());
    return load();
  }

  /// Với dữ liệu mẫu thì không làm gì, vì tải lại sẽ xóa các thay đổi đang giữ
  /// trong bộ nhớ.
  Future<void> refresh() async {
    if (!_repository.persists || state.isLoading || state.loadFailed) return;
    // Chờ các lần ghi đang dở để không tải về bản cũ hơn giao diện.
    await _writes;
    await load();
  }

  void reset() => emit(const LedgerState.loading());

  void _save(Future<void> Function() write) {
    _writes = _writes.then((_) async {
      try {
        await write();
      } on Exception {
        if (isClosed) return;
        _saveFailures.add(null);
        await load();
      }
    });
  }

  Future<JoinGroupResult> joinGroup(String inviteCode) async {
    final String? groupId;
    try {
      groupId = await _repository.joinGroup(inviteCode.trim().toUpperCase());
    } on Exception {
      return JoinGroupResult.failed;
    }
    if (groupId == null) return JoinGroupResult.notFound;

    if (_repository.persists || state.isLoading) {
      await load(openGroupId: groupId);
    } else {
      switchGroup(groupId);
    }
    return JoinGroupResult.joined;
  }

  Expense addExpense({
    required int amount,
    required String note,
    required List<String> participantIds,
    String? photoUrl,
    Uint8List? photoBytes,
  }) {
    final groupId = state.currentGroupId;
    final expense = Expense(
      id: _newId(),
      payerId: state.meId,
      amount: amount,
      note: note,
      photoUrl: photoUrl,
      photoBytes: photoBytes,
      splits: splitEqually(
        amount: amount,
        participantIds: participantIds,
        payerId: state.meId,
      ),
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(expenses: [expense, ...state.expenses]));
    _save(() => _repository.addExpense(groupId, expense));
    return expense;
  }

  /// Chỉ người ghi khoản chi mới xóa được nó.
  void deleteExpense(String expenseId) {
    final mine = state.expenses.any(
      (e) => e.id == expenseId && e.payerId == state.meId,
    );
    if (!mine) return;
    final groupId = state.currentGroupId;
    emit(
      state.copyWith(
        expenses: [
          for (final e in state.expenses)
            if (e.id != expenseId) e,
        ],
      ),
    );
    _save(() => _repository.deleteExpense(groupId, expenseId));
  }

  void _updateExpense(String id, Expense Function(Expense) change) {
    emit(
      state.copyWith(
        expenses: [
          for (final e in state.expenses)
            if (e.id == id) change(e) else e,
        ],
      ),
    );
  }

  void toggleReaction(String expenseId, String emoji) {
    final expense = state.expenses.firstWhere((e) => e.id == expenseId);
    final current = expense.reactions[state.meId];
    setReaction(expenseId, current == emoji ? null : emoji);
  }

  void setReaction(String expenseId, String? emoji) {
    _updateExpense(expenseId, (expense) {
      final reactions = {...expense.reactions};
      if (emoji == null) {
        reactions.remove(state.meId);
      } else {
        reactions[state.meId] = emoji;
      }
      return expense.copyWith(reactions: reactions);
    });
    _save(() => _repository.setReaction(expenseId, emoji));
  }

  void addComment(String expenseId, String text, {String? parentId}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final comment = Comment(
      id: _newId(),
      userId: state.meId,
      parentId: parentId,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _updateExpense(expenseId, (expense) {
      return expense.copyWith(comments: [...expense.comments, comment]);
    });
    _save(() => _repository.addComment(expenseId, comment));
  }

  /// Hồ sơ của người dùng đi theo họ ở mọi nhóm, nên sửa ở tất cả các nhóm.
  void _updateMe(Member Function(Member) change) {
    emit(
      state.withLedgers([
        for (final l in state.ledgers)
          GroupLedger(
            group: l.group.copyWith(
              members: [
                for (final m in l.group.members)
                  if (m.id == state.meId) change(m) else m,
              ],
            ),
            expenses: l.expenses,
            settlements: l.settlements,
          ),
      ], me: change(state.me)),
    );
  }

  void renameGroup(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || !state.hasGroup) return;
    final groupId = state.currentGroupId;
    emit(state.copyWith(group: state.group.copyWith(name: trimmed)));
    _save(() => _repository.renameGroup(groupId, trimmed));
  }

  /// Trả về `false` và không làm gì khi còn khoản chưa sòng phẳng.
  bool leaveGroup() {
    if (!state.canLeaveGroup) return false;
    final groupId = state.currentGroupId;
    _closeCurrentGroup();
    _save(() => _repository.leaveGroup(groupId));
    return true;
  }

  /// Trả về `false` và không làm gì khi người dùng không phải người tạo nhóm
  /// hoặc nhóm còn khoản chưa trả xong.
  bool deleteGroup() {
    if (!state.canDeleteGroup) return false;
    final groupId = state.currentGroupId;
    _closeCurrentGroup();
    _save(() => _repository.deleteGroup(groupId));
    return true;
  }

  /// Bỏ nhóm đang mở khỏi danh sách trên máy này. Rời và xóa giống nhau ở đây;
  /// trên máy chủ, xóa còn gỡ nhóm ở mọi thành viên.
  void _closeCurrentGroup() {
    final remaining = [
      for (final l in state.ledgers)
        if (l.group.id != state.currentGroupId) l,
    ];
    emit(
      state.withLedgers(
        remaining,
        currentGroupId: remaining.isEmpty ? '' : remaining.first.group.id,
      ),
    );
  }

  Group createGroup({required String name, required GroupType type}) {
    final trimmed = name.trim();
    final group = Group(
      id: _newId(),
      name: trimmed,
      code: groupCodeFromName(trimmed),
      type: type,
      inviteCode: [
        for (var i = 0; i < _inviteLength; i++)
          _inviteAlphabet[_random.nextInt(_inviteAlphabet.length)],
      ].join(),
      createdBy: state.meId,
      members: [state.me],
    );
    emit(
      state.withLedgers([
        ...state.ledgers,
        GroupLedger(group: group),
      ], currentGroupId: group.id),
    );
    _save(() => _repository.createGroup(group));
    return group;
  }

  void switchGroup(String groupId) {
    if (groupId == state.currentGroupId) return;
    if (!state.ledgers.any((l) => l.group.id == groupId)) return;
    emit(state.withLedgers(state.ledgers, currentGroupId: groupId));
  }

  void renameMe(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _updateMe((me) => me.copyWith(name: trimmed));
    _saveProfile();
  }

  void setMyBank(BankAccount? bank) {
    _updateMe((me) => me.withBank(bank));
    _saveProfile();
  }

  void _saveProfile() {
    final me = state.me;
    _save(() => _repository.saveProfile(me));
  }

  void setMyAvatar(Uint8List? bytes) {
    _updateMe((me) => me.withAvatar(bytes));
    _save(() => _repository.setAvatar(bytes));
  }

  String transferCodeFor(Transfer transfer) => buildTransferCode(
    groupCode: state.group.code,
    payerName: state.member(transfer.fromId).name,
    month: DateTime.now().month,
  );

  void markTransferred(Transfer transfer) {
    if (state.pendingFor(transfer) != null) return;
    final groupId = state.currentGroupId;
    final settlement = Settlement(
      id: _newId(),
      fromId: transfer.fromId,
      toId: transfer.toId,
      amount: transfer.amount,
      transferCode: transferCodeFor(transfer),
      status: SettlementStatus.pending,
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(settlements: [...state.settlements, settlement]));
    _save(() => _repository.addSettlement(groupId, settlement));
  }

  void confirmReceived(String settlementId) {
    emit(
      state.copyWith(
        settlements: [
          for (final s in state.settlements)
            if (s.id == settlementId)
              s.copyWith(status: SettlementStatus.confirmed)
            else
              s,
        ],
      ),
    );
    _save(() => _repository.confirmSettlement(settlementId));
  }
}
