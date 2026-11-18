import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/format/time_ago.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/expense.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';
import '../widgets/member_avatar.dart';
import 'comments_sheet.dart';

/// Một khoản chi chiếm trọn màn hình trong bảng tin.
class ExpensePage extends StatelessWidget {
  const ExpensePage({super.key, required this.expense, required this.state});

  static const quickReactions = ['👍', '😂', '🙏'];

  /// Chừa chỗ cho thanh điều hướng nổi ở đáy bảng tin.
  static const bottomBarSpace = 84.0;

  final Expense expense;
  final LedgerState state;

  /// Dòng tóm tắt phần của người đang xem, ví dụ "Bạn nợ 7.500đ".
  ({String main, String detail}) _myPart() {
    final sharers = expense.splits.length;
    final detail = 'chia $sharers';
    final myShare = expense.splits[state.meId] ?? 0;
    if (expense.payerId == state.meId) {
      final owed = expense.amount - myShare;
      return (
        main: owed == 0
            ? 'Bạn tự trả khoản này'
            : 'Cả nhóm nợ bạn ${formatVnd(owed)}',
        detail: detail,
      );
    }
    if (myShare == 0) return (main: 'Bạn không chia khoản này', detail: detail);
    return (main: 'Bạn nợ ${formatVnd(myShare)}', detail: detail);
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TachColors.paper,
      // Bảng tin dùng theme tối; bảng bình luận là nền sáng.
      builder: (_) => Theme(
        data: tachLightTheme,
        child: BlocProvider.value(
          value: context.read<LedgerCubit>(),
          child: CommentsSheet(expenseId: expense.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<LedgerCubit>();
    final part = _myPart();
    final myReaction = expense.reactions[state.meId];

    final reactionCounts = <String, int>{};
    for (final emoji in expense.reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                MemberAvatar(
                  name: state.member(expense.payerId).name,
                  tone: state.toneOf(expense.payerId),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.displayName(expense.payerId)} trả',
                        style: text.labelLarge,
                      ),
                      Text(timeAgo(expense.createdAt), style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExpensePhoto(photoUrl: expense.photoUrl),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xA6000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatVnd(expense.amount),
                              style: text.displaySmall,
                            ),
                          ),
                          if (expense.note.isNotEmpty)
                            Text(
                              expense.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: part.main,
                          style: text.titleMedium?.copyWith(
                            color: TachColors.mintLight,
                          ),
                        ),
                        TextSpan(
                          text: '  ·  ${part.detail}',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                for (final entry in reactionCounts.entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '${entry.key} ${entry.value}',
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: TachColors.nightRaised,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _openComments(context),
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 18),
                        child: Text(
                          expense.comments.isEmpty
                              ? 'Viết bình luận'
                              : 'Xem ${expense.comments.length} bình luận',
                          style: text.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final emoji in quickReactions)
                    Semantics(
                      button: true,
                      selected: myReaction == emoji,
                      label: 'Thả cảm xúc $emoji',
                      excludeSemantics: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => cubit.toggleReaction(expense.id, emoji),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: myReaction == emoji
                                ? TachColors.mint.withValues(alpha: 0.35)
                                : null,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 20, height: 1.1),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: bottomBarSpace),
        ],
      ),
    );
  }
}
