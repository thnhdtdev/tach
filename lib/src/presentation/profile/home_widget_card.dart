import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';
import '../widgets/member_avatar.dart';
import '../widgets/tach_mark.dart';

/// Giới thiệu widget màn hình chính và cách thêm. iOS không cho app tự thêm
/// widget, nên chỉ hướng dẫn được.
class HomeWidgetCard extends StatelessWidget {
  const HomeWidgetCard({super.key});

  void _showSteps(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddWidgetSteps(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.watch<LedgerCubit>().state;

    return Row(
      children: [
        ExcludeSemantics(child: _WidgetPreview(state: state)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khoản chi mới nhất của nhóm, ngay trên màn hình chính.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _showSteps(context),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('Cách thêm widget'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.state});

  static const _side = 104.0;

  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    final latest = state.hasGroup && state.expenses.isNotEmpty
        ? state.expenses.first
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox.square(
        dimension: _side,
        child: latest == null
            ? const ColoredBox(
                color: TachColors.mint,
                child: Center(child: TachMark(size: 44, color: Colors.white)),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ExpensePhoto(
                    photoUrl: latest.photoUrl,
                    photoBytes: latest.photoBytes,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB3000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: MemberAvatar(
                        name: state.member(latest.payerId).name,
                        tone: state.toneOf(latest.payerId),
                        photo: state.member(latest.payerId).avatarBytes,
                        size: 22,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: Text(
                      formatShortVnd(latest.amount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AddWidgetSteps extends StatelessWidget {
  const _AddWidgetSteps();

  static const _steps = [
    'Về màn hình chính, nhấn giữ vào một chỗ trống cho tới khi các icon rung.',
    'Bấm "Sửa" ở góc trên rồi chọn "Thêm tiện ích". Trên iOS cũ hơn, bấm '
        'dấu cộng ở góc trên.',
    'Tìm "Tach", chọn cỡ nhỏ (ảnh khoản chi mới nhất) hoặc cỡ vừa (số tiền '
        'bạn cần trả), rồi bấm "Thêm tiện ích".',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thêm widget Tach', style: text.titleLarge),
            const SizedBox(height: 14),
            for (final (index, step) in _steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: TachColors.mintTint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: text.labelLarge?.copyWith(
                          color: TachColors.mintLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step, style: text.bodyLarge)),
                  ],
                ),
              ),
            Text(
              'Widget lấy theo nhóm đang mở và mới lại mỗi lần bạn mở Tach.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
