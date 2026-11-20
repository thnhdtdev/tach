import 'package:material_ui/material_ui.dart';

/// Vuốt ngang ở bất kỳ đâu trên màn để quay về màn trước. Hướng vuốt ngược với
/// hướng đã vuốt để mở màn đó.
class SwipeToClose extends StatefulWidget {
  const SwipeToClose({
    super.key,
    required this.towardsRight,
    required this.child,
  });

  final bool towardsRight;
  final Widget child;

  @override
  State<SwipeToClose> createState() => _SwipeToCloseState();
}

class _SwipeToCloseState extends State<SwipeToClose> {
  var _dx = 0.0;

  void _onEnd(DragEndDetails details) {
    final sign = widget.towardsRight ? 1 : -1;
    final distance = _dx * sign;
    final velocity = (details.primaryVelocity ?? 0) * sign;
    if ((distance > 72 && velocity >= 0) || velocity > 600) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (details) => _dx += details.primaryDelta ?? 0,
      onHorizontalDragEnd: _onEnd,
      child: widget.child,
    );
  }
}
