import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

/// Các mức hũ người dùng đã đặt. Đặt mức mới thì hiện ngay rồi mới ghi; ghi
/// không được thì báo qua [saveFailures] và tải lại.
class BudgetCubit extends Cubit<List<Budget>> {
  BudgetCubit(this._repository) : super(const []);

  final BudgetRepository _repository;
  final _saveFailures = StreamController<void>.broadcast();

  Stream<void> get saveFailures => _saveFailures.stream;

  Future<void> load() async {
    try {
      final budgets = await _repository.load();
      if (!isClosed) emit(budgets);
    } on Exception {
      // Chưa tải được thì coi như chưa đặt hũ; lần mở sau sẽ tải lại.
    }
  }

  void reset() => emit(const []);

  Future<void> set(Budget budget) async {
    emit([
      for (final b in state)
        if (b.period != budget.period) b,
      budget,
    ]);
    try {
      await _repository.save(budget);
    } on Exception {
      if (isClosed) return;
      _saveFailures.add(null);
      await load();
    }
  }

  @override
  Future<void> close() async {
    await _saveFailures.close();
    return super.close();
  }
}
