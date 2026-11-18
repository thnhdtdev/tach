import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/transfer_code.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/logic/balances.dart';
import '../../domain/logic/split.dart';
import '../../domain/repositories/group_repository.dart';

/// Một nhóm cùng sổ chi tiêu của nó.
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
  });

  const LedgerState.loading()
    : isLoading = true,
      me = const Member(id: '', name: ''),
      ledgers = const [],
      currentGroupId = '';

  final bool isLoading;

  /// Hồ sơ của người dùng. Tồn tại cả khi họ chưa ở nhóm nào.
  final Member me;

  String get meId => me.id;

  /// Mọi nhóm người dùng đang tham gia, theo thứ tự vào nhóm.
  final List<GroupLedger> ledgers;
  final String currentGroupId;

  GroupLedger get _current => ledgers.firstWhere(
    (l) => l.group.id == currentGroupId,
    orElse: () => _noGroup,
  );

  List<Group> get groups => [for (final l in ledgers) l.group];

  /// `false` khi người dùng chưa ở nhóm nào (mới đăng ký hoặc đã rời hết).
  bool get hasGroup => ledgers.isNotEmpty;

  /// Nhóm đang mở.
  Group get group => _current.group;

  /// Khoản chi của nhóm đang mở, mới nhất đứng đầu.
  List<Expense> get expenses => _current.expenses;
  List<Settlement> get settlements => _current.settlements;

  Member member(String id) =>
      id == meId ? me : group.members.firstWhere((m) => m.id == id);

  /// Tên hiển thị: chính mình thì gọi là "Bạn".
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

  /// Các lần chuyển khoản còn lại sau khi gộp nợ chéo.
  List<Transfer> get transfers => simplifyDebts(net);

  int get myNet => net[meId] ?? 0;

  /// Chỉ rời được nhóm khi không còn nợ ai và không ai còn nợ mình.
  bool get canLeaveGroup => hasGroup && myNet == 0;

  /// Người dùng có phải người tạo nhóm đang mở không.
  bool get isGroupCreator => hasGroup && group.createdBy == meId;

  /// Chỉ người tạo nhóm xóa được nhóm, và chỉ khi cả nhóm đã sòng phẳng, để
  /// không ai mất dấu khoản nợ còn dang dở.
  bool get canDeleteGroup => isGroupCreator && transfers.isEmpty;

  int get totalSpent => expenses.fold(0, (sum, e) => sum + e.amount);

  /// Lần báo "đã chuyển" đang chờ xác nhận cho một khoản cần trả.
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

  /// Bản sao với thay đổi áp vào nhóm đang mở.
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

/// Trạng thái các nhóm của người dùng và sổ chi tiêu của nhóm đang mở.
///
/// Thay đổi hiện chỉ giữ trong bộ nhớ; khi có Supabase sẽ ghi qua repository.
class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this._repository, {Random? random})
    : _random = random ?? Random(),
      super(const LedgerState.loading());

  /// Bộ ký tự mã mời, bỏ các ký tự dễ đọc nhầm (0/O, 1/I/L).
  static const _inviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _inviteLength = 6;

  final GroupRepository _repository;
  final Random _random;
  var _localId = 0;

  String _newId(String prefix) => '$prefix-local-${_localId++}';

  Future<void> load() async {
    final snapshot = await _repository.loadCurrentGroup();
    if (isClosed) return;
    emit(
      LedgerState(
        isLoading: false,
        me: snapshot.group.members.firstWhere(
          (m) => m.id == snapshot.currentUserId,
        ),
        currentGroupId: snapshot.group.id,
        ledgers: [
          GroupLedger(
            group: snapshot.group,
            expenses: [...snapshot.expenses]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
            settlements: snapshot.settlements,
          ),
        ],
      ),
    );
  }

  /// Ghi một khoản do chính người dùng trả, chia đều cho [participantIds].
  Expense addExpense({
    required int amount,
    required String note,
    required List<String> participantIds,
    String? photoUrl,
    Uint8List? photoBytes,
  }) {
    final expense = Expense(
      id: _newId('e'),
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
    return expense;
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

  /// Thả cảm xúc; chạm lại đúng cảm xúc đang chọn thì gỡ.
  void toggleReaction(String expenseId, String emoji) {
    _updateExpense(expenseId, (expense) {
      final reactions = {...expense.reactions};
      if (reactions[state.meId] == emoji) {
        reactions.remove(state.meId);
      } else {
        reactions[state.meId] = emoji;
      }
      return expense.copyWith(reactions: reactions);
    });
  }

  void addComment(String expenseId, String text, {String? parentId}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _updateExpense(expenseId, (expense) {
      return expense.copyWith(
        comments: [
          ...expense.comments,
          Comment(
            id: _newId('c'),
            userId: state.meId,
            parentId: parentId,
            text: trimmed,
            createdAt: DateTime.now(),
          ),
        ],
      );
    });
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

  /// Đổi tên nhóm đang mở. Bỏ qua tên trống.
  void renameGroup(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || !state.hasGroup) return;
    emit(state.copyWith(group: state.group.copyWith(name: trimmed)));
  }

  /// Rời nhóm đang mở rồi mở nhóm còn lại đầu tiên (nếu có).
  ///
  /// Trả về `false` và không làm gì khi còn khoản chưa sòng phẳng.
  bool leaveGroup() {
    if (!state.canLeaveGroup) return false;
    _closeCurrentGroup();
    return true;
  }

  /// Xóa nhóm đang mở với mọi thành viên, rồi mở nhóm còn lại đầu tiên.
  ///
  /// Trả về `false` và không làm gì khi người dùng không phải người tạo nhóm
  /// hoặc nhóm còn khoản chưa trả xong.
  bool deleteGroup() {
    if (!state.canDeleteGroup) return false;
    _closeCurrentGroup();
    return true;
  }

  /// Bỏ nhóm đang mở khỏi danh sách. Khi chỉ giữ dữ liệu trong bộ nhớ thì rời
  /// và xóa giống nhau; với máy chủ, xóa còn gỡ nhóm ở mọi thành viên.
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

  /// Tạo nhóm mới chỉ có người dùng, rồi mở luôn nhóm đó.
  Group createGroup({required String name, required GroupType type}) {
    final trimmed = name.trim();
    final group = Group(
      id: _newId('g'),
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
    return group;
  }

  /// Mở một nhóm khác trong các nhóm đang tham gia.
  void switchGroup(String groupId) {
    if (groupId == state.currentGroupId) return;
    if (!state.ledgers.any((l) => l.group.id == groupId)) return;
    emit(state.withLedgers(state.ledgers, currentGroupId: groupId));
  }

  /// Đổi tên hiển thị của chính người dùng. Bỏ qua tên trống.
  void renameMe(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _updateMe((me) => me.copyWith(name: trimmed));
  }

  /// Đặt tài khoản nhận tiền của người dùng; `null` để gỡ.
  void setMyBank(BankAccount? bank) => _updateMe((me) => me.withBank(bank));

  /// Đặt ảnh đại diện của người dùng; `null` để gỡ.
  void setMyAvatar(Uint8List? bytes) => _updateMe((me) => me.withAvatar(bytes));

  /// Nội dung chuyển khoản riêng cho khoản [transfer].
  String transferCodeFor(Transfer transfer) => buildTransferCode(
    groupCode: state.group.code,
    payerName: state.member(transfer.fromId).name,
    month: DateTime.now().month,
  );

  /// Người nợ báo đã chuyển; khoản này chờ người nhận xác nhận.
  void markTransferred(Transfer transfer) {
    if (state.pendingFor(transfer) != null) return;
    emit(
      state.copyWith(
        settlements: [
          ...state.settlements,
          Settlement(
            id: _newId('s'),
            fromId: transfer.fromId,
            toId: transfer.toId,
            amount: transfer.amount,
            transferCode: transferCodeFor(transfer),
            status: SettlementStatus.pending,
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
  }

  /// Người nhận xác nhận đã nhận tiền.
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
  }
}
