import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../ledger/ledger_cubit.dart';
import 'group_type_ui.dart';

/// Kết quả chọn trong bảng nhóm: mở một nhóm có sẵn hoặc tạo nhóm mới.
sealed class GroupsSheetResult {
  const GroupsSheetResult();
}

class OpenGroup extends GroupsSheetResult {
  const OpenGroup(this.groupId);

  final String groupId;
}

class CreateNewGroup extends GroupsSheetResult {
  const CreateNewGroup();
}

/// Bảng liệt kê các nhóm đang tham gia để chuyển nhóm hoặc tạo nhóm mới.
class GroupsSheet extends StatelessWidget {
  const GroupsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Nhóm của bạn', style: text.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final group in state.groups)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: TachColors.mintWash,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          group.type.icon,
                          size: 22,
                          color: TachColors.mintDeep,
                        ),
                      ),
                      title: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      subtitle: Text(
                        '${group.type.label}, ${group.members.length} người',
                        style: text.bodySmall,
                      ),
                      trailing: group.id == state.currentGroupId
                          ? const Icon(
                              Icons.check_circle,
                              color: TachColors.mint,
                              semanticLabel: 'Đang mở',
                            )
                          : null,
                      onTap: () =>
                          Navigator.of(context).pop(OpenGroup(group.id)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(const CreateNewGroup()),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Tạo nhóm mới'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
