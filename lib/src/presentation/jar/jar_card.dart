import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/budget.dart';
import '../../domain/logic/jar.dart';
import 'jar_view.dart';

/// Thẻ "Hũ của tôi": đã tiêu bao nhiêu trên mức đặt, còn lại và mức mỗi ngày.
class JarCard extends StatelessWidget {
  const JarCard({
    super.key,
    required this.jar,
    required this.budget,
    required this.onSet,
    this.onDetail,
    this.title = 'Hũ của tôi',
    this.segments = const [],
  });

  final JarMonth jar;
  final Budget? budget;
  final VoidCallback onSet;
  final VoidCallback? onDetail;
  final String title;

  /// Chia thanh tiến độ theo nhóm; rỗng thì thanh một màu theo mức đã dùng.
  final List<({Color color, int amount})> segments;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final budget = this.budget;
    final now = DateTime.now();
    final isCurrent =
        jar.month.year == now.year && jar.month.month == now.month;

    return Material(
      color: TachColors.nightRaised,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: text.bodyMedium)),
                  if (onDetail != null)
                    Text(
                      'Xem chi tiết',
                      style: text.bodyMedium?.copyWith(
                        color: TachColors.mintLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatThousands(jar.spent),
                        style: text.headlineMedium,
                      ),
                      TextSpan(
                        text: budget == null
                            ? 'đ'
                            : ' / ${formatVnd(budget.amount)}',
                        style: text.bodyLarge?.copyWith(color: TachColors.soft),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (budget == null) ...[
                Text(
                  'Đặt mức chi tiêu cho tháng để biết mình còn được tiêu '
                  'bao nhiêu mỗi ngày.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onSet,
                  child: const Text('Đặt hũ tháng'),
                ),
              ] else ...[
                _Bar(jar: jar, budget: budget, segments: segments),
                const SizedBox(height: 10),
                _Remaining(jar: jar, budget: budget, isCurrent: isCurrent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.jar, required this.budget, required this.segments});

  final JarMonth jar;
  final Budget budget;
  final List<({Color color, int amount})> segments;

  @override
  Widget build(BuildContext context) {
    final total = jar.spent > budget.amount ? jar.spent : budget.amount;
    final parts = segments.isEmpty
        ? [(color: progressColor(jar.spent, budget), amount: jar.spent)]
        : segments;
    final rest = total - jar.spent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final part in parts)
              if (part.amount > 0)
                Expanded(
                  flex: part.amount,
                  child: Container(
                    margin: const EdgeInsets.only(right: 2),
                    color: part.color,
                  ),
                ),
            if (rest > 0)
              Expanded(
                flex: rest,
                child: const ColoredBox(color: TachColors.fill),
              ),
          ],
        ),
      ),
    );
  }
}

class _Remaining extends StatelessWidget {
  const _Remaining({
    required this.jar,
    required this.budget,
    required this.isCurrent,
  });

  final JarMonth jar;
  final Budget budget;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = budget.amount - jar.spent;
    final daysLeft = jar.daysInMonth - DateTime.now().day;
    final percent = jar.spent * 100 ~/ budget.amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: remaining >= 0 ? 'Còn ' : 'Vượt ',
                  children: [
                    TextSpan(
                      text: formatVnd(remaining.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: remaining >= 0
                            ? Colors.white
                            : TachColors.danger,
                      ),
                    ),
                  ],
                ),
                style: text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
            if (isCurrent && remaining > 0 && daysLeft > 0)
              Text(
                '~${formatShortVnd(remaining ~/ daysLeft)}/ngày, '
                'còn $daysLeft ngày',
                style: text.bodyMedium?.copyWith(color: TachColors.mintLight),
              ),
          ],
        ),
        // Thay cho thông báo đẩy: nhắc ngay trên thẻ khi đã dùng từ 80%.
        if (percent >= 80 && remaining >= 0) ...[
          const SizedBox(height: 6),
          Text(
            'Bạn đã dùng $percent% hũ tháng này.',
            style: text.bodySmall?.copyWith(color: TachColors.warn),
          ),
        ],
      ],
    );
  }
}
