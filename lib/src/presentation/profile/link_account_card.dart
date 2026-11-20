import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../dependency/injection.dart';
import '../../services/auth/auth_service.dart';

/// Chỉ hiện với tài khoản khách: mời gắn Apple hoặc Google để dữ liệu không
/// mất theo máy.
class LinkAccountCard extends StatefulWidget {
  const LinkAccountCard({super.key});

  @override
  State<LinkAccountCard> createState() => _LinkAccountCardState();
}

class _LinkAccountCardState extends State<LinkAccountCard> {
  final _auth = getIt<AuthService>();

  SignInMethod? _busy;
  String? _error;

  Future<void> _link(SignInMethod method) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = method;
      _error = null;
    });
    try {
      await _auth.link(method);
    } on SignInCancelled {
      if (mounted) setState(() => _busy = null);
      return;
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
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Đã liên kết. Từ giờ bạn đăng nhập lại được bằng tài khoản này.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final methods = _auth.linkMethods;
    if (methods.isEmpty) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Material(
        color: TachColors.mintTint,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Giữ dữ liệu của bạn', style: text.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Bạn đang dùng tài khoản khách: xóa app hoặc đổi máy là mất '
                'các nhóm và khoản chi. Liên kết một tài khoản để đăng nhập '
                'lại được.',
                style: text.bodyMedium?.copyWith(color: Colors.white),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: text.bodyMedium?.copyWith(color: TachColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              for (final method in methods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: switch (method) {
                    SignInMethod.apple => FilledButton.icon(
                      onPressed: _busy == null ? () => _link(method) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.apple, size: 22),
                      label: const Text('Liên kết với Apple'),
                    ),
                    _ => OutlinedButton.icon(
                      onPressed: _busy == null ? () => _link(method) : null,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      label: const Text('Liên kết với Google'),
                    ),
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
