import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../ledger/ledger_cubit.dart';

/// Bảng đổi tên hiển thị.
class RenameSheet extends StatefulWidget {
  const RenameSheet({super.key, required this.currentName});

  final String currentName;

  @override
  State<RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<RenameSheet> {
  late final _name = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    context.read<LedgerCubit>().renameMe(_name.text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canSave = _name.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Đổi tên', style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Cả nhóm sẽ thấy tên này ở mỗi khoản chi của bạn.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(24)],
            style: text.titleMedium,
            decoration: InputDecoration(
              hintText: 'Tên của bạn',
              filled: true,
              fillColor: TachColors.mintWash.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canSave) _save();
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canSave ? _save : null,
            child: const Text('Lưu tên'),
          ),
        ],
      ),
    );
  }
}
