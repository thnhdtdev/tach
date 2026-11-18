import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tach/src/app.dart';
import 'package:tach/src/dependency/injection.dart';
import 'package:tach/src/presentation/home/home_screen.dart';
import 'package:tach/src/presentation/ledger/ledger_cubit.dart';

Future<void> _launch(WidgetTester tester, {bool seenOnboarding = true}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (seenOnboarding) 'onboarding_seen': true,
  });
  await getIt.reset();
  configureDependencies();

  await tester.pumpWidget(const TachApp());
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.text('Tiếp tục với Google'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lần đầu mở app: giới thiệu, đăng nhập rồi vào camera', (
    tester,
  ) async {
    await _launch(tester, seenOnboarding: false);
    expect(find.text('Chụp là ghi'), findsOneWidget);

    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    expect(find.text('Tự tách, tự tính'), findsOneWidget);

    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    expect(find.text('Trả bằng VietQR'), findsOneWidget);
    expect(find.text('Bỏ qua').hitTestable(), findsNothing);

    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp là ghi, tách là xong.'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);

    await _signIn(tester);
    expect(find.text('Trọ 12'), findsOneWidget);
    expect(find.bySemanticsLabel('Chụp'), findsOneWidget);
  });

  testWidgets('những lần sau bỏ qua màn giới thiệu', (tester) async {
    await _launch(tester);
    expect(find.text('Chụp là ghi'), findsNothing);
    expect(find.text('Tiếp tục với Apple'), findsOneWidget);
  });

  testWidgets('ghi một khoản: chụp, gõ số, Xong, bỏ bớt người, Gửi', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();
    final before = cubit.state.expenses.length;

    await tester.tap(find.bySemanticsLabel('Chụp'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Xong'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xong'))
          .onPressed,
      isNull,
      reason: 'Chưa có số tiền thì chưa bấm Xong được',
    );

    await tester.tap(find.byKey(const ValueKey('key-3')));
    await tester.tap(find.byKey(const ValueKey('key-0')));
    await tester.pump();
    expect(find.bySemanticsLabel('Số tiền 30.000đ'), findsOneWidget);

    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('Chia đều 4 người, mỗi người 7.500đ'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Hùng'));
    await tester.pumpAndSettle();
    expect(find.text('Chia đều 3 người, mỗi người 10.000đ'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Gửi'));
    await tester.pump();
    expect(find.text('Đã gửi. 2 người nợ bạn 20.000đ'), findsOneWidget);
    expect(find.bySemanticsLabel('Chụp'), findsOneWidget);

    final added = cubit.state.expenses.first;
    expect(cubit.state.expenses, hasLength(before + 1));
    expect(added.amount, 30000);
    expect(added.splits.length, 3);

    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Đã gửi'), findsNothing);
  });

  testWidgets('bảng tin, số dư và trả bằng VietQR', (tester) async {
    await _launch(tester);
    await _signIn(tester);

    await tester.tap(find.textContaining('vừa ghi'));
    await tester.pumpAndSettle();
    expect(find.text('Minh trả'), findsOneWidget);
    expect(find.text('30.000đ'), findsOneWidget);
    expect(find.textContaining('Bạn nợ 7.500đ'), findsOneWidget);

    await tester.tap(find.byTooltip('Số dư'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn cần trả'), findsWidgets);
    expect(find.text('266.000đ'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Trả'));
    await tester.pumpAndSettle();
    expect(find.text('Trả Lan'), findsOneWidget);
    expect(find.text('TRO12 AN T${DateTime.now().month}'), findsOneWidget);

    await tester.tap(find.text('Tôi đã chuyển khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Chờ Lan\nxác nhận'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Trả'), findsNothing);
  });

  testWidgets('lưới cả tháng: lọc và mở lại một khoản', (tester) async {
    await _launch(tester);
    await _signIn(tester);
    await tester.tap(find.textContaining('vừa ghi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cả tháng'));
    await tester.pumpAndSettle();
    expect(find.text('Cả nhóm đã chi'), findsOneWidget);
    expect(find.text('1.634.000đ'), findsOneWidget);

    await tester.tap(find.text('Của tôi'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Gạo 5kg')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Trứng')), findsNothing);

    await tester.tap(find.bySemanticsLabel(RegExp('Gạo 5kg')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn trả'), findsOneWidget);
    expect(find.text('Gạo 5kg'), findsOneWidget);
  });

  testWidgets('bình luận: trả lời theo luồng', (tester) async {
    await _launch(tester);
    await _signIn(tester);
    await tester.tap(find.textContaining('vừa ghi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xem 3 bình luận'));
    await tester.pumpAndSettle();
    expect(find.text('Cả nhóm cùng thấy'), findsOneWidget);
    expect(find.text('Trứng hôm nay rẻ ghê'), findsOneWidget);

    await tester.tap(find.text('Trả lời').last);
    await tester.pumpAndSettle();
    expect(find.text('Đang trả lời Hùng'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Để mình nấu');
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi bình luận'));
    await tester.pumpAndSettle();
    expect(find.text('Để mình nấu'), findsOneWidget);
    expect(find.text('Đang trả lời Hùng'), findsNothing);
  });
}
