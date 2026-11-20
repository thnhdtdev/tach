import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../domain/entities/group.dart';
import '../../services/auth/auth_service.dart';
import '../../services/avatar/avatar_picker.dart';
import '../balance/balance_screen.dart';
import '../group/create_group_screen.dart';
import '../group/group_invite_screen.dart';
import '../group/group_screen.dart';
import '../group/group_type_ui.dart';
import '../group/join_group_sheet.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/info_line.dart';
import '../widgets/member_avatar.dart';
import 'bank_account_sheet.dart';
import 'home_widget_card.dart';
import 'link_account_card.dart';
import 'name_edit_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          BlocProvider.value(value: context.read<LedgerCubit>(), child: sheet),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _rename(BuildContext context) {
    final cubit = context.read<LedgerCubit>();
    _openSheet(
      context,
      NameEditSheet(
        title: 'Đổi tên',
        description: 'Cả nhóm sẽ thấy tên này ở mỗi khoản chi của bạn.',
        initialName: cubit.state.me.name,
        hint: 'Tên của bạn',
        maxLength: 24,
        onSave: cubit.renameMe,
      ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, bool hasPhoto) async {
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
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

  /// Các thao tác quản lý nhóm đều chạy trên nhóm đang mở, nên mở nhóm đó
  /// trước khi vào màn quản lý.
  void _openGroup(BuildContext context, String groupId) {
    context.read<LedgerCubit>().switchGroup(groupId);
    _push(context, GroupScreen(groupId: groupId));
  }

  Future<void> _addGroup(BuildContext context) async {
    final create = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.add, color: Colors.white),
              title: const Text('Tạo nhóm mới'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.pin_outlined, color: Colors.white),
              title: const Text('Vào nhóm bằng mã mời'),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (create == null || !context.mounted) return;
    if (create) {
      _push(context, const CreateGroupScreen());
    } else {
      await showJoinGroupSheet(context);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất khỏi Tach?'),
        content: Text(
          getIt<AuthService>().isGuest
              ? 'Bạn đang dùng tài khoản khách. Đăng xuất rồi sẽ không vào '
                    'lại được tài khoản này, kể cả các nhóm và khoản chi '
                    'của bạn.'
              : 'Dữ liệu của bạn vẫn được giữ. Đăng nhập lại là thấy đủ các '
                    'nhóm và khoản chi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: TachColors.danger),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final me = state.me;
    final bank = me.bank;
    final groups = state.groups;

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: _EditableAvatar(
              onTap: () => _changeAvatar(context, me.avatarBytes != null),
              child: MemberAvatar(
                name: me.name,
                tone: state.toneOf(me.id),
                photo: me.avatarBytes,
                size: 96,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Tooltip(
              message: 'Đổi tên',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _rename(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    me.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              groups.isEmpty ? 'Chưa ở nhóm nào' : '${groups.length} nhóm',
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.inSharedGroup) ...[
                _QuickAction(
                  icon: Icons.person_add_alt,
                  label: 'Mời bạn',
                  onTap: () => _push(
                    context,
                    GroupInviteScreen(groupId: state.group.id),
                  ),
                ),
                _QuickAction(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Số dư',
                  onTap: () => _push(context, const BalanceScreen()),
                ),
              ],
              _QuickAction(
                icon: Icons.add,
                label: 'Thêm nhóm',
                onTap: () => _addGroup(context),
              ),
            ],
          ),
          const LinkAccountCard(),
          if (groups.isNotEmpty) ...[
            const _Heading('Nhóm của bạn'),
            _Card(
              children: [
                for (final group in groups)
                  _GroupRow(
                    group: group,
                    open: group.id == state.currentGroupId,
                    net: state.myNetIn(group.id),
                    onTap: () => _openGroup(context, group.id),
                  ),
              ],
            ),
          ],
          if (defaultTargetPlatform == TargetPlatform.iOS) ...[
            const _Heading('Widget màn hình chính'),
            const _Card(
              padding: EdgeInsets.all(16),
              children: [HomeWidgetCard()],
            ),
          ],
          const _Heading('Tài khoản nhận tiền'),
          _Card(
            padding: const EdgeInsets.all(16),
            children: [
              if (bank == null) ...[
                Text(
                  'Thêm tài khoản để bạn cùng nhóm trả bạn bằng mã VietQR, '
                  'đúng số tiền và đúng người.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () =>
                      _openSheet(context, const BankAccountSheet()),
                  child: const Text('Thêm tài khoản'),
                ),
              ] else ...[
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
            ],
          ),
          const _Heading('Cá nhân'),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.badge_outlined,
                title: 'Tên hiển thị',
                value: me.name,
                onTap: () => _rename(context),
              ),
              _SettingRow(
                icon: Icons.account_circle_outlined,
                title: 'Ảnh đại diện',
                onTap: () => _changeAvatar(context, me.avatarBytes != null),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.logout,
                title: 'Đăng xuất',
                danger: true,
                onTap: () => _signOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TachColors.nightRaised,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0 && padding == EdgeInsets.zero)
                const Divider(height: 1, indent: 56, endIndent: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: TachColors.mintTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: TachColors.mintLight),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.open,
    required this.net,
    required this.onTap,
  });

  final Group group;
  final bool open;
  final int net;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: TachColors.mintTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                group.type.icon,
                size: 22,
                color: TachColors.mintLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                      ),
                      if (open) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TachColors.mintTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Đang mở',
                            style: text.bodySmall?.copyWith(
                              color: TachColors.mintLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${group.type.label}, ${group.members.length} người',
                    style: text.bodySmall,
                  ),
                  if (net != 0)
                    Text(
                      net < 0
                          ? 'Bạn cần trả ${formatVnd(-net)}'
                          : 'Bạn được nhận ${formatVnd(net)}',
                      style: text.bodySmall?.copyWith(
                        color: net < 0 ? Colors.white : TachColors.mintLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: TachColors.soft),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = danger ? TachColors.danger : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 16),
            Text(
              title,
              style: text.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: text.bodyMedium,
              ),
            ),
            if (!danger)
              const Icon(Icons.chevron_right, color: TachColors.soft),
          ],
        ),
      ),
    );
  }
}

enum _AvatarAction { gallery, camera, remove }

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
                  color: TachColors.nightRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: TachColors.hairline),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 16,
                  color: Colors.white,
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
        leading: Icon(icon, color: Colors.white),
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
