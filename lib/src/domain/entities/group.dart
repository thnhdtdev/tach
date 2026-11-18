/// Tài khoản ngân hàng để nhận tiền qua VietQR.
class BankAccount {
  const BankAccount({
    required this.bin,
    required this.bankName,
    required this.accountNumber,
    required this.holderName,
  });

  /// Mã BIN 6 số của ngân hàng theo NAPAS.
  final String bin;
  final String bankName;
  final String accountNumber;
  final String holderName;
}

class Member {
  const Member({required this.id, required this.name, this.bank});

  final String id;
  final String name;
  final BankAccount? bank;
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.code,
    required this.members,
  });

  final String id;
  final String name;

  /// Mã ngắn không dấu, dùng trong nội dung chuyển khoản (ví dụ `TRO12`).
  final String code;
  final List<Member> members;
}
