import 'package:material_ui/material_ui.dart';

import '../../dependency/injection.dart';
import '../../services/preferences/app_preferences.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../widgets/tach_mark.dart';

enum _Step { loading, onboarding, login, home }

/// Quyết định màn đầu tiên: giới thiệu (chỉ lần đầu), đăng nhập, rồi camera.
///
/// Chưa có đăng nhập thật nên mỗi lần mở app vẫn qua màn đăng nhập.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  final _preferences = getIt<AppPreferences>();
  var _step = _Step.loading;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final seen = await _preferences.hasSeenOnboarding();
    if (!mounted) return;
    setState(() => _step = seen ? _Step.login : _Step.onboarding);
  }

  void _finishOnboarding() {
    _preferences.markOnboardingSeen();
    setState(() => _step = _Step.login);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: switch (_step) {
        _Step.loading => const Scaffold(
          key: ValueKey(_Step.loading),
          body: Center(child: TachMark()),
        ),
        _Step.onboarding => OnboardingScreen(
          key: const ValueKey(_Step.onboarding),
          onDone: _finishOnboarding,
        ),
        _Step.login => LoginScreen(
          key: const ValueKey(_Step.login),
          onSignedIn: () => setState(() => _step = _Step.home),
        ),
        _Step.home => const HomeScreen(key: ValueKey(_Step.home)),
      },
    );
  }
}
