import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/expense.dart';
import '../../domain/logic/recap.dart';
import '../ledger/ledger_cubit.dart';
import '../widgets/expense_photo.dart';
import '../widgets/member_avatar.dart';
import '../widgets/tach_mark.dart';

/// Ảnh tổng kết tháng, khổ dọc 9:16 để đăng story. Vẽ ở cỡ 360×640 rồi xuất
/// ra gấp ba lần.
class RecapPoster extends StatelessWidget {
  const RecapPoster({
    super.key,
    required this.state,
    required this.recap,
    required this.photos,
  });

  static const size = Size(360, 640);

  final LedgerState state;
  final MonthRecap recap;

  /// Ảnh đã tải của từng khoản nổi bật, theo id khoản chi.
  final Map<String, Uint8List> photos;

  @override
  Widget build(BuildContext context) {
    const soft = TextStyle(fontSize: 13, color: TachColors.soft, height: 1.3);

    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                TachColors.mint.withValues(alpha: 0.3),
                TachColors.night,
              ),
              TachColors.night,
            ],
            stops: const [0, 0.55],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TachLogo(height: 22),
                const SizedBox(height: 14),
                Text(
                  'Tháng ${recap.month.month}',
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -1.5,
                  ),
                ),
                Text(
                  state.group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: TachColors.mintLight,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _Collage(recap: recap, photos: photos),
                ),
                const SizedBox(height: 14),
                const Text('Cả nhóm đã chi', style: soft),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatVnd(recap.total),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${recap.count} khoản, ${recap.photoCount} ảnh, '
                  '${state.group.members.length} người',
                  style: soft,
                ),
                const SizedBox(height: 12),
                for (final payer in recap.payers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        MemberAvatar(
                          name: state.member(payer.memberId).name,
                          tone: state.toneOf(payer.memberId),
                          photo: state.member(payer.memberId).avatarBytes,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.member(payer.memberId).name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          'đã trả ${formatVnd(payer.paid)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Chụp là ghi, tách là xong.',
                  style: TextStyle(fontSize: 12, color: TachColors.soft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Các ảnh nổi bật xếp so le và nghiêng nhẹ, như một xấp ảnh rải trên bàn.
class _Collage extends StatelessWidget {
  const _Collage({required this.recap, required this.photos});

  static const _tilts = [-5.0, 4.0, -3.0, 6.0, -4.0];
  static const _sides = [0.92, 0.78, 0.66, 0.58, 0.52];

  final MonthRecap recap;
  final Map<String, Uint8List> photos;

  @override
  Widget build(BuildContext context) {
    final items = recap.highlights;
    if (items.isEmpty) {
      return Center(
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: TachColors.mint,
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Center(child: TachMark(size: 76, color: Colors.white)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final count = items.length;
        final side = math.min(
          box.maxHeight * _sides[count - 1],
          box.maxWidth * 0.9,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, expense) in items.indexed)
              Positioned(
                left: count == 1
                    ? (box.maxWidth - side) / 2
                    : i * (box.maxWidth - side) / (count - 1),
                top: (box.maxHeight - side) * (i.isEven ? 0.08 : 0.92),
                width: side,
                height: side,
                child: Transform.rotate(
                  angle: _tilts[i] * math.pi / 180,
                  child: _Print(expense: expense, bytes: photos[expense.id]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Print extends StatelessWidget {
  const _Print({required this.expense, required this.bytes});

  final Expense expense;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            else
              ExpensePhoto(
                photoUrl: expense.photoUrl,
                photoBytes: expense.photoBytes,
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  formatShortVnd(expense.amount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
