import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/format/time_ago.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../dependency/injection.dart';
import '../../domain/entities/expense.dart';
import '../../services/photo/photo_loader.dart';
import '../../services/photo/photo_sharer.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';
import '../widgets/member_avatar.dart';
import 'comments_sheet.dart';
import 'edit_expense_sheet.dart';
import 'reaction_picker_sheet.dart';

class ExpensePage extends StatelessWidget {
  const ExpensePage({super.key, required this.expense, required this.state});

  static const quickReactions = ['👍', '😂', '🙏'];

  static const _maxReactionKinds = 3;

  static const bottomBarSpace = 84.0;

  final Expense expense;
  final LedgerState state;

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
      // Không để bảng tràn lên dưới thanh trạng thái khi bàn phím mở.
      useSafeArea: true,
      showDragHandle: true,
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

  bool get _isMine => expense.payerId == state.meId;

  /// Ảnh mẫu và ô thay thế của khoản không có ảnh thì không có gì để chia sẻ.
  bool get _hasSharablePhoto =>
      expense.photoBytes != null ||
      (expense.photoUrl?.startsWith(remotePhotoPrefix) ?? false);

  Future<void> _openActions(BuildContext context) async {
    final action = await showModalBottomSheet<_ExpenseAction>(
      context: context,
      backgroundColor: TachColors.paper,
      showDragHandle: true,
      // Bảng tin dùng theme tối; bảng này là nền sáng.
      builder: (sheetContext) => Theme(
        data: tachLightTheme,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasSharablePhoto)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Chia sẻ ảnh'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ExpenseAction.share),
                ),
              if (_isMine)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Sửa khoản chi'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ExpenseAction.edit),
                ),
              if (_isMine)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.delete_outline),
                  iconColor: TachColors.danger,
                  textColor: TachColors.danger,
                  title: const Text('Xóa khoản chi'),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ExpenseAction.delete),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _ExpenseAction.share:
        await _share(context);
      case _ExpenseAction.edit:
        await _edit(context);
      case _ExpenseAction.delete:
        await _delete(context);
      case null:
    }
  }

  Future<void> _edit(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: TachColors.paper,
      builder: (_) => Theme(
        data: tachLightTheme,
        child: BlocProvider.value(
          value: context.read<LedgerCubit>(),
          child: EditExpenseSheet(expense: expense),
        ),
      ),
    );
    if (edited != true) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã sửa khoản chi.')));
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    void tell(String message) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    final photo =
        expense.photoBytes ??
        await getIt<PhotoLoader>().load(
          expense.photoUrl!.substring(remotePhotoPrefix.length),
        );
    if (photo == null) {
      tell('Chưa tải được ảnh. Kiểm tra mạng rồi thử lại.');
      return;
    }
    try {
      await getIt<PhotoSharer>().share(photo, origin: origin);
    } on Exception {
      tell('Không mở được bảng chia sẻ. Thử lại nhé.');
    }
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<LedgerCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: tachLightTheme,
        child: AlertDialog(
          title: const Text('Xóa khoản chi này?'),
          content: Text(
            'Ảnh và khoản chi ${formatVnd(expense.amount)} sẽ mất với cả nhóm, '
            'số dư được tính lại. Việc này không hoàn tác được.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Giữ lại'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: TachColors.danger),
              child: const Text('Xóa khoản chi'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    cubit.deleteExpense(expense.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã xóa khoản chi.')));
  }

  void _openReactionPicker(BuildContext context) {
    final cubit = context.read<LedgerCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TachColors.nightRaised,
      showDragHandle: true,
      builder: (sheetContext) => ReactionPickerSheet(
        current: expense.reactions[state.meId],
        onPick: (emoji) {
          cubit.setReaction(expense.id, emoji);
          Navigator.of(sheetContext).pop();
        },
        onRemove: () {
          cubit.setReaction(expense.id, null);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<LedgerCubit>();
    final part = _myPart();
    final myReaction = expense.reactions[state.meId];

    final otherReaction =
        myReaction != null && !quickReactions.contains(myReaction)
        ? myReaction
        : null;

    final reactionCounts = <String, int>{};
    for (final emoji in expense.reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }
    final topReactions =
        (reactionCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(_maxReactionKinds)
            .toList();

    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                MemberAvatar(
                  name: state.member(expense.payerId).name,
                  tone: state.toneOf(expense.payerId),
                  photo: state.member(expense.payerId).avatarBytes,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.displayName(expense.payerId),
                        style: text.labelLarge,
                      ),
                      Text(
                        expense.editedAt == null
                            ? timeAgo(expense.createdAt)
                            : '${timeAgo(expense.createdAt)} · đã sửa',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_hasSharablePhoto || _isMine)
                  IconButton(
                    onPressed: () => _openActions(context),
                    tooltip: 'Tùy chọn',
                    icon: Icon(
                      Icons.more_horiz,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                heightFactor: 1,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
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
                for (final entry in topReactions)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '${entry.key} ${entry.value}',
                      style: text.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                if (reactionCounts.length > topReactions.length)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '+${reactionCounts.length - topReactions.length}',
                      style: text.bodyMedium,
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
                // Trắng mờ thay cho xám đặc để thanh ngả theo màu nền của ảnh.
                color: Colors.white.withValues(alpha: 0.1),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                            // Màu chữ thừa hưởng là trắng mờ, làm emoji mờ
                            // theo; đặt trắng hẳn để emoji lên đủ màu.
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Tooltip(
                    message: 'Chọn cảm xúc khác',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _openReactionPicker(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: otherReaction != null
                              ? TachColors.mint.withValues(alpha: 0.35)
                              : null,
                        ),
                        child: otherReaction != null
                            ? Text(
                                otherReaction,
                                style: const TextStyle(
                                  fontSize: 20,
                                  height: 1.1,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.add_reaction_outlined,
                                size: 24,
                                color: Colors.white,
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

enum _ExpenseAction { share, edit, delete }
