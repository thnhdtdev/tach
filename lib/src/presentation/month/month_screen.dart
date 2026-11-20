import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../../domain/logic/jar.dart';
import '../balance/balance_screen.dart';
import '../jar/budget_cubit.dart';
import '../jar/jar_card.dart';
import '../jar/jar_screen.dart';
import '../jar/jar_sheet.dart';
import '../jar/jar_view.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';
import '../widgets/side_slide_route.dart';
import '../widgets/swipe_to_close.dart';
import 'month_calendar.dart';

enum _Mode { calendar, grid }

enum _Filter { all, mine, commented }

/// Khoản chi người dùng chọn ở màn tháng, để màn chính mở đúng khoản đó.
typedef PickedExpense = ({String groupId, String expenseId});

/// Một tháng nhìn theo hai cách: "Lịch" là phần của riêng người dùng trên mọi
/// nhóm kèm hũ của họ, "Lưới" là mọi khoản của nhóm đang mở.
class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key});

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  static const _labels = {
    _Filter.all: 'Tất cả',
    _Filter.mine: 'Của tôi',
    _Filter.commented: 'Có bình luận',
  };

  var _mode = _Mode.calendar;
  var _filter = _Filter.all;
  late DateTime _month = _thisMonth;

  DateTime get _thisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  Future<void> _openDay(
    LedgerState state,
    int day,
    List<JarEntry> entries,
  ) async {
    final picked = await showModalBottomSheet<JarEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DayEntriesSheet(
        state: state,
        date: DateTime(_month.year, _month.month, day),
        entries: entries,
      ),
    );
    if (picked == null || !mounted) return;
    Navigator.of(context).pop<PickedExpense>((
      groupId: picked.group.id,
      expenseId: picked.expense.id,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SwipeToClose(
      towardsRight: !openedFromLeft(context),
      child: _screen(context),
    );
  }

  Widget _screen(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final budget = budgetFor(context.watch<BudgetCubit>().state, _month);
    final jar = jarOf(state, _month, budget);

    final inMonth = [
      for (final e in state.expenses)
        if (e.createdAt.year == _month.year &&
            e.createdAt.month == _month.month)
          e,
    ];
    final expenses = switch (_filter) {
      _Filter.all => inMonth,
      _Filter.mine => inMonth.where((e) => e.payerId == state.meId).toList(),
      _Filter.commented => inMonth.where((e) => e.comments.isNotEmpty).toList(),
    };
    final groupTotal = inMonth.fold(0, (sum, e) => sum + e.amount);

    void setJar() => showJarSheet(context, month: _month, current: budget);

    return Scaffold(
      appBar: sideAppBar(
        context,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _shift(-1),
              tooltip: 'Tháng trước',
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Tháng ${_month.month}, ${_month.year}'),
            IconButton(
              onPressed: _month.isBefore(_thisMonth) ? () => _shift(1) : null,
              tooltip: 'Tháng sau',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(
              children: [
                SegmentedButton<_Mode>(
                  segments: const [
                    ButtonSegment(value: _Mode.calendar, label: Text('Lịch')),
                    ButtonSegment(value: _Mode.grid, label: Text('Lưới')),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: TachColors.fill,
                    foregroundColor: Colors.white,
                    selectedBackgroundColor: TachColors.mintTint,
                    selectedForegroundColor: TachColors.mintLight,
                    side: BorderSide.none,
                  ),
                  onSelectionChanged: (modes) =>
                      setState(() => _mode = modes.single),
                ),
                const SizedBox(height: 14),
                if (_mode == _Mode.calendar) ...[
                  JarCard(
                    jar: jar,
                    budget: budget,
                    onSet: setJar,
                    onDetail: budget == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => JarScreen(month: _month),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  MonthCalendar(
                    state: state,
                    jar: jar,
                    budget: budget,
                    onDay: (day, entries) => _openDay(state, day, entries),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  Text(
                    state.group.isPersonal
                        ? 'Bạn đã chi riêng'
                        : 'Cả nhóm đã chi',
                    style: text.bodyMedium,
                  ),
                  Text(formatVnd(groupTotal), style: text.displaySmall),
                  const SizedBox(height: 16),
                  if (!state.group.isPersonal) ...[
                    _MyBalanceCard(myNet: state.myNet),
                    const SizedBox(height: 18),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in _Filter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_labels[filter]!),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                              showCheckmark: false,
                              shape: const StadiumBorder(),
                              side: const BorderSide(
                                color: TachColors.hairline,
                              ),
                              backgroundColor: TachColors.nightRaised,
                              selectedColor: TachColors.mintTint,
                              labelStyle: text.labelLarge?.copyWith(
                                color: _filter == filter
                                    ? TachColors.mintLight
                                    : Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          if (_mode == _Mode.grid && expenses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    switch (_filter) {
                      _Filter.all => 'Tháng này chưa có khoản chi nào.',
                      _Filter.mine => 'Bạn chưa ghi khoản nào trong tháng này.',
                      _Filter.commented => 'Chưa có khoản nào có bình luận.',
                    },
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ),
              ),
            )
          else if (_mode == _Mode.grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: expenses.length,
                itemBuilder: (context, i) => _Tile(
                  expense: expenses[i],
                  onTap: () => Navigator.of(context).pop<PickedExpense>((
                    groupId: state.currentGroupId,
                    expenseId: expenses[i].id,
                  )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MyBalanceCard extends StatelessWidget {
  const _MyBalanceCard({required this.myNet});

  final int myNet;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = myNet < 0
        ? 'Bạn cần trả'
        : myNet > 0
        ? 'Bạn được nhận'
        : 'Bạn không nợ ai';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: TachColors.mintTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.bodyMedium?.copyWith(color: TachColors.mintLight),
                ),
                if (myNet != 0)
                  Text(
                    formatVnd(myNet.abs()),
                    style: text.headlineMedium?.copyWith(
                      color: TachColors.mintLight,
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BalanceScreen()),
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text('Xem số dư'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      height: 1.1,
    );
    return Semantics(
      button: true,
      label:
          '${expense.note.isEmpty ? 'Khoản chi' : expense.note}, '
          '${formatVnd(expense.amount)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExpensePhoto(
                photoUrl: expense.photoUrl,
                photoBytes: expense.photoBytes,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 7,
                child: Text(formatShortVnd(expense.amount), style: label),
              ),
              if (expense.comments.isNotEmpty)
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${expense.comments.length}',
                        style: label.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
