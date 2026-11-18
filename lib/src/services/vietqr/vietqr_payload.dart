/// Tạo chuỗi mã VietQR (chuẩn EMVCo của NAPAS) để chuyển khoản tới tài khoản.
///
/// App chỉ tạo mã để người dùng tự chuyển trong app ngân hàng, không giữ tiền.
library;

String _field(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';

/// CRC-16/CCITT-FALSE (đa thức 0x1021, khởi tạo 0xFFFF) theo chuẩn EMVCo.
int crc16(String text) {
  var crc = 0xFFFF;
  for (final byte in text.codeUnits) {
    crc ^= byte << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
      crc &= 0xFFFF;
    }
  }
  return crc;
}

/// Chuỗi để vẽ thành mã QR chuyển [amount] đồng tới [accountNumber] tại ngân
/// hàng có mã [bankBin], kèm nội dung chuyển khoản [content] (không dấu).
String buildVietQrPayload({
  required String bankBin,
  required String accountNumber,
  required int amount,
  required String content,
}) {
  final beneficiary = [
    _field('00', bankBin),
    _field('01', accountNumber),
  ].join();
  final account = [
    _field('00', 'A000000727'),
    _field('01', beneficiary),
    _field('02', 'QRIBFTTA'),
  ].join();

  final body = [
    _field('00', '01'),
    _field('01', '12'),
    _field('38', account),
    _field('53', '704'),
    _field('54', amount.toString()),
    _field('58', 'VN'),
    _field('62', _field('08', content)),
    '6304',
  ].join();

  final checksum = crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$body$checksum';
}
