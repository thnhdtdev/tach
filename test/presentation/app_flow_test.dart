import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tach/src/app.dart';
import 'package:tach/src/dependency/injection.dart';
import 'package:tach/src/services/avatar/avatar_picker.dart';
import 'package:tach/src/presentation/home/home_screen.dart';
import 'package:tach/src/presentation/ledger/ledger_cubit.dart';

/// Ảnh PNG 1×1 hợp lệ, dùng thay cho ảnh người dùng chọn.
final _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _FakeAvatarPicker implements AvatarPicker {
  final requested = <AvatarSource>[];

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    requested.add(source);
    if (source == AvatarSource.camera) {
      throw PlatformException(code: 'camera_access_denied');
    }
    return _tinyPng;
  }
}

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

  testWidgets('hồ sơ: đổi tên, sửa tài khoản nhận tiền và đăng xuất', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Thành viên Trọ 12'), findsOneWidget);
    expect(find.text('MB Bank'), findsOneWidget);

    await tester.tap(find.byTooltip('Đổi tên'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ánh');
    await tester.pump();
    await tester.tap(find.text('Lưu tên'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ánh'),
      findsNWidgets(2),
      reason: 'đầu trang và danh sách nhóm',
    );

    await tester.tap(find.text('Sửa tài khoản'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Số tài khoản'),
      '12345',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Lưu tài khoản'),
          )
          .onPressed,
      isNull,
      reason: 'Số tài khoản quá ngắn thì chưa lưu được',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Số tài khoản'),
      '123456789',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên chủ tài khoản'),
      'Nguyễn Văn Ánh',
    );
    await tester.pump();
    await tester.tap(find.text('Lưu tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('123456789'), findsOneWidget);
    expect(find.text('NGUYEN VAN ANH'), findsOneWidget);

    await tester.tap(find.text('Sửa tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gỡ tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm tài khoản'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Đăng xuất'), 200);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục với Apple'), findsOneWidget);
    expect(find.text('Hồ sơ'), findsNothing);
  });

  testWidgets('hồ sơ: chọn ảnh đại diện từ thư viện rồi gỡ ảnh', (
    tester,
  ) async {
    await _launch(tester);
    final picker = _FakeAvatarPicker();
    getIt
      ..unregister<AvatarPicker>()
      ..registerSingleton<AvatarPicker>(picker);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();
    Uint8List? myAvatar() => cubit.state.member(cubit.state.meId).avatarBytes;

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đổi ảnh đại diện'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn từ thư viện'), findsOneWidget);
    expect(find.text('Gỡ ảnh'), findsNothing, reason: 'Chưa có ảnh để gỡ');

    await tester.tap(find.text('Chọn từ thư viện'));
    await tester.pumpAndSettle();
    expect(picker.requested, [AvatarSource.gallery]);
    expect(myAvatar(), _tinyPng);
    expect(find.bySemanticsLabel('Ảnh đại diện của An'), findsWidgets);

    await tester.tap(find.byTooltip('Đổi ảnh đại diện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gỡ ảnh'));
    await tester.pumpAndSettle();
    expect(myAvatar(), isNull);
  });

  testWidgets('hồ sơ: không mở được camera thì báo lỗi và giữ ảnh cũ', (
    tester,
  ) async {
    await _launch(tester);
    getIt
      ..unregister<AvatarPicker>()
      ..registerSingleton<AvatarPicker>(_FakeAvatarPicker());
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đổi ảnh đại diện'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chụp ảnh mới'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không mở được camera'), findsOneWidget);
    expect(cubit.state.member(cubit.state.meId).avatarBytes, isNull);
  });

  testWidgets('tạo nhóm mới, xem mã mời rồi chuyển lại nhóm cũ', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();

    await tester.tap(find.byTooltip('Đổi nhóm'));
    await tester.pumpAndSettle();
    expect(find.text('Nhóm của bạn'), findsOneWidget);
    expect(find.text('Phòng trọ, 4 người'), findsOneWidget);

    await tester.tap(find.text('Tạo nhóm mới'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tạo nhóm'))
          .onPressed,
      isNull,
      reason: 'Chưa đặt tên thì chưa tạo được',
    );

    await tester.tap(find.bySemanticsLabel('Chuyến đi'));
    await tester.enterText(find.byType(TextField), 'Đà Lạt');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo nhóm'));
    await tester.pumpAndSettle();

    final trip = cubit.state.group;
    expect(trip.name, 'Đà Lạt');
    expect(find.text('Đã tạo nhóm Đà Lạt'), findsOneWidget);
    expect(find.text(trip.inviteCode), findsOneWidget);

    // Môi trường test không có bộ nhớ tạm thật, nên hứng lời gọi để kiểm tra.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.text('Chép lời mời'));
    await tester.pumpAndSettle();
    expect(find.text('Đã chép lời mời'), findsOneWidget);
    expect(copied, contains('Đà Lạt'));
    expect(copied, contains('Mã mời: ${trip.inviteCode}'));

    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('Đà Lạt'), findsOneWidget);
    expect(find.text('1 người'), findsOneWidget);
    expect(find.text('Chưa có khoản chi nào'), findsOneWidget);

    await tester.tap(find.byTooltip('Đổi nhóm'));
    await tester.pumpAndSettle();
    expect(find.text('Chuyến đi, 1 người'), findsOneWidget);
    await tester.tap(find.text('Trọ 12'));
    await tester.pumpAndSettle();
    expect(cubit.state.group.name, 'Trọ 12');
    expect(find.textContaining('vừa ghi'), findsOneWidget);
  });

  testWidgets('hồ sơ: mở màn mời bạn vào nhóm đang mở', (tester) async {
    await _launch(tester);
    await _signIn(tester);

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mời bạn vào nhóm'), 200);
    await tester.tap(find.text('Mời bạn vào nhóm'));
    await tester.pumpAndSettle();

    expect(find.text('Mời bạn vào Trọ 12'), findsOneWidget);
    expect(find.text('K7M2QP'), findsOneWidget);
  });
}
