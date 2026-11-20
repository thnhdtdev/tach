import 'dart:typed_data';

class BankAccount {
  const BankAccount({
    required this.bin,
    required this.bankName,
    required this.accountNumber,
    required this.holderName,
  });

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

  final Uint8List? avatarBytes;

  Member copyWith({String? name}) => Member(
    id: id,
    name: name ?? this.name,
    bank: bank,
    avatarBytes: avatarBytes,
  );

  Member withBank(BankAccount? bank) =>
      Member(id: id, name: name, bank: bank, avatarBytes: avatarBytes);

  Member withAvatar(Uint8List? bytes) =>
      Member(id: id, name: name, bank: bank, avatarBytes: bytes);
}

enum GroupType {
  room,
  trip,
  family,

  /// Nhóm "Riêng tôi": chỉ có người dùng, chứa các khoản chi riêng. Không ai
  /// khác thấy và không mời ai vào được.
  personal;

  /// Các loại để chọn khi tạo nhóm chung.
  static const shared = [room, trip, family];
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.inviteCode,
    required this.createdBy,
    required this.members,
    this.formerMembers = const [],
  });

  final String id;
  final String name;

  /// Mã ngắn không dấu, dùng trong nội dung chuyển khoản (ví dụ `TRO12`).
  final String code;
  final GroupType type;

  /// Mã gửi cho người khác để họ vào nhóm.
  final String inviteCode;

  final String createdBy;

  final List<Member> members;

  /// Người đã rời nhóm, giữ lại để các khoản cũ còn hiện tên họ.
  final List<Member> formerMembers;

  bool get isPersonal => type == GroupType.personal;

  /// Đổi tên không đổi [code], để nội dung chuyển khoản của nhóm giữ nguyên.
  Group copyWith({String? name, List<Member>? members}) => Group(
    id: id,
    name: name ?? this.name,
    code: code,
    type: type,
    inviteCode: inviteCode,
    createdBy: createdBy,
    members: members ?? this.members,
    formerMembers: formerMembers,
  );
}
