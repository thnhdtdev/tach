import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as picker;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Bảng chọn cảm xúc từ toàn bộ bộ emoji, chia theo nhóm.
///
/// Thư viện `emoji_picker_flutter` lo dữ liệu: danh sách emoji, mục dùng gần
/// đây và việc lọc emoji mà máy không hiển thị được. Phần giao diện tự dựng,
/// vì giao diện có sẵn của thư viện dùng bộ Material cũ, không ghép được với
/// `material_ui` của app.
class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({
    super.key,
    required this.current,
    required this.onPick,
    required this.onRemove,
  });

  static const _gridHeight = 320.0;

  /// Cảm xúc người dùng đang thả ở khoản chi này, nếu có.
  final String? current;
  final ValueChanged<String> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text('Thả cảm xúc', style: text.titleLarge)),
                if (current != null)
                  TextButton(
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      foregroundColor: TachColors.mintLight,
                      minimumSize: const Size(64, 44),
                    ),
                    child: const Text('Gỡ cảm xúc'),
                  )
                else
                  const SizedBox(height: 44),
              ],
            ),
          ),
          picker.EmojiPicker(
            config: const picker.Config(height: _gridHeight),
            onEmojiSelected: (_, emoji) => onPick(emoji.emoji),
            customWidget: (_, state, _) =>
                _EmojiBrowser(state: state, current: current),
          ),
        ],
      ),
    );
  }
}

/// Hàng nhóm emoji ở trên và lưới emoji của nhóm đang chọn ở dưới.
class _EmojiBrowser extends StatefulWidget {
  const _EmojiBrowser({required this.state, required this.current});

  final picker.EmojiViewState state;
  final String? current;

  @override
  State<_EmojiBrowser> createState() => _EmojiBrowserState();
}

class _EmojiBrowserState extends State<_EmojiBrowser> {
  static const _columns = 8;

  static const _icons = {
    picker.Category.RECENT: Icons.schedule,
    picker.Category.SMILEYS: Icons.emoji_emotions_outlined,
    picker.Category.ANIMALS: Icons.pets_outlined,
    picker.Category.FOODS: Icons.restaurant_outlined,
    picker.Category.ACTIVITIES: Icons.sports_soccer_outlined,
    picker.Category.TRAVEL: Icons.directions_car_outlined,
    picker.Category.OBJECTS: Icons.lightbulb_outline,
    picker.Category.SYMBOLS: Icons.emoji_symbols_outlined,
    picker.Category.FLAGS: Icons.flag_outlined,
  };

  static const _labels = {
    picker.Category.RECENT: 'Dùng gần đây',
    picker.Category.SMILEYS: 'Mặt cười và con người',
    picker.Category.ANIMALS: 'Động vật và thiên nhiên',
    picker.Category.FOODS: 'Đồ ăn và thức uống',
    picker.Category.ACTIVITIES: 'Hoạt động',
    picker.Category.TRAVEL: 'Du lịch và địa điểm',
    picker.Category.OBJECTS: 'Đồ vật',
    picker.Category.SYMBOLS: 'Ký hiệu',
    picker.Category.FLAGS: 'Cờ',
  };

  /// Bỏ các nhóm trống, ví dụ "Dùng gần đây" khi chưa chọn emoji nào.
  late final List<picker.CategoryEmoji> _groups = [
    for (final group in widget.state.categoryEmoji)
      if (group.emoji.isNotEmpty) group,
  ];

  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) return const SizedBox.shrink();
    final group = _groups[_selected];
    // Emoji trên iOS vẽ nhỏ hơn Android ở cùng cỡ chữ.
    final size = defaultTargetPlatform == TargetPlatform.iOS ? 30.0 : 26.0;

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              for (var i = 0; i < _groups.length; i++)
                Expanded(
                  child: Tooltip(
                    message: _labels[_groups[i].category] ?? '',
                    child: InkWell(
                      onTap: () => setState(() => _selected = i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 2,
                              color: i == _selected
                                  ? TachColors.mintLight
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Icon(
                          _icons[_groups[i].category],
                          size: 22,
                          color: i == _selected
                              ? TachColors.mintLight
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            // Đổi nhóm thì lưới quay về đầu.
            key: ValueKey(group.category),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
            ),
            itemCount: group.emoji.length,
            itemBuilder: (context, index) => _EmojiCell(
              emoji: group.emoji[index],
              size: size,
              selected: group.emoji[index].emoji == widget.current,
              onTap: () => widget.state.onEmojiSelected(
                group.category,
                group.emoji[index],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({
    required this.emoji,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final picker.Emoji emoji;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? TachColors.mint.withValues(alpha: 0.35) : null,
        ),
        child: Text(
          emoji.emoji,
          // Màu trắng hẳn để emoji không bị mờ theo màu chữ thừa hưởng.
          style: TextStyle(fontSize: size, height: 1.1, color: Colors.white),
        ),
      ),
    );
  }
}
