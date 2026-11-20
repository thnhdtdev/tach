import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/group.dart';
import '../ledger/ledger_cubit.dart';
import 'group_invite_screen.dart';
import 'group_type_ui.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  var _type = GroupType.room;

  bool get _canCreate => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final group = context.read<LedgerCubit>().createGroup(
      name: _name.text,
      type: _type,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GroupInviteScreen(groupId: group.id, justCreated: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo nhóm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Nhóm này để làm gì?', style: text.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final type in GroupType.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: type == GroupType.values.last ? 0 : 8,
                    ),
                    child: _TypeOption(
                      type: type,
                      selected: _type == type,
                      onTap: () => setState(() => _type = type),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Tên nhóm', style: text.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            style: text.titleMedium,
            decoration: InputDecoration(
              hintText: _type.nameHint,
              hintStyle: text.titleMedium?.copyWith(
                color: TachColors.soft.withValues(alpha: 0.7),
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: TachColors.fill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canCreate) _create();
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Tạo xong bạn sẽ có mã mời để gửi cho mọi người.',
            style: text.bodyMedium,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: FilledButton(
            onPressed: _canCreate ? _create : null,
            child: const Text('Tạo nhóm'),
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final GroupType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = selected ? TachColors.mintLight : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? TachColors.mintTint : TachColors.nightRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? TachColors.mintLight : TachColors.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
            child: Column(
              children: [
                Icon(type.icon, size: 28, color: color),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    type.label,
                    style: text.labelLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
