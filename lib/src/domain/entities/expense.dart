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
    this.editedAt,
    this.photoUrl,
    this.photoBytes,
    this.reactions = const {},
    this.comments = const [],
  });

  final String id;
  final String payerId;

  final int amount;
  final String note;

  final String? photoUrl;

  final Uint8List? photoBytes;

  bool get hasPhoto => photoUrl != null || photoBytes != null;

  final Map<String, int> splits;
  final DateTime createdAt;

  /// Lần gần nhất người ghi sửa khoản này; `null` nếu chưa sửa lần nào.
  final DateTime? editedAt;

  final Map<String, String> reactions;
  final List<Comment> comments;

  Expense copyWith({
    int? amount,
    String? note,
    Map<String, int>? splits,
    DateTime? editedAt,
    Map<String, String>? reactions,
    List<Comment>? comments,
  }) {
    return Expense(
      id: id,
      payerId: payerId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      photoUrl: photoUrl,
      photoBytes: photoBytes,
      splits: splits ?? this.splits,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
    );
  }
}
