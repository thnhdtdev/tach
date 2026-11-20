String timeAgo(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  final daysApart = today.difference(day).inDays;
  if (daysApart == 0) return '${diff.inHours} giờ trước';
  if (daysApart == 1) return 'Hôm qua';
  if (daysApart < 7) return '$daysApart ngày trước';

  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.day)}/${two(time.month)}';
}
