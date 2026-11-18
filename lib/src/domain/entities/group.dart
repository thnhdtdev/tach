import 'dart:typed_data';

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
  const Member({
    required this.id,
    required this.name,
    this.bank,
    this.avatarBytes,
  });

  final String id;
  final String name;
  final BankAccount? bank;

  /// Ảnh đại diện đã chọn, giữ trong bộ nhớ. Khi có nơi lưu ảnh trên máy chủ
  /// thì trường này sẽ thay bằng đường dẫn ảnh.
  final Uint8List? avatarBytes;

  Member copyWith({String? name}) => Member(
    id: id,
    name: name ?? this.name,
    bank: bank,
    avatarBytes: avatarBytes,
  );

  /// Đặt lại tài khoản nhận tiền; truyền `null` để gỡ tài khoản.
  Member withBank(BankAccount? bank) =>
      Member(id: id, name: name, bank: bank, avatarBytes: avatarBytes);

  /// Đặt lại ảnh đại diện; truyền `null` để gỡ ảnh.
  Member withAvatar(Uint8List? bytes) =>
      Member(id: id, name: name, bank: bank, avatarBytes: bytes);
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

  Group copyWith({List<Member>? members}) =>
      Group(id: id, name: name, code: code, members: members ?? this.members);
}
