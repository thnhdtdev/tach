import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/tach_mark.dart';

/// Màn đăng nhập.
///
/// Chưa nối dịch vụ đăng nhập thật: mọi lựa chọn đều vào thẳng nhóm mẫu.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  Future<void> _enterInviteCode(BuildContext context) async {
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TachColors.paper,
      showDragHandle: true,
      builder: (_) => const _InviteCodeSheet(),
    );
    if (joined == true) onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              const Align(
                alignment: Alignment.centerLeft,
                child: TachMark(size: 76),
              ),
              const SizedBox(height: 22),
              Text(
                'Tach',
                style: text.displayLarge?.copyWith(color: TachColors.mintDeep),
              ),
              const SizedBox(height: 6),
              Text(
                'Chụp là ghi, tách là xong.',
                style: text.titleMedium?.copyWith(
                  color: TachColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 4),
              FilledButton.icon(
                onPressed: onSignedIn,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.apple, size: 22),
                label: const Text('Tiếp tục với Apple'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onSignedIn,
                icon: const Text(
                  'G',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                label: const Text('Tiếp tục với Google'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onSignedIn,
                icon: const Icon(Icons.phone_iphone_outlined, size: 20),
                label: const Text('Tiếp tục với số điện thoại'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _enterInviteCode(context),
                style: TextButton.styleFrom(
                  foregroundColor: TachColors.mintDeep,
                  minimumSize: const Size(64, 48),
                ),
                child: const Text('Có mã mời nhóm? Nhập mã'),
              ),
              const SizedBox(height: 8),
              Text(
                'Khi tiếp tục, bạn đồng ý với Điều khoản và Chính sách '
                'quyền riêng tư của Tach.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCodeSheet extends StatefulWidget {
  const _InviteCodeSheet();

  @override
  State<_InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends State<_InviteCodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nhập mã mời', style: text.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Mã nằm trong link mời mà bạn cùng nhóm đã gửi.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
            style: text.titleLarge?.copyWith(letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'Ví dụ TRO12',
              hintStyle: text.titleLarge?.copyWith(
                color: TachColors.inkSoft.withValues(alpha: 0.5),
                letterSpacing: 0,
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
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _code.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(true),
            child: const Text('Vào nhóm'),
          ),
        ],
      ),
    );
  }
}
