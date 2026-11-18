import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../balance/balance_screen.dart';
import '../capture/capture_page.dart';
import '../feed/expense_page.dart';
import '../group/create_group_screen.dart';
import '../group/groups_sheet.dart';
import '../ledger/ledger_cubit.dart';
import '../month/month_grid_screen.dart';
import '../profile/profile_screen.dart';
import '../widgets/member_avatar.dart';
import '../widgets/tach_mark.dart';

/// Màn chính: camera ở trên cùng, vuốt lên là bảng tin, mỗi màn một khoản chi.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pages = PageController();
  var _onFeed = false;
  var _capturing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openMonth() async {
    final expenseId = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const MonthGridScreen()));
    if (expenseId == null || !mounted) return;
    final expenses = context.read<LedgerCubit>().state.expenses;
    final index = expenses.indexWhere((e) => e.id == expenseId);
    if (index >= 0) _pages.jumpToPage(index + 1);
  }

  void _openBalance() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BalanceScreen()));
  }

  /// Mở bảng nhóm: chuyển sang nhóm khác hoặc tạo nhóm mới.
  Future<void> _openGroups() async {
    final cubit = context.read<LedgerCubit>();
    final result = await showModalBottomSheet<GroupsSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TachColors.paper,
      showDragHandle: true,
      // Màn camera dùng theme tối; bảng nhóm là nền sáng.
      builder: (_) => Theme(
        data: tachLightTheme,
        child: BlocProvider.value(value: cubit, child: const GroupsSheet()),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case OpenGroup(:final groupId):
        cubit.switchGroup(groupId);
      case CreateNewGroup():
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CreateGroupScreen()),
        );
      case null:
        return;
    }
    // Nhóm đã đổi thì bảng tin cũng đổi; quay về camera của nhóm mới.
    if (mounted && _pages.hasClients) _pages.jumpToPage(0);
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          onSignOut: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            widget.onSignOut();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LedgerCubit>().state;

    return Theme(
      data: tachNightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: TachColors.night,
          body: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: TachColors.mintLight),
                )
              : !state.hasGroup
              ? _NoGroupView(
                  state: state,
                  onOpenProfile: _openProfile,
                  onCreateGroup: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateGroupScreen(),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pages,
                      scrollDirection: Axis.vertical,
                      physics: _capturing
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: state.expenses.length + 1,
                      onPageChanged: (page) =>
                          setState(() => _onFeed = page > 0),
                      itemBuilder: (context, page) {
                        if (page == 0) {
                          return CapturePage(
                            onBusyChanged: (busy) =>
                                setState(() => _capturing = busy),
                            onOpenFeed: () => _goToPage(1),
                            onOpenProfile: _openProfile,
                            onOpenGroups: _openGroups,
                          );
                        }
                        final expense = state.expenses[page - 1];
                        return ExpensePage(
                          key: ValueKey(expense.id),
                          expense: expense,
                          state: state,
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
                        ignoring: !_onFeed,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _onFeed ? 1 : 0,
                          child: _FeedBar(
                            onMonth: _openMonth,
                            onCamera: () => _goToPage(0),
                            onBalance: _openBalance,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Màn chính khi người dùng chưa ở nhóm nào: mời tạo nhóm đầu tiên.
class _NoGroupView extends StatelessWidget {
  const _NoGroupView({
    required this.state,
    required this.onOpenProfile,
    required this.onCreateGroup,
  });

  final LedgerState state;
  final VoidCallback onOpenProfile;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 6, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Hồ sơ',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onOpenProfile,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: MemberAvatar(
                        name: state.me.name,
                        tone: state.toneOf(state.meId),
                        photo: state.me.avatarBytes,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            const Align(
              alignment: Alignment.centerLeft,
              child: TachMark(size: 64, color: TachColors.mintLight),
            ),
            const SizedBox(height: 22),
            Text('Bạn chưa ở nhóm nào', style: text.headlineMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Tạo một nhóm cho phòng trọ, chuyến đi hoặc gia đình để '
                'bắt đầu ghi chi tiêu chung.',
                style: text.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: onCreateGroup,
                child: const Text('Tạo nhóm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh dưới của bảng tin: lưới cả tháng, về camera, số dư.
class _FeedBar extends StatelessWidget {
  const _FeedBar({
    required this.onMonth,
    required this.onCamera,
    required this.onBalance,
  });

  final VoidCallback onMonth;
  final VoidCallback onCamera;
  final VoidCallback onBalance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: ExpensePage.bottomBarSpace,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: onMonth,
              tooltip: 'Cả tháng',
              iconSize: 28,
              icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            ),
            Semantics(
              button: true,
              label: 'Về camera',
              child: GestureDetector(
                onTap: onCamera,
                child: Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onBalance,
              tooltip: 'Số dư',
              iconSize: 28,
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
