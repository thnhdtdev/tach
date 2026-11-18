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

/// Nhóm dùng để làm gì. Quyết định gợi ý tên và cách gọi trong giao diện.
enum GroupType { room, trip, family }

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.inviteCode,
    required this.createdBy,
    required this.members,
  });

  final String id;
  final String name;

  /// Mã ngắn không dấu, dùng trong nội dung chuyển khoản (ví dụ `TRO12`).
  final String code;
  final GroupType type;

  /// Mã gửi cho người khác để họ vào nhóm.
  final String inviteCode;

  /// Id người tạo nhóm. Chỉ người này được xóa nhóm.
  final String createdBy;
  final List<Member> members;

  /// Đổi tên không đổi [code], để nội dung chuyển khoản của nhóm giữ nguyên.
  Group copyWith({String? name, List<Member>? members}) => Group(
    id: id,
    name: name ?? this.name,
    code: code,
    type: type,
    inviteCode: inviteCode,
    createdBy: createdBy,
    members: members ?? this.members,
  );
}
