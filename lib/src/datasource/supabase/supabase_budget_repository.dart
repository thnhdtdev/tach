import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client);

  final SupabaseClient _client;

  String _date(DateTime period) =>
      '${period.year.toString().padLeft(4, '0')}-'
      '${period.month.toString().padLeft(2, '0')}-01';

  @override
  Future<List<Budget>> load() async {
    final rows = await _client
        .from('budgets')
        .select('period, amount, include_personal, repeats');
    return [
      for (final row in rows)
        Budget(
          period: DateTime.parse(row['period'] as String),
          amount: row['amount'] as int,
          includePersonal: row['include_personal'] as bool,
          repeats: row['repeats'] as bool,
        ),
    ];
  }

  @override
  Future<void> save(Budget budget) {
    return _client.from('budgets').upsert({
      'user_id': _client.auth.currentUser!.id,
      'period': _date(budget.period),
      'amount': budget.amount,
      'include_personal': budget.includePersonal,
      'repeats': budget.repeats,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
