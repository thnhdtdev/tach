import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/format/vnd_input_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/budget.dart';
import 'budget_cubit.dart';

/// Mở bảng đặt hũ cho [month]. Mức mới áp dụng từ tháng đó, các tháng trước
/// giữ nguyên.
Future<void> showJarSheet(
  BuildContext context, {
  required DateTime month,
  Budget? current,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: context.read<BudgetCubit>(),
      child: _JarSheet(month: month, current: current),
    ),
  );
}

class _JarSheet extends StatefulWidget {
  const _JarSheet({required this.month, required this.current});

  final DateTime month;
  final Budget? current;

  @override
  State<_JarSheet> createState() => _JarSheetState();
}

class _JarSheetState extends State<_JarSheet> {
  static const _quick = [3000000, 5000000, 7000000, 10000000];

  late final _amount = TextEditingController(
    text: widget.current == null ? '' : formatThousands(widget.current!.amount),
  );
  late var _includePersonal = widget.current?.includePersonal ?? true;
  late var _repeats = widget.current?.repeats ?? true;

  int get _value => VndInputFormatter.valueOf(_amount.text);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    context.read<BudgetCubit>().set(
      Budget(
        period: widget.month,
        amount: _value,
        includePersonal: _includePersonal,
        repeats: _repeats,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = _value;

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
          Text('Hũ chi tiêu tháng', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Mỗi tháng bạn muốn tiêu tối đa bao nhiêu?',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            autofocus: widget.current == null,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [VndInputFormatter()],
            style: text.displaySmall,
            cursorColor: TachColors.mintLight,
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: text.displaySmall?.copyWith(color: TachColors.soft),
              suffixText: 'đ',
              suffixStyle: text.titleLarge?.copyWith(color: TachColors.soft),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: TachColors.hairline, width: 2),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: TachColors.mint, width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final amount in _quick)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(formatShortVnd(amount)),
                    selected: value == amount,
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: value == amount
                          ? TachColors.mintLight
                          : Colors.transparent,
                    ),
                    backgroundColor: TachColors.fill,
                    selectedColor: TachColors.mintTint,
                    labelStyle: text.labelLarge?.copyWith(
                      color: value == amount
                          ? TachColors.mintLight
                          : Colors.white,
                    ),
                    onSelected: (_) =>
                        setState(() => _amount.text = formatThousands(amount)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TachColors.mintTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Chỉ tính phần của bạn. Bữa lẩu 600k chia 4 thì trừ 150k, kể cả '
              'khi bạn là người trả cả bữa. Không ai khác thấy hũ này.',
              style: text.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tính cả khoản "Chỉ mình tôi"'),
            value: _includePersonal,
            activeTrackColor: TachColors.mint,
            onChanged: (on) => setState(() => _includePersonal = on),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tự áp dụng cho tháng sau'),
            value: _repeats,
            activeTrackColor: TachColors.mint,
            onChanged: (on) => setState(() => _repeats = on),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: value > 0 ? _save : null,
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
