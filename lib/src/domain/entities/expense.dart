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
