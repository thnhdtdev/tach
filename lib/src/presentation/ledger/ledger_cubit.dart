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

class LedgerState {
  const LedgerState({
    required this.isLoading,
    required this.group,
    required this.meId,
    required this.expenses,
    required this.settlements,
  });

  const LedgerState.loading()
    : isLoading = true,
      group = const Group(id: '', name: '', code: '', members: []),
      meId = '',
      expenses = const [],
      settlements = const [];

  final bool isLoading;
  final Group group;
  final String meId;

  /// Khoản chi của nhóm, mới nhất đứng đầu.
  final List<Expense> expenses;
  final List<Settlement> settlements;

  Member member(String id) => group.members.firstWhere((m) => m.id == id);

  /// Tên hiển thị: chính mình thì gọi là "Bạn".
  String displayName(String id) => id == meId ? 'Bạn' : member(id).name;

  Color toneOf(String id) {
    final index = group.members.indexWhere((m) => m.id == id);
    return TachColors.avatarTones[index % TachColors.avatarTones.length];
  }

  Map<String, int> get net => netBalances(
    memberIds: group.members.map((m) => m.id),
    expenses: expenses,
    settlements: settlements,
  );

  /// Các lần chuyển khoản còn lại sau khi gộp nợ chéo.
  List<Transfer> get transfers => simplifyDebts(net);

  int get myNet => net[meId] ?? 0;

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

  LedgerState copyWith({
    Group? group,
    List<Expense>? expenses,
    List<Settlement>? settlements,
  }) {
    return LedgerState(
      isLoading: isLoading,
      group: group ?? this.group,
      meId: meId,
      expenses: expenses ?? this.expenses,
      settlements: settlements ?? this.settlements,
    );
  }
}

/// Trạng thái sổ chi tiêu của nhóm đang mở.
///
/// Thay đổi hiện chỉ giữ trong bộ nhớ; khi có Supabase sẽ ghi qua repository.
class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this._repository) : super(const LedgerState.loading());

  final GroupRepository _repository;
  var _localId = 0;

  String _newId(String prefix) => '$prefix-local-${_localId++}';

  Future<void> load() async {
    final snapshot = await _repository.loadCurrentGroup();
    if (isClosed) return;
    emit(
      LedgerState(
        isLoading: false,
        group: snapshot.group,
        meId: snapshot.currentUserId,
        expenses: [...snapshot.expenses]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        settlements: snapshot.settlements,
      ),
    );
  }

  /// Ghi một khoản do chính người dùng trả, chia đều cho [participantIds].
  Expense addExpense({
    required int amount,
    required String note,
    required List<String> participantIds,
    String? photoUrl,
  }) {
    final expense = Expense(
      id: _newId('e'),
      payerId: state.meId,
      amount: amount,
      note: note,
      photoUrl: photoUrl,
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

  void _updateMe(Member Function(Member) change) {
    emit(
      state.copyWith(
        group: state.group.copyWith(
          members: [
            for (final m in state.group.members)
              if (m.id == state.meId) change(m) else m,
          ],
        ),
      ),
    );
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
