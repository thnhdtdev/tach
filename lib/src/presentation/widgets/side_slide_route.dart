import 'package:material_ui/material_ui.dart';

/// Màn trượt ngang vào theo hướng tay vuốt và trượt ra theo hướng ngược lại.
/// [fromLeft] là màn "nằm bên trái" màn chính (mở bằng cách vuốt từ trái sang
/// phải); ngược lại là màn nằm bên phải.
class SideSlideRoute<T> extends PageRouteBuilder<T> {
  SideSlideRoute({required WidgetBuilder builder, required this.fromLeft})
    : super(
        pageBuilder: (context, _, _) => builder(context),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (context, animation, _, child) {
          return SlideTransition(
            position:
                Tween(
                  begin: Offset(fromLeft ? -1 : 1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: child,
          );
        },
      );

  final bool fromLeft;
}

/// Màn đang hiện được mở từ bên trái hay theo kiểu thường (từ bên phải).
bool openedFromLeft(BuildContext context) {
  final route = ModalRoute.of(context);
  return route is SideSlideRoute && route.fromLeft;
}

/// Thanh tiêu đề cho màn có thể mở từ bên trái: khi đó nút quay về nằm bên
/// phải và chỉ sang phải, khớp với hướng màn trượt ra.
AppBar sideAppBar(BuildContext context, {required Widget title}) {
  final fromLeft = openedFromLeft(context);
  return AppBar(
    automaticallyImplyLeading: !fromLeft,
    title: title,
    actions: [
      if (fromLeft)
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_forward),
        ),
    ],
  );
}
