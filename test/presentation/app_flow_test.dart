import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tach/src/app.dart';
import 'package:tach/src/dependency/injection.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/services/avatar/avatar_picker.dart';
import 'package:tach/src/services/camera/capture_camera.dart';
import 'package:tach/src/services/camera/zoom_plan.dart';
import 'package:tach/src/presentation/home/home_screen.dart';
import 'package:tach/src/presentation/ledger/ledger_cubit.dart';
import 'package:tach/src/presentation/widgets/expense_photo.dart';

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

class _FakeCamera implements CaptureCamera {
  _FakeCamera(this.status);

  CameraStatus status;
  var opens = 0;
  var closes = 0;
  var photoFails = false;
  var hasFlash = true;
  bool? flashOn;
  var front = false;
  var twoLenses = true;
  var topZoom = 6.0;

  final zooms = <double>[];

  var ultraWideLens = false;
  var ultraWide = false;
  var currentZoom = 1.0;

  bool get _hasUltraWide => ultraWideLens && !front;

  @override
  double get minZoom => _hasUltraWide ? 0.5 : 1;

  @override
  double get maxZoom => topZoom;

  @override
  double get zoom => currentZoom;

  @override
  Future<CameraStatus> setZoom(double level) async {
    final plan = planZoom(
      level,
      hasUltraWide: _hasUltraWide,
      onUltraWide: ultraWide,
      maxZoom: topZoom,
    );
    if (plan.ultraWide != ultraWide) {
      ultraWide = plan.ultraWide;
      opens++;
    }
    currentZoom = plan.zoom;
    zooms.add(plan.zoom);
    return status;
  }

  @override
  bool get canFlip => twoLenses;

  @override
  bool get isFront => front;

  @override
  Future<CameraStatus> flip() async {
    front = !front;
    hasFlash = !front;
    return open();
  }

  @override
  Future<CameraStatus> open() async {
    ultraWide = false;
    currentZoom = 1;
    opens++;
    return status;
  }

  @override
  Widget preview() => const ColoredBox(
    key: ValueKey('live-preview'),
    color: Color(0xFF223344),
    child: SizedBox.expand(),
  );

  @override
  Future<Uint8List> takePhoto() async {
    if (photoFails) throw Exception('Camera bận');
    return _tinyPng;
  }

  @override
  Future<bool> setFlash(bool on) async {
    if (!hasFlash) return false;
    flashOn = on;
    return true;
  }

  @override
  Future<void> close() async => closes++;
}

late _FakeCamera _camera;

Future<void> _launch(
  WidgetTester tester, {
  bool seenOnboarding = true,
  CameraStatus cameraStatus = CameraStatus.ready,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (seenOnboarding) 'onboarding_seen': true,
  });
  await getIt.reset();
  configureDependencies();
  _camera = _FakeCamera(cameraStatus);
  getIt
    ..unregister<CaptureCamera>()
    ..registerFactory<CaptureCamera>(() => _camera);

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
    expect(find.text('Minh'), findsOneWidget);
    expect(find.textContaining(' trả'), findsNothing);
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
    expect(find.text('Bạn'), findsOneWidget);
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

  testWidgets(
    'bình luận: bàn phím mở thì bảng vẫn dưới thanh trạng thái, chạm chỗ '
    'trống cất bàn phím, có nút đóng',
    (tester) async {
      await _launch(tester);
      // iPhone có tai thỏ: thanh trạng thái cao 59, bàn phím cao 336.
      const statusBar = 59.0;
      tester.view.padding = const FakeViewPadding(top: statusBar * 3);
      tester.view.viewPadding = const FakeViewPadding(top: statusBar * 3);
      await _signIn(tester);
      await tester.tap(find.textContaining('vừa ghi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem 3 bình luận'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);

      expect(
        tester.getTopLeft(find.text('Bình luận')).dy,
        greaterThan(statusBar),
      );
      expect(
        tester.getTopLeft(find.byTooltip('Đóng')).dy,
        greaterThan(statusBar),
      );
      expect(
        tester.getBottomLeft(find.byType(TextField)).dy,
        lessThan(844 - 336),
      );

      await tester.tap(find.text('Tối nay ai nấu vậy?'));
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isFalse);
      expect(find.text('Cả nhóm cùng thấy'), findsOneWidget);

      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Cả nhóm cùng thấy'), findsNothing);
    },
  );

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

  testWidgets('vuốt từ phải sang trái ở camera và bảng tin thì mở hồ sơ', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);
    final preview = find.byKey(const ValueKey('live-preview'));

    await tester.drag(preview, const Offset(200, 0));
    await tester.pumpAndSettle();
    await tester.drag(preview, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thành viên Trọ 12'), findsNothing);

    await tester.drag(preview, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thành viên Trọ 12'), findsOneWidget);
    expect(_camera.zooms, isEmpty);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('vừa ghi'));
    await tester.pumpAndSettle();
    expect(find.text('Minh'), findsOneWidget);

    await tester.fling(find.text('30.000đ'), const Offset(-60, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Thành viên Trọ 12'), findsOneWidget);
  });

  testWidgets('đang gõ số tiền thì vuốt ngang không mở hồ sơ', (tester) async {
    await _launch(tester);
    await _signIn(tester);

    await tester.tap(find.bySemanticsLabel('Chụp'));
    await tester.pumpAndSettle();
    // Kéo ngay trên ảnh; lớp số tiền nằm đè lên nên kéo theo tọa độ.
    await tester.dragFrom(
      tester.getCenter(find.byType(ExpensePhoto)),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thành viên Trọ 12'), findsNothing);
    expect(find.byKey(const ValueKey('key-0')), findsOneWidget);
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

  testWidgets('hồ sơ: đổi tên nhóm, tên mới hiện ở màn camera', (tester) async {
    await _launch(tester);
    await _signIn(tester);

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Đổi tên nhóm'), 200);
    await tester.tap(find.byTooltip('Đổi tên nhóm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nhà trọ Cầu Giấy');
    await tester.pump();
    await tester.tap(find.text('Lưu tên'));
    await tester.pumpAndSettle();
    expect(find.text('Nhà trọ Cầu Giấy'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Nhà trọ Cầu Giấy'), findsOneWidget);
    expect(find.text('Trọ 12'), findsNothing);
  });

  testWidgets('rời nhóm khi còn nợ: báo lý do và dẫn sang số dư', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rời nhóm'), 200);
    await tester.tap(find.text('Rời nhóm'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa rời nhóm được'), findsOneWidget);
    expect(
      find.textContaining('Bạn còn cần trả 266.000đ trong Trọ 12'),
      findsOneWidget,
    );
    expect(cubit.state.groups, hasLength(1));

    await tester.tap(find.text('Xem số dư'));
    await tester.pumpAndSettle();
    expect(find.text('Số dư'), findsOneWidget);
    expect(find.text('Trả cho ai'), findsOneWidget);
  });

  testWidgets('rời nhóm đã sòng phẳng: xác nhận rồi về nhóm còn lại', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();
    cubit.createGroup(name: 'Đà Lạt', type: GroupType.trip);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rời nhóm'), 200);
    await tester.tap(find.text('Rời nhóm'));
    await tester.pumpAndSettle();
    expect(find.text('Rời nhóm Đà Lạt?'), findsOneWidget);

    await tester.tap(find.text('Ở lại'));
    await tester.pumpAndSettle();
    expect(cubit.state.group.name, 'Đà Lạt');

    await tester.tap(find.text('Rời nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Rời nhóm').last);
    await tester.pumpAndSettle();

    expect(cubit.state.groups.map((g) => g.name), ['Trọ 12']);
    expect(find.text('Hồ sơ'), findsNothing);
    expect(find.text('Trọ 12'), findsOneWidget);
    expect(find.textContaining('vừa ghi'), findsOneWidget);
  });

  testWidgets('rời nhóm cuối cùng: màn mời tạo nhóm, tạo xong vào camera', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();

    // Trả hết nợ trong nhóm mẫu để rời được nhóm duy nhất.
    final mine = cubit.state.transfers.singleWhere(
      (t) => t.fromId == cubit.state.meId,
    );
    cubit.markTransferred(mine);
    cubit.confirmReceived(cubit.state.pendingFor(mine)!.id);
    expect(cubit.leaveGroup(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Bạn chưa ở nhóm nào'), findsOneWidget);
    expect(find.bySemanticsLabel('Chụp'), findsNothing);

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa ở nhóm nào'), findsOneWidget);
    expect(find.text('Rời nhóm'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Tạo nhóm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nhà mình');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();

    expect(find.text('Nhà mình'), findsOneWidget);
    expect(find.bySemanticsLabel('Chụp'), findsOneWidget);
  });

  testWidgets('xóa nhóm khi còn khoản chưa trả: báo lý do, nhóm còn nguyên', (
    tester,
  ) async {
    await _launch(tester);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();

    await tester.tap(find.byTooltip('Hồ sơ'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Xóa nhóm'), 200);
    await tester.ensureVisible(find.text('Xóa nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa nhóm'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa xóa nhóm được'), findsOneWidget);
    expect(
      find.textContaining('Trọ 12 còn 3 khoản chưa trả xong'),
      findsOneWidget,
    );
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(cubit.state.group.name, 'Trọ 12');
  });

  testWidgets(
    'người tạo xóa nhóm đã sòng phẳng: xác nhận rồi về nhóm còn lại',
    (tester) async {
      await _launch(tester);
      await _signIn(tester);
      final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();
      cubit.createGroup(name: 'Đà Lạt', type: GroupType.trip);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Hồ sơ'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Xóa nhóm'), 200);
      await tester.ensureVisible(find.text('Xóa nhóm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa nhóm'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa nhóm Đà Lạt?'), findsOneWidget);
      expect(find.textContaining('không hoàn tác được'), findsOneWidget);

      await tester.tap(find.text('Giữ nhóm'));
      await tester.pumpAndSettle();
      expect(cubit.state.group.name, 'Đà Lạt');

      await tester.tap(find.text('Xóa nhóm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Xóa nhóm').last);
      await tester.pumpAndSettle();

      expect(cubit.state.groups.map((g) => g.name), ['Trọ 12']);
      expect(find.text('Hồ sơ'), findsNothing);
      expect(find.text('Trọ 12'), findsOneWidget);
    },
  );

  testWidgets('thả cảm xúc từ bảng emoji đầy đủ, đổi rồi gỡ', (tester) async {
    // Thư viện emoji hỏi máy Android xem emoji nào hiển thị được; trong test
    // coi như máy hiển thị được hết.
    const channel = MethodChannel('emoji_picker_flutter');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      final source = (call.arguments as Map)['source'] as List;
      return List<bool>.filled(source.length, true);
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await _launch(tester);
    await _signIn(tester);
    final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();
    String? mine() => cubit.state.expenses.first.reactions[cubit.state.meId];

    await tester.tap(find.textContaining('vừa ghi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Chọn cảm xúc khác'));
    await tester.pumpAndSettle();
    expect(find.text('Thả cảm xúc'), findsOneWidget);
    expect(find.text('Gỡ cảm xúc'), findsNothing, reason: 'Chưa thả gì');
    expect(find.byTooltip('Mặt cười và con người'), findsOneWidget);
    expect(
      find.byTooltip('Dùng gần đây'),
      findsNothing,
      reason: 'Chưa dùng emoji nào thì không có nhóm gần đây',
    );

    await tester.tap(find.byTooltip('Đồ ăn và thức uống'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🍎'));
    await tester.pumpAndSettle();
    expect(mine(), '🍎');
    expect(
      find.text('Thả cảm xúc'),
      findsNothing,
      reason: 'Chọn xong thì đóng',
    );
    expect(
      find.descendant(
        of: find.byTooltip('Chọn cảm xúc khác'),
        matching: find.text('🍎'),
      ),
      findsOneWidget,
      reason: 'Cảm xúc vừa chọn hiện ở ô thứ tư',
    );

    await tester.tap(find.byTooltip('Chọn cảm xúc khác'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dùng gần đây'), findsOneWidget);
    await tester.tap(find.text('Gỡ cảm xúc'));
    await tester.pumpAndSettle();
    expect(mine(), isNull);

    await tester.tap(find.bySemanticsLabel('Thả cảm xúc 👍'));
    await tester.pump();
    expect(mine(), '👍');
  });

  group('camera', () {
    testWidgets('chụp ảnh thật: ảnh đi theo khoản chi lên bảng tin', (
      tester,
    ) async {
      await _launch(tester);
      await _signIn(tester);
      final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();
      expect(find.byKey(const ValueKey('live-preview')), findsOneWidget);
      expect(_camera.opens, 1);

      await tester.tap(find.bySemanticsLabel('Chụp'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-preview')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('key-5')));
      await tester.tap(find.byKey(const ValueKey('key-0')));
      await tester.pump();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Gửi'));
      await tester.pump();

      final added = cubit.state.expenses.first;
      expect(added.amount, 50000);
      expect(added.photoBytes, _tinyPng);
      expect(added.hasPhoto, isTrue);
      expect(find.byKey(const ValueKey('live-preview')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('màn khác che thì nhả camera, quay lại thì mở lại', (
      tester,
    ) async {
      await _launch(tester);
      await _signIn(tester);
      expect((_camera.opens, _camera.closes), (1, 0));

      await tester.tap(find.byTooltip('Hồ sơ'));
      await tester.pumpAndSettle();
      expect(_camera.closes, 1);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_camera.opens, 2);
      expect(find.byKey(const ValueKey('live-preview')), findsOneWidget);
    });

    testWidgets('app xuống nền thì nhả camera, mở lại app thì bật lại', (
      tester,
    ) async {
      await _launch(tester);
      await _signIn(tester);

      // App ở nền không vẽ khung hình nào, nên chỉ kiểm tra camera đã nhả.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(_camera.closes, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_camera.opens, 2);
      expect(find.byKey(const ValueKey('live-preview')), findsOneWidget);
    });

    testWidgets(
      'chưa cấp quyền: báo cách bật, khóa nút chụp, vẫn ghi không ảnh',
      (tester) async {
        await _launch(tester, cameraStatus: CameraStatus.denied);
        await _signIn(tester);
        expect(find.text('Tach chưa được dùng camera'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Chụp'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Xong'), findsNothing);

        await tester.tap(find.text('Ghi không cần ảnh'));
        await tester.pumpAndSettle();
        expect(find.text('Xong'), findsOneWidget);
      },
    );

    testWidgets(
      'được cấp quyền sau khi vào Cài đặt: quay lại app là có camera',
      (tester) async {
        await _launch(tester, cameraStatus: CameraStatus.denied);
        await _signIn(tester);
        expect(find.text('Tach chưa được dùng camera'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pumpAndSettle();
        _camera.status = CameraStatus.ready;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(find.text('Tach chưa được dùng camera'), findsNothing);
        expect(find.byKey(const ValueKey('live-preview')), findsOneWidget);
      },
    );

    testWidgets('máy không có camera (bản debug): nút chụp dùng ảnh mẫu', (
      tester,
    ) async {
      await _launch(tester, cameraStatus: CameraStatus.unavailable);
      await _signIn(tester);
      final cubit = tester.element(find.byType(HomeScreen)).read<LedgerCubit>();
      expect(find.text('Máy này không có camera'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Chụp'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('key-2')));
      await tester.pump();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Gửi'));
      await tester.pump();

      expect(cubit.state.expenses.first.photoUrl, 'sample:viewfinder');
      expect(cubit.state.expenses.first.photoBytes, isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('chụp lỗi: báo thử lại và ở lại màn camera', (tester) async {
      await _launch(tester);
      await _signIn(tester);
      _camera.photoFails = true;

      await tester.tap(find.bySemanticsLabel('Chụp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Không chụp được ảnh. Thử lại nhé.'), findsOneWidget);
      expect(find.text('Xong'), findsNothing);

      _camera.photoFails = false;
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.bySemanticsLabel('Chụp'));
      await tester.pumpAndSettle();
      expect(find.text('Xong'), findsOneWidget);
    });

    testWidgets('đèn flash: bật được thì đổi nút, máy không có thì báo', (
      tester,
    ) async {
      await _launch(tester);
      await _signIn(tester);

      await tester.tap(find.byTooltip('Bật đèn flash'));
      await tester.pumpAndSettle();
      expect(_camera.flashOn, isTrue);
      expect(find.byTooltip('Tắt đèn flash'), findsOneWidget);

      _camera.hasFlash = false;
      await tester.tap(find.byTooltip('Tắt đèn flash'));
      await tester.pump();
      expect(find.text('Camera này không có đèn flash.'), findsOneWidget);
      expect(find.byTooltip('Tắt đèn flash'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'đổi camera trước sau; sang camera trước thì đèn flash tự tắt',
      (tester) async {
        await _launch(tester);
        await _signIn(tester);

        await tester.tap(find.byTooltip('Bật đèn flash'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Tắt đèn flash'), findsOneWidget);

        await tester.tap(find.byTooltip('Đổi sang camera trước'));
        await tester.pumpAndSettle();
        expect(_camera.front, isTrue);
        expect(find.byTooltip('Đổi sang camera sau'), findsOneWidget);
        expect(find.byTooltip('Bật đèn flash'), findsOneWidget);
        expect(find.byKey(const ValueKey('live-preview')), findsOneWidget);

        await tester.tap(find.byTooltip('Đổi sang camera sau'));
        await tester.pumpAndSettle();
        expect(_camera.front, isFalse);
        expect(find.byTooltip('Đổi sang camera trước'), findsOneWidget);
      },
    );

    testWidgets('máy chỉ có một camera thì nút đổi camera bị khóa', (
      tester,
    ) async {
      await _launch(tester);
      _camera.twoLenses = false;
      await _signIn(tester);

      final flip = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.cameraswitch_outlined),
      );
      expect(flip.onPressed, isNull);
    });

    testWidgets('khung ngắm và ảnh ở bảng tin đều vuông 1:1', (tester) async {
      await _launch(tester);
      await _signIn(tester);

      final viewfinder = tester.getSize(
        find.byKey(const ValueKey('live-preview')),
      );
      expect(viewfinder.width, viewfinder.height);
      expect(viewfinder.width, greaterThan(300));

      await tester.tap(find.textContaining('vừa ghi'));
      await tester.pumpAndSettle();
      final photo = tester.getSize(find.byType(ExpensePhoto));
      expect(photo.width, photo.height);
      expect(photo.width, viewfinder.width);
    });

    testWidgets(
      'gõ ghi chú: bàn phím chữ mở thì cất bàn phím số, khung ảnh vẫn rộng',
      (tester) async {
        await _launch(tester);
        await _signIn(tester);
        await tester.tap(find.bySemanticsLabel('Chụp'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('50k'));
        await tester.pump();
        expect(find.byKey(const ValueKey('key-0')), findsOneWidget);

        await tester.tap(find.byType(TextField));
        tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('key-0')), findsNothing);
        expect(find.text('15k'), findsNothing);
        final photo = tester.getRect(find.byType(ExpensePhoto));
        expect(photo.width, moreOrLessEquals(photo.height, epsilon: 0.5));
        expect(photo.width, greaterThan(300));
        expect(photo.bottom, lessThanOrEqualTo(844 - 336));

        await tester.enterText(find.byType(TextField), 'Thêm màn hình');
        await tester.pump();

        await tester.testTextInput.receiveAction(TextInputAction.done);
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('key-0')), findsOneWidget);
        expect(find.bySemanticsLabel('Số tiền 50.000đ'), findsOneWidget);
        expect(find.text('Thêm màn hình'), findsOneWidget);

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('key-0')), findsNothing);
        await tester.tapAt(
          tester.getTopLeft(find.byType(ExpensePhoto)) + const Offset(30, 30),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('key-0')), findsOneWidget);
      },
    );

    testWidgets(
      'máy nhỏ: bàn phím số hiện mà khung ảnh vẫn vuông, không tràn',
      (tester) async {
        await _launch(tester);
        // iPhone SE: 375×667.
        tester.view.physicalSize = const Size(750, 1334);
        tester.view.devicePixelRatio = 2;
        await _signIn(tester);

        await tester.tap(find.bySemanticsLabel('Chụp'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('key-0')), findsOneWidget);

        final photo = tester.getSize(find.byType(ExpensePhoto));
        expect(photo.width, moreOrLessEquals(photo.height, epsilon: 0.5));
        expect(photo.width, greaterThan(180));
      },
    );

    testWidgets('nút zoom: bấm lên 2×, bấm nữa về 1×, đổi camera thì về 1×', (
      tester,
    ) async {
      await _launch(tester);
      await _signIn(tester);

      final frame = tester.getRect(find.byKey(const ValueKey('live-preview')));
      final button = tester.getCenter(find.bySemanticsLabel('Zoom 1×'));
      expect(button.dx, greaterThan(frame.center.dx + frame.width / 4));
      expect(button.dy, lessThan(frame.center.dy - frame.height / 4));

      await tester.tap(find.bySemanticsLabel('Zoom 1×'));
      await tester.pumpAndSettle();
      expect(_camera.zooms, [2.0]);

      await tester.tap(find.bySemanticsLabel('Zoom 2×'));
      await tester.pumpAndSettle();
      expect(_camera.zooms, [2.0, 1.0]);

      await tester.tap(find.bySemanticsLabel('Zoom 1×'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đổi sang camera trước'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Zoom 1×'), findsOneWidget);
      expect(_camera.zooms, [2.0, 1.0, 2.0]);
    });

    testWidgets(
      'chụm hai ngón tay để zoom: không trượt sang bảng tin, dừng ở mức tối đa',
      (tester) async {
        await _launch(tester);
        await _signIn(tester);

        final center = tester.getCenter(
          find.byKey(const ValueKey('live-preview')),
        );
        final first = await tester.startGesture(
          center - const Offset(0, 20),
          pointer: 1,
        );
        final second = await tester.startGesture(
          center + const Offset(0, 20),
          pointer: 2,
        );
        await tester.pump();

        // Hai ngón cách nhau 40 rồi 60: phóng 1,5 lần. Ngón kéo dọc, đúng
        // hướng vuốt của bảng tin.
        await second.moveBy(const Offset(0, 20));
        await tester.pump();
        expect(_camera.zooms.last, moreOrLessEquals(1.5, epsilon: 0.01));
        expect(find.bySemanticsLabel('Zoom 1,5×'), findsOneWidget);
        expect(find.bySemanticsLabel('Zoom 1×'), findsNothing);

        await second.moveBy(const Offset(0, 300));
        await tester.pump();
        expect(_camera.zooms.last, 6.0);
        expect(find.bySemanticsLabel('Zoom 6×'), findsOneWidget);

        await second.moveBy(const Offset(0, -330));
        await tester.pump();
        expect(_camera.zooms.last, 1.0);

        await second.moveBy(const Offset(0, 30));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Zoom 1×'), findsNothing);
        await tester.tap(find.bySemanticsLabel(RegExp(r'^Zoom ')));
        await tester.pumpAndSettle();
        expect(_camera.zooms.last, 1.0);
        expect(find.bySemanticsLabel('Zoom 1×'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('live-preview')).hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.getCenter(find.byKey(const ValueKey('live-preview'))),
          center,
        );
      },
    );

    testWidgets(
      'máy có ống kính góc siêu rộng: nút zoom xoay vòng 1× → 2× → 0,5× → 1×',
      (tester) async {
        await _launch(tester);
        _camera.ultraWideLens = true;
        await _signIn(tester);
        final opens = _camera.opens;

        await tester.tap(find.bySemanticsLabel('Zoom 1×'));
        await tester.pumpAndSettle();
        expect(_camera.zooms, [2.0]);
        expect(_camera.opens, opens);

        await tester.tap(find.bySemanticsLabel('Zoom 2×'));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isTrue);
        expect(_camera.opens, opens + 1);
        expect(find.bySemanticsLabel('Zoom 0,5×'), findsOneWidget);
        expect(find.byKey(const ValueKey('live-preview')), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Zoom 0,5×'));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isFalse);
        expect(_camera.opens, opens + 2);
        expect(find.bySemanticsLabel('Zoom 1×'), findsOneWidget);
      },
    );

    testWidgets(
      'chụm hai ngón tay đi liền từ 0,5× tới 6×, camera tự đổi ống kính ở 1×',
      (tester) async {
        await _launch(tester);
        _camera.ultraWideLens = true;
        await _signIn(tester);
        final opens = _camera.opens;

        final center = tester.getCenter(
          find.byKey(const ValueKey('live-preview')),
        );
        // Hai ngón đặt cách nhau 100, bắt đầu từ 1×.
        final first = await tester.startGesture(
          center - const Offset(0, 50),
          pointer: 1,
        );
        final second = await tester.startGesture(
          center + const Offset(0, 50),
          pointer: 2,
        );
        await tester.pump();

        // Thu nhỏ một chút (0,95×): chưa đủ để đổi ống kính, camera vẫn ở 1×.
        await second.moveBy(const Offset(0, -5));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isFalse);
        expect(_camera.zooms.last, 1.0);
        expect(find.bySemanticsLabel('Zoom 1×'), findsOneWidget);

        // Thu nhỏ tiếp xuống 0,7×: sang ống kính góc siêu rộng.
        await second.moveBy(const Offset(0, -25));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isTrue);
        expect(_camera.opens, opens + 1);
        expect(_camera.zooms.last, moreOrLessEquals(0.7, epsilon: 0.01));
        expect(find.bySemanticsLabel('Zoom 0,7×'), findsOneWidget);

        // Chụm hết cỡ: dừng ở 0,5×.
        await second.moveBy(const Offset(0, -60));
        await tester.pumpAndSettle();
        expect(_camera.zooms.last, 0.5);

        // Tách ra tới 0,96×: vẫn ở góc siêu rộng, chưa đổi lại.
        await second.moveBy(const Offset(0, 86));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isTrue);
        expect(_camera.opens, opens + 1);

        // Qua 1× thì về ống kính chính, rồi phóng tiếp tới mức tối đa 6×.
        await second.moveBy(const Offset(0, 104));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isFalse);
        expect(_camera.opens, opens + 2);
        expect(_camera.zooms.last, moreOrLessEquals(2.0, epsilon: 0.01));

        await second.moveBy(const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(_camera.zooms.last, 6.0);
        expect(find.bySemanticsLabel('Zoom 6×'), findsOneWidget);

        await first.up();
        await second.up();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('live-preview')).hitTestable(),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'đang ở 0,5× mà đổi sang camera trước: về 1×, không còn mức 0,5×',
      (tester) async {
        await _launch(tester);
        _camera.ultraWideLens = true;
        await _signIn(tester);

        await tester.tap(find.bySemanticsLabel('Zoom 1×'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Zoom 2×'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Zoom 0,5×'), findsOneWidget);

        await tester.tap(find.byTooltip('Đổi sang camera trước'));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isFalse);
        expect(find.bySemanticsLabel('Zoom 1×'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Zoom 1×'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Zoom 2×'));
        await tester.pumpAndSettle();
        expect(_camera.ultraWide, isFalse);
        expect(find.bySemanticsLabel('Zoom 1×'), findsOneWidget);
      },
    );

    testWidgets('vuốt một ngón trên khung ngắm vẫn sang bảng tin', (
      tester,
    ) async {
      await _launch(tester);
      await _signIn(tester);

      await tester.drag(
        find.byKey(const ValueKey('live-preview')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-preview')), findsNothing);
      expect(_camera.zooms, isEmpty);
    });

    testWidgets('camera không zoom được thì không hiện nút zoom', (
      tester,
    ) async {
      await _launch(tester);
      _camera.topZoom = 1;
      await _signIn(tester);

      expect(find.bySemanticsLabel('Chụp'), findsOneWidget);
      expect(find.bySemanticsLabel('Zoom 1×'), findsNothing);
    });

    testWidgets('máy không có camera (bản debug): ảnh mẫu cũng phóng to được', (
      tester,
    ) async {
      await _launch(tester, cameraStatus: CameraStatus.unavailable);
      await _signIn(tester);
      final before = tester.getRect(find.byType(ExpensePhoto));

      await tester.tap(find.bySemanticsLabel('Zoom 1×'));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byType(ExpensePhoto));
      expect(after.width, moreOrLessEquals(before.width * 2, epsilon: 0.5));
      expect(_camera.zooms, isEmpty);

      await tester.tap(find.bySemanticsLabel('Zoom 2×'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Zoom 0,5×'), findsOneWidget);
      final wide = tester.getRect(find.byType(ExpensePhoto));
      expect(wide.width, moreOrLessEquals(before.width / 2, epsilon: 0.5));

      await tester.tap(find.bySemanticsLabel('Zoom 0,5×'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Zoom 1×'), findsOneWidget);
      expect(_camera.zooms, isEmpty);
    });
  });
}
