/// Chia đều [amount] cho [participantIds].
///
/// Khi không chia hết, phần dư (vài đồng) tính cho người trả nếu người đó có
/// tham gia chia, nếu không thì tính cho người đầu tiên trong danh sách. Tổng
/// các phần luôn đúng bằng [amount].
Map<String, int> splitEqually({
  required int amount,
  required List<String> participantIds,
  required String payerId,
}) {
  if (amount < 0) {
    throw ArgumentError.value(amount, 'amount', 'Số tiền không được âm');
  }
  if (participantIds.isEmpty) {
    throw ArgumentError.value(
      participantIds,
      'participantIds',
      'Cần ít nhất một người chia',
    );
  }

  final base = amount ~/ participantIds.length;
  final remainder = amount - base * participantIds.length;
  final shares = {for (final id in participantIds) id: base};
  final absorber = participantIds.contains(payerId)
      ? payerId
      : participantIds.first;
  shares[absorber] = base + remainder;
  return shares;
}
