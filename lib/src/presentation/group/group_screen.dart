import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../balance/balance_screen.dart';
import '../ledger/ledger_cubit.dart';
import '../profile/name_edit_sheet.dart';
import '../widgets/info_line.dart';
import '../widgets/member_avatar.dart';
import '../widgets/section_title.dart';
import 'group_invite_screen.dart';
import 'group_type_ui.dart';

/// Quản lý một nhóm: thành viên, tên, mời, rời và xóa. Nhóm phải là nhóm đang
/// mở, vì các thao tác của [LedgerCubit] đều tác động lên nhóm đang mở.
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.groupId});

  final String groupId;

  void _openBalance(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BalanceScreen()));
  }

  Future<void> _explainBlocked(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final seeBalance = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xem số dư'),
          ),
        ],
      ),
    );
    if (seeBalance == true && context.mounted) _openBalance(context);
  }

  Future<void> _deleteGroup(BuildContext context) async {
    final cubit = context.read<LedgerCubit>();
    final state = cubit.state;
    final groupName = state.group.name;
    final memberCount = state.group.members.length;

    if (!state.canDeleteGroup) {
      await _explainBlocked(
        context,
        title: 'Chưa xóa nhóm được',
        message:
            '$groupName còn ${state.transfers.length} khoản chưa trả xong. '
            'Khi cả nhóm đã sòng phẳng bạn mới xóa nhóm được.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xóa nhóm $groupName?'),
        content: Text(
          memberCount > 1
              ? 'Mọi khoản chi, ảnh và bình luận của nhóm sẽ bị xóa với cả '
                    '$memberCount thành viên. Việc này không hoàn tác được.'
              : 'Mọi khoản chi, ảnh và bình luận của nhóm sẽ bị xóa. '
                    'Việc này không hoàn tác được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Giữ nhóm'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: TachColors.danger),
            child: const Text('Xóa nhóm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    if (cubit.deleteGroup()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _leaveGroup(BuildContext context) async {
    final cubit = context.read<LedgerCubit>();
    final state = cubit.state;
    final groupName = state.group.name;

    if (!state.canLeaveGroup) {
      final amount = formatVnd(state.myNet.abs());
      await _explainBlocked(
        context,
        title: 'Chưa rời nhóm được',
        message: state.myNet < 0
            ? 'Bạn còn cần trả $amount trong $groupName. '
                  'Trả xong rồi bạn mới rời nhóm được.'
            : 'Mọi người còn cần trả bạn $amount trong $groupName. '
                  'Nhận đủ rồi bạn mới rời nhóm được.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rời nhóm $groupName?'),
        content: const Text(
          'Bạn sẽ không còn thấy khoản chi và ảnh của nhóm này. '
          'Muốn vào lại cần mã mời.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: TachColors.danger),
            child: const Text('Rời nhóm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    if (cubit.leaveGroup()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final cubit = context.read<LedgerCubit>();

    // Nhóm vừa bị xóa hoặc mình vừa bị gỡ khỏi nhóm trong lúc đang xem.
    if (state.currentGroupId != groupId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nhóm')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Nhóm này không còn nữa.',
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
          ),
        ),
      );
    }

    final group = state.group;
    final net = state.myNet;

    return Scaffold(
      appBar: AppBar(title: const Text('Nhóm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: TachColors.mintTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  group.type.icon,
                  size: 28,
                  color: TachColors.mintLight,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge,
                    ),
                    Text(
                      '${group.type.label}, ${group.members.length} người',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => NameEditSheet(
                    title: 'Đổi tên nhóm',
                    description: 'Cả nhóm sẽ thấy tên mới.',
                    initialName: group.name,
                    hint: 'Tên nhóm',
                    maxLength: 30,
                    onSave: cubit.renameGroup,
                  ),
                ),
                tooltip: 'Đổi tên nhóm',
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InfoLine(
            label: 'Số dư của bạn',
            value: net < 0
                ? 'Cần trả ${formatVnd(-net)}'
                : net > 0
                ? 'Được nhận ${formatVnd(net)}'
                : 'Đã sòng phẳng',
          ),
          InfoLine(label: 'Cả nhóm đã chi', value: formatVnd(state.totalSpent)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _openBalance(context),
            child: const Text('Xem ai nợ ai'),
          ),
          const SectionTitle('Thành viên'),
          for (final m in group.members)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  MemberAvatar(
                    name: m.name,
                    tone: state.toneOf(m.id),
                    photo: m.avatarBytes,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(m.name, style: text.bodyLarge)),
                  if (m.id == state.meId) Text('Bạn', style: text.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupInviteScreen(groupId: group.id),
              ),
            ),
            icon: const Icon(Icons.person_add_alt, size: 20),
            label: const Text('Mời bạn vào nhóm'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _leaveGroup(context),
            style: TextButton.styleFrom(
              foregroundColor: TachColors.danger,
              minimumSize: const Size(64, 48),
            ),
            child: const Text('Rời nhóm'),
          ),
          if (state.isGroupCreator)
            TextButton(
              onPressed: () => _deleteGroup(context),
              style: TextButton.styleFrom(
                foregroundColor: TachColors.danger,
                minimumSize: const Size(64, 48),
              ),
              child: const Text('Xóa nhóm'),
            ),
        ],
      ),
    );
  }
}
