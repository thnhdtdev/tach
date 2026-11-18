import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../ledger/ledger_cubit.dart';

/// Màn mời bạn vào nhóm bằng mã mời.
///
/// Link mời mở thẳng app sẽ thêm sau khi chốt tên miền; hiện chỉ có mã.
class GroupInviteScreen extends StatefulWidget {
  const GroupInviteScreen({
    super.key,
    required this.groupId,
    this.justCreated = false,
  });

  final String groupId;

  /// `true` khi vừa tạo nhóm xong, để đổi lời chào đầu màn.
  final bool justCreated;

  @override
  State<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends State<GroupInviteScreen> {
  var _copied = false;

  Future<void> _copy(String groupName, String code) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            'Vào nhóm "$groupName" trên Tach để ghi chi tiêu chung nhé. '
            'Mã mời: $code',
      ),
    );
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;
    final group = state.groups.firstWhere((g) => g.id == widget.groupId);

    return Scaffold(
      appBar: AppBar(title: const Text('Mời vào nhóm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            widget.justCreated
                ? 'Đã tạo nhóm ${group.name}'
                : 'Mời bạn vào ${group.name}',
            style: text.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Gửi mã này cho mọi người. Họ nhập mã khi đăng nhập Tach '
            'là vào đúng nhóm.',
            style: text.bodyLarge?.copyWith(color: TachColors.inkSoft),
          ),
          const SizedBox(height: 24),
          Semantics(
            label: 'Mã mời ${group.inviteCode.split('').join(' ')}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TachColors.mintWash,
                borderRadius: BorderRadius.circular(24),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  group.inviteCode,
                  style: text.displaySmall?.copyWith(
                    color: TachColors.mintDeep,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _copy(group.name, group.inviteCode),
            icon: Icon(_copied ? Icons.check : Icons.copy, size: 20),
            label: Text(_copied ? 'Đã chép lời mời' : 'Chép lời mời'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }
}
