/// Mức chi tiêu một tháng của người dùng ("Hũ của tôi").
class Budget {
  Budget({
    required DateTime period,
    required this.amount,
    this.includePersonal = true,
    this.repeats = true,
  }) : period = DateTime(period.year, period.month);

  /// Ngày đầu của tháng mà mức này bắt đầu áp dụng.
  final DateTime period;
  final int amount;

  /// Có tính các khoản "Chỉ mình tôi" vào hũ hay không.
  final bool includePersonal;

  /// Tự áp dụng cho các tháng sau cho tới khi có mức mới.
  final bool repeats;
}
