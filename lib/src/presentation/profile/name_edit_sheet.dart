import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

class NameEditSheet extends StatefulWidget {
  const NameEditSheet({
    super.key,
    required this.title,
    required this.description,
    required this.initialName,
    required this.hint,
    required this.maxLength,
    required this.onSave,
  });

  final String title;
  final String description;
  final String initialName;
  final String hint;
  final int maxLength;

  final ValueChanged<String> onSave;

  @override
  State<NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends State<NameEditSheet> {
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(_name.text);
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
          Text(widget.title, style: text.titleLarge),
          const SizedBox(height: 6),
          Text(widget.description, style: text.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            style: text.titleMedium,
            decoration: InputDecoration(
              hintText: widget.hint,
              filled: true,
              fillColor: TachColors.fill,
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
