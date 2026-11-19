import 'dart:typed_data';

import '../entities/expense.dart';
import '../entities/group.dart';
import '../entities/settlement.dart';

/// Một nhóm cùng sổ chi tiêu của nó.
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

/// Hồ sơ người dùng và mọi nhóm họ đang tham gia, theo thứ tự vào nhóm.
class LedgerSnapshot {
  const LedgerSnapshot({required this.me, required this.groups});

  final Member me;
  final List<GroupSnapshot> groups;
}

/// Nơi lưu dữ liệu nhóm: bản dữ liệu mẫu trong bộ nhớ hoặc Supabase.
///
/// Giao diện tự cập nhật trước rồi mới gọi các hàm ghi ở đây, nên hàm ghi chỉ
/// cần báo lỗi (ném ngoại lệ) khi không lưu được.
abstract interface class GroupRepository {
  /// `false` với dữ liệu mẫu: thay đổi chỉ sống trong bộ nhớ, tải lại sẽ mất.
  bool get persists;

  Future<LedgerSnapshot> load();

  Future<void> createGroup(Group group);

  /// Vào nhóm bằng mã mời. Trả về id nhóm, hoặc `null` nếu không có nhóm nào
  /// dùng mã này.
  Future<String?> joinGroup(String inviteCode);

  Future<void> renameGroup(String groupId, String name);
  Future<void> leaveGroup(String groupId);
  Future<void> deleteGroup(String groupId);

  /// Lưu khoản chi; ảnh trong [Expense.photoBytes] được nén rồi tải lên.
  Future<void> addExpense(String groupId, Expense expense);

  /// Đặt cảm xúc của người dùng cho một khoản chi; `null` để gỡ.
  Future<void> setReaction(String expenseId, String? emoji);
  Future<void> addComment(String expenseId, Comment comment);

  /// Lưu tên và tài khoản nhận tiền của người dùng.
  Future<void> saveProfile(Member me);

  /// Đặt ảnh đại diện của người dùng; `null` để gỡ.
  Future<void> setAvatar(Uint8List? bytes);

  Future<void> addSettlement(String groupId, Settlement settlement);
  Future<void> confirmSettlement(String settlementId);
}
