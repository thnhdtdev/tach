import 'dart:typed_data';

import '../entities/expense.dart';
import '../entities/group.dart';
import '../entities/settlement.dart';

class GroupSnapshot {
  const GroupSnapshot({
    required this.group,
    this.expenses = const [],
    this.settlements = const [],
  });

  final Group group;
  final List<Expense> expenses;
  final List<Settlement> settlements;
}

class LedgerSnapshot {
  const LedgerSnapshot({required this.me, required this.groups});

  final Member me;
  final List<GroupSnapshot> groups;
}

/// Giao diện tự cập nhật trước rồi mới gọi các hàm ghi ở đây, nên hàm ghi chỉ
/// cần báo lỗi (ném ngoại lệ) khi không lưu được.
abstract interface class GroupRepository {
  /// `false` với dữ liệu mẫu: thay đổi chỉ sống trong bộ nhớ, tải lại sẽ mất.
  bool get persists;

  Future<LedgerSnapshot> load();

  Future<void> createGroup(Group group);

  /// Trả về id nhóm, hoặc `null` nếu không có nhóm nào dùng mã này.
  Future<String?> joinGroup(String inviteCode);

  Future<void> renameGroup(String groupId, String name);
  Future<void> leaveGroup(String groupId);
  Future<void> deleteGroup(String groupId);

  Future<void> addExpense(String groupId, Expense expense);
  Future<void> deleteExpense(String groupId, String expenseId);

  Future<void> setReaction(String expenseId, String? emoji);
  Future<void> addComment(String expenseId, Comment comment);

  Future<void> saveProfile(Member me);

  Future<void> setAvatar(Uint8List? bytes);

  Future<void> addSettlement(String groupId, Settlement settlement);
  Future<void> confirmSettlement(String settlementId);
}
