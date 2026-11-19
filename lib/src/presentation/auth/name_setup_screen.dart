import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';

/// Hỏi tên người dùng ở lần đầu vào app, để cả nhóm biết ai ghi khoản nào.
class NameSetupScreen extends StatefulWidget {
  const NameSetupScreen({super.key, required this.onSubmit});

  /// Nhận tên đã bỏ khoảng trắng thừa, không bao giờ trống.
  final ValueChanged<String> onSubmit;

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) widget.onSubmit(name);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text('Bạn tên gì?', style: text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Cả nhóm sẽ thấy tên này bên cạnh các khoản bạn ghi. Bạn đổi '
                'lại được trong hồ sơ.',
                style: text.bodyLarge?.copyWith(color: TachColors.inkSoft),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(24)],
                style: text.titleLarge,
                decoration: InputDecoration(
                  hintText: 'Ví dụ An',
                  hintStyle: text.titleLarge?.copyWith(
                    color: TachColors.inkSoft.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: TachColors.mintWash.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: _name.text.trim().isEmpty ? null : _submit,
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
