import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/logic/jar.dart';
import '../ledger/ledger_cubit.dart';
import 'budget_cubit.dart';
import 'jar_card.dart';
import 'jar_sheet.dart';
import 'jar_view.dart';

/// Chi tiết "Hũ của tôi" trong một tháng: phần của mình đi vào nhóm nào.
class JarScreen extends StatelessWidget {
  const JarScreen({super.key, required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final budget = budgetFor(context.watch<BudgetCubit>().state, month);
    final jar = jarOf(state, month, budget);
    final totals = jar.byGroup;
    final largest = totals.isEmpty ? 1 : totals.first.amount;

    void edit() => showJarSheet(context, month: month, current: budget);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hũ của tôi'),
        actions: [
          IconButton(
            onPressed: edit,
            tooltip: budget == null ? 'Đặt hũ' : 'Sửa hũ',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          JarCard(
            jar: jar,
            budget: budget,
            onSet: edit,
            title: 'Tháng ${month.month}, phần của bạn',
            segments: [
              for (final total in totals)
                (color: groupTone(state, total.group), amount: total.amount),
            ],
          ),
          const SizedBox(height: 24),
          Text('Theo nhóm', style: text.titleMedium),
          const SizedBox(height: 4),
          if (totals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Tháng này bạn chưa có khoản chi nào.',
                style: text.bodyMedium,
              ),
            ),
          for (final total in totals) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: groupTone(state, total.group),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          groupLabel(total.group),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                      ),
                      Text(formatVnd(total.amount), style: text.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: total.amount / largest,
                      minHeight: 4,
                      backgroundColor: TachColors.fill,
                      color: groupTone(state, total.group),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${total.group.isPersonal ? 'Khoản riêng' : 'Phần của bạn'}'
                    ', ${total.count} khoản',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TachColors.mintTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Đây chỉ là phần của bạn. Mỗi nhóm vẫn tự xem tổng chi và ai nợ '
              'ai như cũ, không ai thấy hũ của bạn.',
              style: text.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
