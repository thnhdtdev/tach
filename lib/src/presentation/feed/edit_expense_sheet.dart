import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../ledger/ledger_cubit.dart';

/// Đóng lại với `true` khi khoản chi đã được sửa.
class EditExpenseSheet extends StatefulWidget {
  const EditExpenseSheet({super.key, required this.expense});

  final Expense expense;

  @override
  State<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<EditExpenseSheet> {
  late final _amount = TextEditingController(
    text: formatThousands(widget.expense.amount),
  );
  late final _note = TextEditingController(text: widget.expense.note);
  late final _included = {...widget.expense.splits.keys};

  int get _value => int.tryParse(_amount.text.replaceAll('.', '')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: TachColors.mintWash.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<LedgerCubit>();
    final state = cubit.state;
    final expense = widget.expense;

    // Người đã rời nhóm mà có phần trong khoản này vẫn hiện, để sửa số tiền
    // không lặng lẽ gạt họ ra.
    final people = [
      for (final m in state.group.members) m.id,
      for (final id in expense.splits.keys)
        if (!state.group.members.any((m) => m.id == id)) id,
    ];
    final participants = [
      for (final id in people)
        if (_included.contains(id)) id,
    ];

    final value = _value;
    final moneyChanged =
        value != expense.amount ||
        !setEquals(_included, expense.splits.keys.toSet());
    final changed = moneyChanged || _note.text.trim() != expense.note;
    final canSave = value > 0 && participants.isNotEmpty && changed;

    final summary = value == 0
        ? 'Nhập số tiền của khoản chi'
        : participants.isEmpty
        ? 'Chọn ít nhất một người'
        : 'Chia đều ${participants.length} người, mỗi người '
              '${formatVnd(value ~/ participants.length)}';

    return SingleChildScrollView(
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
          Text('Sửa khoản chi', style: text.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [_VndFormatter()],
            style: text.headlineSmall,
            decoration: _field('Số tiền', suffix: 'đ'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            style: text.titleMedium,
            decoration: _field('Ghi chú'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          Text('Chia cho', style: text.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final id in people)
                FilterChip(
                  label: Text(state.displayName(id)),
                  selected: _included.contains(id),
                  selectedColor: TachColors.mintWash,
                  checkmarkColor: TachColors.mintDeep,
                  onSelected: (selected) => setState(() {
                    selected ? _included.add(id) : _included.remove(id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(summary, style: text.bodyMedium),
          if (moneyChanged && state.settlements.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Nhóm đã có lần chuyển tiền. Sau khi lưu, số dư của mọi người '
              'được tính lại theo khoản đã sửa.',
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: canSave
                ? () => Navigator.of(context).pop(
                    cubit.editExpense(
                      expense.id,
                      amount: value,
                      note: _note.text,
                      participantIds: participants,
                    ),
                  )
                : null,
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }
}

/// Hiện số tiền có dấu chấm ngăn hàng nghìn ngay khi gõ.
class _VndFormatter extends TextInputFormatter {
  // Giới hạn như lúc ghi khoản mới: dưới một tỷ đồng.
  static const _maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp('^0+'), '');
    if (digits.length > _maxDigits) return oldValue;
    final text = digits.isEmpty ? '' : formatThousands(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
