import 'dart:typed_data';

class Comment {
  const Comment({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.parentId,
  });

  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;

  /// Id bình luận gốc khi đây là một câu trả lời; `null` nếu là bình luận gốc.
  final String? parentId;
}

class Expense {
  const Expense({
    required this.id,
    required this.payerId,
    required this.amount,
    required this.note,
    required this.splits,
    required this.createdAt,
    this.photoUrl,
    this.photoBytes,
    this.reactions = const {},
    this.comments = const [],
  });

  final String id;
  final String payerId;

  /// Số tiền bằng đồng, luôn là số nguyên.
  final int amount;
  final String note;

  /// Đường dẫn ảnh. `null` khi khoản không có ảnh, hoặc ảnh vừa chụp còn
  /// nằm trong [photoBytes].
  final String? photoUrl;

  /// Ảnh vừa chụp, giữ trong bộ nhớ cho tới khi có nơi tải lên máy chủ.
  final Uint8List? photoBytes;

  /// `false` với khoản ghi không cần ảnh (tiền phòng, wifi...).
  bool get hasPhoto => photoUrl != null || photoBytes != null;

  /// Phần mỗi người phải chịu, theo id thành viên. Tổng bằng [amount].
  final Map<String, int> splits;
  final DateTime createdAt;

  /// Cảm xúc của từng người, theo id thành viên. Mỗi người một cảm xúc.
  final Map<String, String> reactions;
  final List<Comment> comments;

  Expense copyWith({Map<String, String>? reactions, List<Comment>? comments}) {
    return Expense(
      id: id,
      payerId: payerId,
      amount: amount,
      note: note,
      photoUrl: photoUrl,
      photoBytes: photoBytes,
      splits: splits,
      createdAt: createdAt,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
    );
  }
}
