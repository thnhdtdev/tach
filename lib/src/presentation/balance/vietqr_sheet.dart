import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/settlement.dart';
import '../../services/vietqr/vietqr_payload.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/info_line.dart';

/// Bảng trượt lên để trả một khoản bằng VietQR.
///
/// App chỉ tạo mã; người dùng tự chuyển trong app ngân hàng rồi báo đã chuyển.
class VietQrSheet extends StatefulWidget {
  const VietQrSheet({super.key, required this.transfer});

  final Transfer transfer;

  @override
  State<VietQrSheet> createState() => _VietQrSheetState();
}

class _VietQrSheetState extends State<VietQrSheet> {
  var _copied = false;

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cubit = context.read<LedgerCubit>();
    final transfer = widget.transfer;
    final receiver = cubit.state.member(transfer.toId);
    final bank = receiver.bank;
    final code = cubit.transferCodeFor(transfer);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Trả ${receiver.name}', style: text.titleLarge),
            Text(
              formatVnd(transfer.amount),
              style: text.displaySmall?.copyWith(color: TachColors.mint),
            ),
            const SizedBox(height: 16),
            if (bank == null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: TachColors.mintWash,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${receiver.name} chưa thêm tài khoản ngân hàng nên chưa có '
                  'mã QR. Bạn có thể trả tiền mặt rồi báo đã trả.',
                  style: text.bodyLarge?.copyWith(color: TachColors.mintDeep),
                ),
              )
            else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: TachColors.line),
                  ),
                  child: QrImageView(
                    data: buildVietQrPayload(
                      bankBin: bank.bin,
                      accountNumber: bank.accountNumber,
                      amount: transfer.amount,
                      content: code,
                    ),
                    size: 208,
                    padding: EdgeInsets.zero,
                    semanticsLabel: 'Mã VietQR trả ${receiver.name}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InfoLine(label: 'Ngân hàng', value: bank.bankName),
              InfoLine(label: 'Số tài khoản', value: bank.accountNumber),
              InfoLine(label: 'Chủ tài khoản', value: bank.holderName),
            ],
            Row(
              children: [
                Expanded(
                  child: InfoLine(label: 'Nội dung', value: code),
                ),
                TextButton.icon(
                  onPressed: () => _copy(code),
                  style: TextButton.styleFrom(
                    foregroundColor: TachColors.mintDeep,
                    minimumSize: const Size(64, 44),
                  ),
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                  label: Text(_copied ? 'Đã chép' : 'Chép'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                cubit.markTransferred(transfer);
                Navigator.of(context).pop();
              },
              child: Text(
                bank == null ? 'Tôi đã trả tiền mặt' : 'Tôi đã chuyển khoản',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${receiver.name} sẽ xác nhận khi nhận được tiền.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
