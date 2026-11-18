import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../balance/balance_screen.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';

enum _Filter { all, mine, commented }

/// Lưới ảnh các khoản chi trong tháng. Chạm một ô để mở khoản đó ở bảng tin.
///
/// Hiện hiển thị mọi khoản đã tải; khi có máy chủ sẽ tải theo từng tháng.
class MonthGridScreen extends StatefulWidget {
  const MonthGridScreen({super.key});

  @override
  State<MonthGridScreen> createState() => _MonthGridScreenState();
}

class _MonthGridScreenState extends State<MonthGridScreen> {
  static const _labels = {
    _Filter.all: 'Tất cả',
    _Filter.mine: 'Của tôi',
    _Filter.commented: 'Có bình luận',
  };

  var _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;

    final expenses = switch (_filter) {
      _Filter.all => state.expenses,
      _Filter.mine =>
        state.expenses.where((e) => e.payerId == state.meId).toList(),
      _Filter.commented =>
        state.expenses.where((e) => e.comments.isNotEmpty).toList(),
    };

    return Scaffold(
      appBar: AppBar(title: Text('Tháng ${DateTime.now().month}')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverList.list(
              children: [
                Text('Cả nhóm đã chi', style: text.bodyMedium),
                Text(formatVnd(state.totalSpent), style: text.displaySmall),
                const SizedBox(height: 16),
                _MyBalanceCard(myNet: state.myNet),
                const SizedBox(height: 18),
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
                            onSelected: (_) => setState(() => _filter = filter),
                            showCheckmark: false,
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: TachColors.line),
                            backgroundColor: TachColors.paper,
                            selectedColor: TachColors.mintWash,
                            labelStyle: text.labelLarge?.copyWith(
                              color: _filter == filter
                                  ? TachColors.mintDeep
                                  : TachColors.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          if (expenses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    switch (_filter) {
                      _Filter.all =>
                        'Chưa có khoản chi nào. Chụp món đầu tiên để bắt đầu.',
                      _Filter.mine => 'Bạn chưa ghi khoản nào trong tháng này.',
                      _Filter.commented => 'Chưa có khoản nào có bình luận.',
                    },
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ),
              ),
            )
          else
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
                  onTap: () => Navigator.of(context).pop(expenses[i].id),
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
        color: TachColors.mintWash,
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
                  style: text.bodyMedium?.copyWith(color: TachColors.mintDeep),
                ),
                if (myNet != 0)
                  Text(
                    formatVnd(myNet.abs()),
                    style: text.headlineMedium?.copyWith(
                      color: TachColors.mintDeep,
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
