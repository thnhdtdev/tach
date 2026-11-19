import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/expense_photo.dart';
import '../widgets/member_avatar.dart';

/// Ba màn giới thiệu, chỉ hiện ở lần mở app đầu tiên.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    (
      title: 'Chụp là ghi',
      body:
          'Mua gì cho cả phòng, chụp một tấm rồi gõ số tiền. '
          'Xong trong 5 giây.',
    ),
    (
      title: 'Tự tách, tự tính',
      body:
          'Tach chia đều cho cả nhóm và cộng dồn ai nợ ai. '
          'Không cần sổ, không cần bảng tính.',
    ),
    (
      title: 'Trả bằng VietQR',
      body:
          'Cuối tháng quét một mã là chuyển đúng số tiền, đúng người. '
          'Tach không giữ tiền của bạn.',
    ),
  ];

  final _controller = PageController();
  var _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: Visibility(
                  visible: !_isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: widget.onDone,
                    style: TextButton.styleFrom(
                      foregroundColor: TachColors.inkSoft,
                    ),
                    child: const Text('Bỏ qua'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: switch (i) {
                                0 => const _CaptureArt(),
                                1 => const _SplitArt(),
                                _ => const _PayArt(),
                              },
                            ),
                          ),
                        ),
                        Text(page.title, style: text.headlineMedium),
                        const SizedBox(height: 10),
                        Text(
                          page.body,
                          style: text.bodyLarge?.copyWith(
                            color: TachColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 24, 20),
              child: Row(
                children: [
                  Semantics(
                    label: 'Trang ${_index + 1} trên ${_pages.length}',
                    child: Row(
                      children: [
                        for (var i = 0; i < _pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _index ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? TachColors.mint
                                  : TachColors.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(_isLast ? 'Bắt đầu' : 'Tiếp theo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một tấm ảnh có số tiền đóng lên, đúng như khi ghi một khoản chi.
class _CaptureArt extends StatelessWidget {
  const _CaptureArt();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        width: 256,
        height: 256,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ExpensePhoto(photoUrl: 'sample:eggs'),
            Positioned(
              left: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '30.000đ',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    'Trứng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khoản 30.000đ được tách cho bốn người.
class _SplitArt extends StatelessWidget {
  const _SplitArt();

  @override
  Widget build(BuildContext context) {
    const names = ['An', 'Minh', 'Lan', 'Hùng'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
          child: const ExpensePhoto(photoUrl: 'sample:eggs'),
        ),
        const SizedBox(height: 12),
        const Text(
          '30.000đ',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: TachColors.ink,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < names.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Column(
                  children: [
                    MemberAvatar(
                      name: names[i],
                      tone: TachColors.avatarTones[i],
                      size: 52,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '7.500đ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: TachColors.mintDeep,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Mã QR đúng số tiền và trạng thái "Đã trả".
class _PayArt extends StatelessWidget {
  const _PayArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TachColors.paper,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TachColors.line),
          ),
          child: Column(
            children: [
              QrImageView(
                data: 'Tach - Chụp là ghi, tách là xong.',
                size: 168,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: TachColors.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: TachColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '266.000đ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: TachColors.mint,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 20, color: TachColors.paid),
            SizedBox(width: 6),
            Text(
              'Đã trả',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: TachColors.paid,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
