import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/transfer_code.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/group.dart';
import '../../services/vietqr/banks.dart';
import '../ledger/ledger_cubit.dart';

/// Bảng thêm hoặc sửa tài khoản ngân hàng nhận tiền.
class BankAccountSheet extends StatefulWidget {
  const BankAccountSheet({super.key, this.current});

  /// Tài khoản đang có; `null` khi thêm mới.
  final BankAccount? current;

  @override
  State<BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends State<BankAccountSheet> {
  static const _minAccountLength = 6;

  late String? _bin = widget.current?.bin;
  late final _account = TextEditingController(
    text: widget.current?.accountNumber,
  );
  late final _holder = TextEditingController(text: widget.current?.holderName);

  /// Tên chủ tài khoản viết hoa không dấu, đúng như ngân hàng hiển thị.
  String get _holderName => removeDiacritics(_holder.text.trim()).toUpperCase();

  bool get _canSave =>
      _bin != null &&
      _account.text.length >= _minAccountLength &&
      _holderName.isNotEmpty;

  @override
  void dispose() {
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _save() {
    final bank = vietnamBanks.firstWhere((b) => b.bin == _bin);
    context.read<LedgerCubit>().setMyBank(
      BankAccount(
        bin: bank.bin,
        bankName: bank.name,
        accountNumber: _account.text,
        holderName: _holderName,
      ),
    );
    Navigator.of(context).pop();
  }

  void _remove() {
    context.read<LedgerCubit>().setMyBank(null);
    Navigator.of(context).pop();
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
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
    final editing = widget.current != null;

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
          Text(
            editing ? 'Sửa tài khoản' : 'Thêm tài khoản',
            style: text.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Tach chỉ dùng thông tin này để tạo mã VietQR. Tiền chuyển thẳng '
            'vào tài khoản của bạn, không qua Tach.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _bin,
            decoration: _decoration('Ngân hàng'),
            style: text.bodyLarge,
            borderRadius: BorderRadius.circular(16),
            items: [
              for (final bank in vietnamBanks)
                DropdownMenuItem(value: bank.bin, child: Text(bank.name)),
            ],
            onChanged: (bin) => setState(() => _bin = bin),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _account,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
            ],
            style: text.bodyLarge,
            decoration: _decoration('Số tài khoản'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _holder,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            style: text.bodyLarge,
            decoration: _decoration('Tên chủ tài khoản'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Lưu tài khoản'),
          ),
          if (editing) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _remove,
              style: TextButton.styleFrom(
                foregroundColor: TachColors.inkSoft,
                minimumSize: const Size(64, 48),
              ),
              child: const Text('Gỡ tài khoản'),
            ),
          ],
        ],
      ),
    );
  }
}
