import '../entities/expense.dart';
import '../entities/group.dart';
import '../entities/settlement.dart';

/// Toàn bộ dữ liệu của nhóm đang mở.
class GroupSnapshot {
  const GroupSnapshot({
    required this.group,
    required this.currentUserId,
    required this.expenses,
    required this.settlements,
  });

  final Group group;
  final String currentUserId;
  final List<Expense> expenses;
  final List<Settlement> settlements;
}

/// Nguồn dữ liệu nhóm. Hiện có bản dữ liệu mẫu; bản Supabase sẽ thay vào sau.
abstract interface class GroupRepository {
  Future<GroupSnapshot> loadCurrentGroup();
}
