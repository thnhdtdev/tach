import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../services/auth/auth_service.dart';
import '../group/join_group_sheet.dart';
import '../widgets/tach_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = getIt<AuthService>();

  SignInMethod? _busy;
  String? _error;

  Future<void> _signIn(SignInMethod method) async {
    setState(() {
      _busy = method;
      _error = null;
    });
    try {
      await _auth.signIn(method);
    } on SignInException catch (error) {
      if (mounted) {
        setState(() {
          _busy = null;
          _error = error.message;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = null);
    widget.onSignedIn();
  }

  Future<void> _enterInviteCode() async {
    final joined = await showJoinGroupSheet(
      context,
      beforeJoin: () async {
        if (!_auth.isSignedIn) await _auth.signIn(_auth.methods.last);
      },
    );
    if (joined && mounted) widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final guestOnly =
        _auth.methods.length == 1 && _auth.methods.single == SignInMethod.guest;

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
              Text('Tach', style: text.displayLarge),
              const SizedBox(height: 6),
              Text(
                'Chụp là ghi, tách là xong.',
                style: text.titleMedium?.copyWith(
                  color: TachColors.soft,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 4),
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: TachColors.danger),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final method in _auth.methods) ...[
                _button(method),
                const SizedBox(height: 10),
              ],
              if (guestOnly)
                Text(
                  'Chưa cần tài khoản. Dữ liệu gắn với máy này, xóa app là '
                  'không vào lại được.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              TextButton(
                onPressed: _busy == null ? _enterInviteCode : null,
                style: TextButton.styleFrom(
                  foregroundColor: TachColors.mintLight,
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

  Widget _button(SignInMethod method) {
    final onPressed = _busy == null ? () => _signIn(method) : null;
    return switch (method) {
      SignInMethod.apple => FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        icon: const Icon(Icons.apple, size: 22),
        label: const Text('Tiếp tục với Apple'),
      ),
      SignInMethod.google => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Text(
          'G',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        label: const Text('Tiếp tục với Google'),
      ),
      SignInMethod.phone => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.phone_iphone_outlined, size: 20),
        label: const Text('Tiếp tục với số điện thoại'),
      ),
      SignInMethod.guest => FilledButton(
        onPressed: onPressed,
        child: Text(_busy == method ? 'Đang vào…' : 'Bắt đầu dùng thử'),
      ),
    };
  }
}
