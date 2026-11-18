/// Một ngân hàng nhận chuyển khoản qua VietQR.
class Bank {
  const Bank({required this.bin, required this.name});

  /// Mã BIN 6 số theo NAPAS, nằm trong chuỗi mã QR.
  final String bin;
  final String name;
}

/// Các ngân hàng phổ biến. Danh sách đầy đủ sẽ lấy từ máy chủ sau.
const vietnamBanks = [
  Bank(bin: '970436', name: 'Vietcombank'),
  Bank(bin: '970415', name: 'VietinBank'),
  Bank(bin: '970418', name: 'BIDV'),
  Bank(bin: '970405', name: 'Agribank'),
  Bank(bin: '970407', name: 'Techcombank'),
  Bank(bin: '970422', name: 'MB Bank'),
  Bank(bin: '970416', name: 'ACB'),
  Bank(bin: '970432', name: 'VPBank'),
  Bank(bin: '970423', name: 'TPBank'),
  Bank(bin: '970403', name: 'Sacombank'),
];
