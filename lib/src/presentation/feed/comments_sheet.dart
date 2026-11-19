import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/time_ago.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/member_avatar.dart';

/// Bình luận của một khoản chi. Cả nhóm cùng thấy, trả lời theo luồng.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key, required this.expenseId});

  final String expenseId;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  /// Bình luận gốc đang được trả lời, nếu có.
  Comment? _replyTo;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    context.read<LedgerCubit>().addComment(
      widget.expenseId,
      _input.text,
      parentId: _replyTo?.id,
    );
    _input.clear();
    setState(() => _replyTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final expense = state.expenses.firstWhere((e) => e.id == widget.expenseId);

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Bàn phím mở thì bảng thu lại cho vừa phần còn trống, vẫn chừa một dải
        // nền mờ phía trên để tiêu đề không chui lên thanh trạng thái và người
        // dùng còn chỗ chạm ra ngoài để đóng.
        final room = constraints.maxHeight - keyboard - _scrimAbove;
        final height = math.max(_minHeight, math.min(screen * 0.72, room));
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SizedBox(
            height: height,
            child: _content(text, state, expense),
          ),
        );
      },
    );
  }

  /// Phần nền mờ tối thiểu còn lại phía trên bảng khi bàn phím mở.
  static const _scrimAbove = 28.0;
  static const _minHeight = 220.0;

  Widget _content(TextTheme text, LedgerState state, Expense expense) {
    final roots = expense.comments.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    List<Comment> repliesOf(Comment root) =>
        expense.comments.where((c) => c.parentId == root.id).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Chạm vào chỗ trống trong bảng thì cất bàn phím.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _focus.unfocus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bình luận', style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text('Cả nhóm cùng thấy', style: text.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close, color: TachColors.ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: roots.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Chưa có bình luận. Hỏi hoặc nhắn gì đó về khoản này.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                    ),
                  )
                : ListView(
                    // Kéo danh sách cũng cất bàn phím.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    children: [
                      for (final root in roots) ...[
                        _CommentTile(
                          comment: root,
                          state: state,
                          onReply: () {
                            setState(() => _replyTo = root);
                            _focus.requestFocus();
                          },
                        ),
                        for (final reply in repliesOf(root))
                          Padding(
                            padding: const EdgeInsets.only(left: 46),
                            child: _CommentTile(
                              comment: reply,
                              state: state,
                              small: true,
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
          if (_replyTo != null)
            Container(
              color: TachColors.mintWash,
              padding: const EdgeInsets.only(left: 24, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đang trả lời ${state.displayName(_replyTo!.userId)}',
                      style: text.bodySmall?.copyWith(
                        color: TachColors.mintDeep,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyTo = null),
                    tooltip: 'Thôi trả lời',
                    iconSize: 18,
                    icon: const Icon(Icons.close, color: TachColors.mintDeep),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: text.bodyLarge,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Viết bình luận',
                        hintStyle: text.bodyLarge?.copyWith(
                          color: TachColors.inkSoft,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F4F3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _input.text.trim().isEmpty ? null : _send,
                    tooltip: 'Gửi bình luận',
                    color: TachColors.mint,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.state,
    this.onReply,
    this.small = false,
  });

  final Comment comment;
  final LedgerState state;
  final VoidCallback? onReply;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberAvatar(
            name: state.member(comment.userId).name,
            tone: state.toneOf(comment.userId),
            photo: state.member(comment.userId).avatarBytes,
            size: small ? 28 : 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      state.displayName(comment.userId),
                      style: text.labelLarge,
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo(comment.createdAt), style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.text, style: text.bodyLarge),
                if (onReply != null)
                  InkWell(
                    onTap: onReply,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Trả lời',
                        style: text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: TachColors.mintDeep,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
