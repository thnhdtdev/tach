enum SettlementStatus { pending, confirmed }

class Settlement {
  const Settlement({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.transferCode,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String fromId;
  final String toId;
  final int amount;
  final String transferCode;
  final SettlementStatus status;
  final DateTime createdAt;

  Settlement copyWith({SettlementStatus? status}) {
    return Settlement(
      id: id,
      fromId: fromId,
      toId: toId,
      amount: amount,
      transferCode: transferCode,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class Transfer {
  const Transfer({
    required this.fromId,
    required this.toId,
    required this.amount,
  });

  final String fromId;
  final String toId;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Transfer &&
      other.fromId == fromId &&
      other.toId == toId &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(fromId, toId, amount);

  @override
  String toString() => 'Transfer($fromId -> $toId: $amount)';
}
