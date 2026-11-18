import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Avatar tròn: ảnh đại diện nếu có, nếu không thì chữ cái đầu của tên trên
/// nền màu riêng từng người.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.name,
    required this.tone,
    this.photo,
    this.size = 36,
  });

  final String name;
  final Color tone;
  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = Container(
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

    final bytes = photo;
    if (bytes == null) return initial;

    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        semanticLabel: 'Ảnh đại diện của $name',
        // Ảnh hỏng thì quay về chữ cái đầu thay vì để ô trống.
        errorBuilder: (_, _, _) => initial,
      ),
    );
  }
}
