import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../dependency/injection.dart';
import '../../services/auth/auth_service.dart';
import '../../services/preferences/app_preferences.dart';
import '../auth/login_screen.dart';
import '../auth/name_setup_screen.dart';
import '../home/home_screen.dart';
import '../ledger/ledger_cubit.dart';
import '../onboarding/onboarding_screen.dart';
import '../widgets/tach_mark.dart';

enum _Step { loading, onboarding, login, home }

/// Quyết định màn đầu tiên: giới thiệu (chỉ lần đầu), đăng nhập, rồi camera.
///
/// Còn phiên đăng nhập từ lần trước thì bỏ qua màn đăng nhập.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  final _preferences = getIt<AppPreferences>();
  final _auth = getIt<AuthService>();
  var _step = _Step.loading;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final seen = await _preferences.hasSeenOnboarding();
    if (!mounted) return;
    if (seen) {
      _afterOnboarding();
    } else {
      setState(() => _step = _Step.onboarding);
    }
  }

  void _finishOnboarding() {
    _preferences.markOnboardingSeen();
    _afterOnboarding();
  }

  void _afterOnboarding() {
    if (_auth.isSignedIn) {
      _enterHome();
    } else {
      setState(() => _step = _Step.login);
    }
  }

  /// Vào màn chính và tải dữ liệu của người vừa đăng nhập.
  void _enterHome() {
    setState(() => _step = _Step.home);
    context.read<LedgerCubit>().load();
  }

  Future<void> _signOut() async {
    final cubit = context.read<LedgerCubit>();
    await _auth.signOut();
    if (!mounted) return;
    cubit.reset();
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
          onSignedIn: _enterHome,
        ),
        // Tài khoản mới chưa có tên thì hỏi tên trước khi vào camera.
        _Step.home => BlocBuilder<LedgerCubit, LedgerState>(
          key: const ValueKey(_Step.home),
          buildWhen: (before, after) => before.needsName != after.needsName,
          builder: (context, state) => state.needsName
              ? NameSetupScreen(onSubmit: context.read<LedgerCubit>().renameMe)
              : HomeScreen(onSignOut: _signOut),
        ),
      },
    );
  }
}
