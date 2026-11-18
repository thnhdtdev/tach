import 'package:material_ui/material_ui.dart';

/// Tiêu đề một nhóm nội dung trên các màn nền sáng, kèm đường kẻ bên dưới.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
