import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../services/avatar/avatar_picker.dart';
import '../group/group_invite_screen.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/info_line.dart';
import '../widgets/member_avatar.dart';
import '../widgets/section_title.dart';
import 'bank_account_sheet.dart';
import 'rename_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final me = state.member(state.meId);
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
                      'Thành viên ${state.group.name}',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    _openSheet(context, RenameSheet(currentName: me.name)),
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
          const SectionTitle('Nhóm của bạn'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(state.group.name, style: text.titleMedium),
                ),
                Text(
                  '${state.group.members.length} người',
                  style: text.bodyMedium,
                ),
              ],
            ),
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
