import 'dart:math' as math;

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

class TachLogo extends StatelessWidget {
  const TachLogo({super.key, this.height = 30});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TachMark(size: height),
        SizedBox(width: height * 0.24),
        Text(
          'Tach',
          style: TextStyle(
            // Chữ hoa của Montserrat cao 0,7 cỡ chữ; logo gốc để chữ cao 0,56
            // chiều cao biểu tượng.
            fontSize: height * 0.8,
            height: 1,
            fontWeight: FontWeight.w700,
            color: TachColors.mintDeep,
          ),
        ),
      ],
    );
  }
}

class _TachMarkPainter extends CustomPainter {
  const _TachMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Tọa độ lấy từ bản vẽ gốc: biểu tượng nằm trong ô vuông 64 đơn vị,
    // gốc tọa độ đặt ở tâm.
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(size.shortestSide / 64);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final corner = Path()
      ..moveTo(-28, -12)
      ..lineTo(-28, -20)
      ..arcToPoint(const Offset(-20, -28), radius: const Radius.circular(8))
      ..lineTo(-12, -28);
    for (var i = 0; i < 4; i++) {
      canvas
        ..drawPath(corner, stroke)
        ..rotate(math.pi / 2);
    }

    final fill = Paint()..color = color;
    const radius = Radius.circular(15);
    canvas
      ..rotate(math.pi / 4)
      ..drawPath(
        Path()
          ..moveTo(-3, -15)
          ..arcToPoint(const Offset(-3, 15), radius: radius, clockwise: false)
          ..close(),
        fill,
      )
      ..drawPath(
        Path()
          ..moveTo(3, -15)
          ..arcToPoint(const Offset(3, 15), radius: radius)
          ..close(),
        fill,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_TachMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
