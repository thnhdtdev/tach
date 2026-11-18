/// Định dạng tiền VND. Tiền luôn là số nguyên đồng.
library;

/// `30000` thành `30.000`.
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// `30000` thành `30.000đ`.
String formatVnd(int amount) => '${formatThousands(amount)}đ';

/// Dạng ngắn cho ô ảnh nhỏ: `30000` thành `30k`, `1200000` thành `1,2tr`.
String formatShortVnd(int amount) {
  String scaled(int unit, String suffix) {
    final tenths = (amount * 10 / unit).round();
    final whole = tenths ~/ 10;
    final frac = tenths % 10;
    return frac == 0 ? '$whole$suffix' : '$whole,$frac$suffix';
  }

  if (amount < 1000) return '$amountđ';
  if (amount < 1000000) return scaled(1000, 'k');
  return scaled(1000000, 'tr');
}
