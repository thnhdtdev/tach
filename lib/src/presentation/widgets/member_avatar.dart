import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Avatar tròn hiện chữ cái đầu của tên trên nền màu riêng từng người.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.tone,
    this.size = 36,
  });

  final String name;
  final Color tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: TachColors.ink,
          height: 1,
        ),
      ),
    );
  }
}
