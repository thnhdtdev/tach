import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tach/src/app.dart';
import 'package:tach/src/datasource/sample/sample_group_repository.dart';
import 'package:tach/src/dependency/injection.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/domain/repositories/group_repository.dart';
import 'package:tach/src/services/auth/auth_service.dart';
import 'package:tach/src/services/camera/capture_camera.dart';

/// Đăng nhập như khi nối máy chủ: chỉ có tài khoản khách, phiên được giữ lại.
class _GuestAuth implements AuthService {
  _GuestAuth({this.signedIn = false});

  bool signedIn;
  var refuses = false;

  @override
  List<SignInMethod> get methods => const [SignInMethod.guest];

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<void> signIn(SignInMethod method) async {
    if (refuses) {
      throw const SignInException('Không kết nối được máy chủ.');
    }
    signedIn = true;
  }

  @override
  Future<void> signOut() async => signedIn = false;
}

/// Máy chủ giả cho một tài khoản mới: chưa có tên, chưa ở nhóm nào.
class _NewAccountServer extends SampleGroupRepository {
  var name = '';
  var offline = false;
  final joined = <GroupSnapshot>[];

  static const _minh = Member(id: 'u-minh', name: 'Minh');

  @override
  bool get persists => true;

  @override
  Future<LedgerSnapshot> load() async {
    if (offline) throw Exception('Mất mạng');
    return LedgerSnapshot(
      me: Member(id: 'u-new', name: name),
      groups: joined,
    );
  }

  @override
  Future<void> saveProfile(Member me) async => name = me.name;

  @override
  Future<String?> joinGroup(String inviteCode) async {
    if (offline) throw Exception('Mất mạng');
    if (inviteCode != 'DL2026') return null;
    joined.add(
      GroupSnapshot(
        group: Group(
          id: 'g-dalat',
          name: 'Đà Lạt',
          code: 'DALAT',
          type: GroupType.trip,
          inviteCode: 'DL2026',
          createdBy: _minh.id,
          members: [
            _minh,
            Member(id: 'u-new', name: name),
          ],
        ),
      ),
    );
    return 'g-dalat';
  }
}

class _NoCamera implements CaptureCamera {
  @override
  bool get canFlip => false;
  @override
  bool get isFront => false;
  @override
  double get minZoom => 1;
  @override
  double get maxZoom => 1;
  @override
  double get zoom => 1;
  @override
  Future<CameraStatus> open() async => CameraStatus.denied;
  @override
  Future<CameraStatus> flip() => open();
  @override
  Widget preview() => const SizedBox();
  @override
  Future<Uint8List> takePhoto() => throw UnimplementedError();
  @override
  Future<bool> setFlash(bool on) async => false;
  @override
  Future<CameraStatus> setZoom(double level) => open();
  @override
  Future<void> close() async {}
}

late _GuestAuth _auth;
late _NewAccountServer _server;

Future<void> _launch(WidgetTester tester, {bool signedIn = false}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'onboarding_seen': true});
  await getIt.reset();
  configureDependencies();
  _auth = _GuestAuth(signedIn: signedIn);
  _server = _NewAccountServer();
  getIt
    ..unregister<AuthService>()
    ..registerSingleton<AuthService>(_auth)
    ..unregister<GroupRepository>()
    ..registerSingleton<GroupRepository>(_server)
    ..unregister<CaptureCamera>()
    ..registerFactory<CaptureCamera>(_NoCamera.new);
}

void main() {
  testWidgets(
    'tài khoản khách mới: đăng nhập, đặt tên, rồi vào nhóm bằng mã mời',
    (tester) async {
      await _launch(tester);
      await tester.pumpWidget(const TachApp());
      await tester.pumpAndSettle();

      // Nối máy chủ thì chỉ hiện cách đăng nhập đang dùng được.
      expect(find.text('Tiếp tục với Google'), findsNothing);
      await tester.tap(find.text('Bắt đầu dùng thử'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn tên gì?'), findsOneWidget);
      final next = find.widgetWithText(FilledButton, 'Tiếp tục');
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '  Dat  ');
      await tester.pump();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(_server.name, 'Dat');
      expect(find.text('Bạn chưa ở nhóm nào'), findsOneWidget);

      await tester.tap(find.text('Nhập mã mời'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.pump();
      await tester.tap(find.text('Vào nhóm'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không có nhóm nào dùng mã này'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'dl2026');
      await tester.pump();
      await tester.tap(find.text('Vào nhóm'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập mã mời'), findsNothing);
      expect(find.text('Đà Lạt'), findsOneWidget);
      expect(find.text('2 người'), findsOneWidget);
    },
  );

  testWidgets(
    'còn phiên đăng nhập thì mở app vào thẳng, không qua màn đăng nhập',
    (tester) async {
      await _launch(tester, signedIn: true);
      _server.name = 'Dat';
      await tester.pumpWidget(const TachApp());
      await tester.pumpAndSettle();

      expect(find.text('Bắt đầu dùng thử'), findsNothing);
      expect(find.text('Bạn chưa ở nhóm nào'), findsOneWidget);
    },
  );

  testWidgets('đăng nhập không được thì báo lý do và ở lại màn đăng nhập', (
    tester,
  ) async {
    await _launch(tester);
    _auth.refuses = true;
    await tester.pumpWidget(const TachApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bắt đầu dùng thử'));
    await tester.pumpAndSettle();
    expect(find.text('Không kết nối được máy chủ.'), findsOneWidget);
    expect(find.text('Bắt đầu dùng thử'), findsOneWidget);
  });

  testWidgets('mất mạng lúc mở app: báo chưa tải được, bấm Thử lại là vào', (
    tester,
  ) async {
    await _launch(tester, signedIn: true);
    _server
      ..name = 'Dat'
      ..offline = true;
    await tester.pumpWidget(const TachApp());
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được dữ liệu'), findsOneWidget);

    _server.offline = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa ở nhóm nào'), findsOneWidget);
  });

  testWidgets('màn đăng nhập: có mã mời thì tạo tài khoản rồi vào thẳng nhóm', (
    tester,
  ) async {
    await _launch(tester);
    _server.name = 'Dat';
    await tester.pumpWidget(const TachApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Có mã mời nhóm? Nhập mã'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DL2026');
    await tester.pump();
    await tester.tap(find.text('Vào nhóm'));
    await tester.pumpAndSettle();

    expect(_auth.signedIn, isTrue);
    expect(find.text('Đà Lạt'), findsOneWidget);
  });
}
