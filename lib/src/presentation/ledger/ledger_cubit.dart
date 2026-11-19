import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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
    this.loadFailed = false,
  });

  const LedgerState.loading()
    : isLoading = true,
      loadFailed = false,
      me = const Member(id: '', name: ''),
      ledgers = const [],
      currentGroupId = '';

  /// Lần tải đầu tiên không thành công (thường do mất mạng); chưa có gì để hiện.
  const LedgerState.loadFailed()
    : isLoading = false,
      loadFailed = true,
      me = const Member(id: '', name: ''),
      ledgers = const [],
      currentGroupId = '';

  final bool isLoading;
  final bool loadFailed;

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

  /// Tài khoản mới chưa đặt tên; cần hỏi tên trước khi vào app.
  bool get needsName => !isLoading && !loadFailed && me.name.trim().isEmpty;

  /// `false` khi người dùng chưa ở nhóm nào (mới đăng ký hoặc đã rời hết).
  bool get hasGroup => ledgers.isNotEmpty;

  /// Nhóm đang mở.
  Group get group => _current.group;

  /// Khoản chi của nhóm đang mở, mới nhất đứng đầu.
  List<Expense> get expenses => _current.expenses;
  List<Settlement> get settlements => _current.settlements;

  /// Hồ sơ của một người trong nhóm đang mở, kể cả người đã rời nhóm.
  Member member(String id) {
    if (id == meId) return me;
    for (final m in group.members.followedBy(group.formerMembers)) {
      if (m.id == id) return m;
    }
    return Member(id: id, name: 'Người cũ');
  }

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

/// Kết quả vào nhóm bằng mã mời.
enum JoinGroupResult {
  joined,

  /// Không có nhóm nào dùng mã này.
  notFound,

  /// Không gọi được máy chủ.
  failed,
}

/// Trạng thái các nhóm của người dùng và sổ chi tiêu của nhóm đang mở.
///
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

  /// Phát một sự kiện mỗi khi một thay đổi không ghi được lên máy chủ.
  Stream<void> get saveFailures => _saveFailures.stream;

  /// Các lần ghi đang chờ, chạy lần lượt để giữ đúng thứ tự (ví dụ bình luận
  /// chỉ ghi sau khi khoản chi của nó đã ghi xong).
  Future<void> _writes = Future.value();

  String _newId() => newUuid(_random);

  @override
  Future<void> close() async {
    await _saveFailures.close();
    return super.close();
  }

  /// Tải hồ sơ và mọi nhóm của người dùng. [openGroupId] là nhóm muốn mở sau
  /// khi tải; mặc định giữ nhóm đang mở.
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

  /// Thử tải lại sau khi lần tải đầu không thành công.
  Future<void> retryLoad() {
    emit(const LedgerState.loading());
    return load();
  }

  /// Lấy dữ liệu mới nhất từ máy chủ, ví dụ khi quay lại app. Với dữ liệu mẫu
  /// thì không làm gì, vì tải lại sẽ xóa các thay đổi đang giữ trong bộ nhớ.
  Future<void> refresh() async {
    if (!_repository.persists || state.isLoading || state.loadFailed) return;
    // Chờ các lần ghi đang dở để không tải về bản cũ hơn giao diện.
    await _writes;
    await load();
  }

  /// Về trạng thái chưa tải, dùng khi đăng xuất.
  void reset() => emit(const LedgerState.loading());

  /// Ghi một thay đổi lên máy chủ sau khi giao diện đã cập nhật.
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

  /// Vào nhóm bằng mã mời rồi mở nhóm đó.
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

  /// Ghi một khoản do chính người dùng trả, chia đều cho [participantIds].
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
    final expense = state.expenses.firstWhere((e) => e.id == expenseId);
    final current = expense.reactions[state.meId];
    setReaction(expenseId, current == emoji ? null : emoji);
  }

  /// Đặt cảm xúc của người dùng cho một khoản chi; `null` để gỡ.
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

  /// Đổi tên nhóm đang mở. Bỏ qua tên trống.
  void renameGroup(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || !state.hasGroup) return;
    final groupId = state.currentGroupId;
    emit(state.copyWith(group: state.group.copyWith(name: trimmed)));
    _save(() => _repository.renameGroup(groupId, trimmed));
  }

  /// Rời nhóm đang mở rồi mở nhóm còn lại đầu tiên (nếu có).
  ///
  /// Trả về `false` và không làm gì khi còn khoản chưa sòng phẳng.
  bool leaveGroup() {
    if (!state.canLeaveGroup) return false;
    final groupId = state.currentGroupId;
    _closeCurrentGroup();
    _save(() => _repository.leaveGroup(groupId));
    return true;
  }

  /// Xóa nhóm đang mở với mọi thành viên, rồi mở nhóm còn lại đầu tiên.
  ///
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

  /// Tạo nhóm mới chỉ có người dùng, rồi mở luôn nhóm đó.
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
    _saveProfile();
  }

  /// Đặt tài khoản nhận tiền của người dùng; `null` để gỡ.
  void setMyBank(BankAccount? bank) {
    _updateMe((me) => me.withBank(bank));
    _saveProfile();
  }

  void _saveProfile() {
    final me = state.me;
    _save(() => _repository.saveProfile(me));
  }

  /// Đặt ảnh đại diện của người dùng; `null` để gỡ.
  void setMyAvatar(Uint8List? bytes) {
    _updateMe((me) => me.withAvatar(bytes));
    _save(() => _repository.setAvatar(bytes));
  }

  /// Nội dung chuyển khoản riêng cho khoản [transfer].
  String transferCodeFor(Transfer transfer) => buildTransferCode(
    groupCode: state.group.code,
    payerName: state.member(transfer.fromId).name,
    month: DateTime.now().month,
  );

  /// Người nợ báo đã chuyển; khoản này chờ người nhận xác nhận.
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
    _save(() => _repository.confirmSettlement(settlementId));
  }
}
