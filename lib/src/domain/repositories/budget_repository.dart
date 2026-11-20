import '../entities/budget.dart';

abstract interface class BudgetRepository {
  Future<List<Budget>> load();

  /// Ghi mức của một tháng, thay mức cũ của tháng đó nếu có.
  Future<void> save(Budget budget);
}
