import 'package:flutter/services.dart';

import 'money.dart';

/// Hiện số tiền có dấu chấm ngăn hàng nghìn ngay khi gõ.
class VndInputFormatter extends TextInputFormatter {
  // Giới hạn như lúc ghi khoản mới: dưới một tỷ đồng.
  static const _maxDigits = 9;

  /// Số tiền đang hiện trong ô nhập, 0 nếu ô trống.
  static int valueOf(String text) =>
      int.tryParse(text.replaceAll('.', '')) ?? 0;

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
