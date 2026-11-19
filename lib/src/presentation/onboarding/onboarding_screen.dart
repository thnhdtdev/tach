import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/member_avatar.dart';

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
                            child: ExcludeSemantics(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: switch (i) {
                                    0 => const _CaptureArt(),
                                    1 => const _SplitArt(),
                                    _ => const _PayArt(),
                                  },
                                ),
                              ),
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.size,
    required this.owner,
    required this.tone,
    required this.strong,
    required this.child,
    this.label,
  });

  final double size;

  final String owner;
  final Color tone;

  final String? label;

  final String strong;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.2);
    final inset = size * 0.065;
    const caption = TextStyle(
      fontSize: 14,
      color: Colors.white,
      height: 1.2,
      fontWeight: FontWeight.w500,
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x260B5F55),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(borderRadius: radius, child: child),
            ),
          ),
          Positioned(
            left: inset,
            right: inset,
            bottom: inset,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: MemberAvatar(name: owner, tone: tone, size: 34),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: const ShapeDecoration(
                      color: Color(0xD91B2422),
                      shape: StadiumBorder(),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (label != null) TextSpan(text: '$label '),
                          TextSpan(
                            text: strong,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/onboarding/$name.jpg',
      fit: BoxFit.cover,
      // Ô lớn nhất rộng 264 điểm; giải mã vừa đủ cho màn hình 3x.
      cacheWidth: 680,
      errorBuilder: (_, _, _) => const ColoredBox(color: TachColors.mintWash),
    );
  }
}

class _CaptureArt extends StatelessWidget {
  const _CaptureArt();

  @override
  Widget build(BuildContext context) {
    return _PhotoTile(
      size: 264,
      owner: 'Minh',
      tone: TachColors.avatarTones[1],
      label: 'Trứng',
      strong: '30.000đ',
      child: const _Photo('eggs'),
    );
  }
}

class _SplitArt extends StatelessWidget {
  const _SplitArt();

  @override
  Widget build(BuildContext context) {
    const names = ['An', 'Minh', 'Lan', 'Hùng'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PhotoTile(
          size: 184,
          owner: 'Lan',
          tone: TachColors.avatarTones[2],
          strong: '320.000đ',
          child: const _Photo('hotpot'),
        ),
        const SizedBox(height: 30),
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
                      '80.000đ',
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

class _PayArt extends StatelessWidget {
  const _PayArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PhotoTile(
          size: 264,
          owner: 'Lan',
          tone: TachColors.avatarTones[2],
          label: 'Trả Lan',
          strong: '266.000đ',
          child: ColoredBox(
            color: TachColors.mintWash,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 22),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: TachColors.paper,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: 'Tach - Chụp là ghi, tách là xong.',
                  size: 140,
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
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
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
