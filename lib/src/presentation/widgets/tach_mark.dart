import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

class TachMark extends StatelessWidget {
  const TachMark({super.key, this.size = 72, this.color = TachColors.mint});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TachMarkPainter(color),
    );
  }
}

class _TachMarkPainter extends CustomPainter {
  const _TachMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.4;
    final shift = size.shortestSide * 0.07;
    final gap = size.shortestSide * 0.035;

    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.11;
    final pupil = Paint()..color = color;

    void half({required bool left}) {
      canvas.save();
      canvas.clipRect(
        left
            ? Rect.fromLTRB(0, 0, center.dx - gap, size.height)
            : Rect.fromLTRB(center.dx + gap, 0, size.width, size.height),
      );
      final c = center.translate(0, left ? -shift : shift);
      canvas.drawCircle(c, radius, ring);
      canvas.drawCircle(c, radius * 0.36, pupil);
      canvas.restore();
    }

    half(left: true);
    half(left: false);
  }

  @override
  bool shouldRepaint(_TachMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
