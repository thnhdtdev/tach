import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../services/avatar/avatar_picker.dart';
import '../balance/balance_screen.dart';
import '../group/group_invite_screen.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/info_line.dart';
import '../widgets/member_avatar.dart';
import '../widgets/section_title.dart';
import 'bank_account_sheet.dart';
import 'name_edit_sheet.dart';

/// Hồ sơ của người dùng: tên, tài khoản nhận tiền, nhóm đang ở và đăng xuất.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TachColors.paper,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: context.read<LedgerCubit>(), child: sheet),
    );
  }

  Future<void> _changeAvatar(BuildContext context, bool hasPhoto) async {
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: TachColors.paper,
      showDragHandle: true,
      builder: (_) => _AvatarOptions(hasPhoto: hasPhoto),
    );
    if (action == null || !context.mounted) return;

    final cubit = context.read<LedgerCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (action == _AvatarAction.remove) {
      cubit.setMyAvatar(null);
      return;
    }

    final fromCamera = action == _AvatarAction.camera;
    try {
      final bytes = await getIt<AvatarPicker>().pick(
        fromCamera ? AvatarSource.camera : AvatarSource.gallery,
      );
      if (bytes != null) cubit.setMyAvatar(bytes);
    } on PlatformException {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            fromCamera
                ? 'Không mở được camera. Kiểm tra quyền camera trong Cài đặt.'
                : 'Không mở được thư viện ảnh. Kiểm tra quyền truy cập ảnh '
                      'trong Cài đặt.',
          ),
        ),
      );
    }
  }

  /// Báo vì sao chưa làm được việc vừa bấm, kèm lối sang màn số dư.
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
    if (seeBalance == true && context.mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const BalanceScreen()));
    }
  }

  /// Xóa nhóm đang mở với mọi thành viên. Chỉ người tạo nhóm thấy nút này.
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

  /// Rời nhóm đang mở. Còn khoản chưa sòng phẳng thì chỉ báo lý do.
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
      // Nhóm đang mở đã đổi; quay về màn chính của nhóm còn lại.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final cubit = context.read<LedgerCubit>();
    final me = state.me;
    final bank = me.bank;

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              _EditableAvatar(
                onTap: () => _changeAvatar(context, me.avatarBytes != null),
                child: MemberAvatar(
                  name: me.name,
                  tone: state.toneOf(me.id),
                  photo: me.avatarBytes,
                  size: 72,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineMedium,
                    ),
                    Text(
                      state.hasGroup
                          ? 'Thành viên ${state.group.name}'
                          : 'Chưa ở nhóm nào',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openSheet(
                  context,
                  NameEditSheet(
                    title: 'Đổi tên',
                    description:
                        'Cả nhóm sẽ thấy tên này ở mỗi khoản chi của bạn.',
                    initialName: me.name,
                    hint: 'Tên của bạn',
                    maxLength: 24,
                    onSave: cubit.renameMe,
                  ),
                ),
                tooltip: 'Đổi tên',
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SectionTitle('Tài khoản nhận tiền'),
          if (bank == null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: TachColors.mintWash,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Thêm tài khoản để bạn cùng nhóm trả bạn bằng mã VietQR, '
                'đúng số tiền và đúng người.',
                style: text.bodyLarge?.copyWith(color: TachColors.mintDeep),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _openSheet(context, const BankAccountSheet()),
              child: const Text('Thêm tài khoản'),
            ),
          ] else ...[
            const SizedBox(height: 6),
            InfoLine(label: 'Ngân hàng', value: bank.bankName),
            InfoLine(label: 'Số tài khoản', value: bank.accountNumber),
            InfoLine(label: 'Chủ tài khoản', value: bank.holderName),
            const SizedBox(height: 4),
            Text(
              'Bạn cùng nhóm thấy tài khoản này khi trả tiền cho bạn.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  _openSheet(context, BankAccountSheet(current: bank)),
              child: const Text('Sửa tài khoản'),
            ),
          ],
          if (state.hasGroup) ...[
            const SectionTitle('Nhóm đang mở'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                ),
                Text(
                  '${state.group.members.length} người',
                  style: text.bodyMedium,
                ),
                IconButton(
                  onPressed: () => _openSheet(
                    context,
                    NameEditSheet(
                      title: 'Đổi tên nhóm',
                      description: 'Cả nhóm sẽ thấy tên mới.',
                      initialName: state.group.name,
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
            for (final m in state.group.members)
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
                  builder: (_) => GroupInviteScreen(groupId: state.group.id),
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
          const SizedBox(height: 36),
          OutlinedButton(onPressed: onSignOut, child: const Text('Đăng xuất')),
        ],
      ),
    );
  }
}

enum _AvatarAction { gallery, camera, remove }

/// Avatar có huy hiệu máy ảnh, chạm để đổi ảnh đại diện.
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Đổi ảnh đại diện',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TachColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: TachColors.line),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 16,
                  color: TachColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarOptions extends StatelessWidget {
  const _AvatarOptions({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget option(IconData icon, String label, _AvatarAction action) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(icon, color: TachColors.ink),
        title: Text(label, style: text.bodyLarge),
        onTap: () => Navigator.of(context).pop(action),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Ảnh đại diện', style: text.titleLarge),
          ),
          option(
            Icons.photo_library_outlined,
            'Chọn từ thư viện',
            _AvatarAction.gallery,
          ),
          option(
            Icons.photo_camera_outlined,
            'Chụp ảnh mới',
            _AvatarAction.camera,
          ),
          if (hasPhoto)
            option(Icons.delete_outline, 'Gỡ ảnh', _AvatarAction.remove),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
