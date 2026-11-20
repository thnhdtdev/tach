import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/datasource/sample/sample_budget_repository.dart';
import 'package:tach/src/datasource/sample/sample_group_repository.dart';
import 'package:tach/src/domain/entities/budget.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/presentation/jar/budget_cubit.dart';
import 'package:tach/src/presentation/ledger/ledger_cubit.dart';

void main() {
  late LedgerCubit cubit;

  setUp(() async {
    cubit = LedgerCubit(SampleGroupRepository());
    await cubit.load();
  });

  tearDown(() => cubit.close());

  test('mở "Riêng tôi" lần đầu thì tạo nhóm riêng, lần sau dùng lại', () {
    expect(cubit.state.personal, isNull);

    cubit.openPersonal();
    final personal = cubit.state.group;
    expect(personal.type, GroupType.personal);
    expect(personal.members.single.id, cubit.state.meId);
    expect(cubit.state.inSharedGroup, isFalse);

    cubit
      ..switchGroup(cubit.state.groups.first.id)
      ..openPersonal();
    expect(cubit.state.group.id, personal.id);
    expect(cubit.state.ledgers.where((l) => l.group.isPersonal), hasLength(1));
  });

  test('nhóm riêng không nằm trong danh sách nhóm chung', () {
    cubit.openPersonal();
    expect(cubit.state.groups.map((g) => g.name), ['Trọ 12']);
  });

  test('khoản riêng không làm đổi số dư của nhóm chung', () {
    final before = cubit.state.myNet;
    final shared = cubit.state.currentGroupId;

    cubit
      ..openPersonal()
      ..addExpense(
        amount: 35000,
        note: 'Phở',
        participantIds: [cubit.state.meId],
      );
    expect(cubit.state.myNet, 0);

    cubit.switchGroup(shared);
    expect(cubit.state.myNet, before);
  });

  test('đặt hũ: mức mới của cùng tháng thay mức cũ', () async {
    final budgets = BudgetCubit(SampleBudgetRepository());
    addTearDown(budgets.close);
    final month = DateTime(2026, 11);

    await budgets.set(Budget(period: month, amount: 5000000));
    await budgets.set(Budget(period: month, amount: 7000000, repeats: false));
    expect(budgets.state.single.amount, 7000000);

    await budgets.load();
    expect(budgets.state.single.amount, 7000000);
    expect(budgets.state.single.repeats, isFalse);
  });
}
