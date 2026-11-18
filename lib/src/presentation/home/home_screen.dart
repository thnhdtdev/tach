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
