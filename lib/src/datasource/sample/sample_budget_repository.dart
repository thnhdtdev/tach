import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

/// Giữ hũ trong bộ nhớ, dùng cho dữ liệu mẫu và test.
class SampleBudgetRepository implements BudgetRepository {
  final _budgets = <Budget>[];

  @override
  Future<List<Budget>> load() async => [..._budgets];

  @override
  Future<void> save(Budget budget) async {
    _budgets
      ..removeWhere((b) => b.period == budget.period)
      ..add(budget);
  }
}
