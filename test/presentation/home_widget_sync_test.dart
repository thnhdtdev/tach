import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/datasource/sample/sample_group_repository.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/presentation/ledger/home_widget_sync.dart';
import 'package:tach/src/presentation/ledger/ledger_cubit.dart';
import 'package:tach/src/services/home_widget/home_widget_updater.dart';
import 'package:tach/src/services/photo/photo_loader.dart';

class _FakeUpdater implements HomeWidgetUpdater {
  final shown = <(WidgetContent?, Uint8List?)>[];
  final avatars = <Uint8List?>[];

  @override
  Future<void> show(
    WidgetContent? content, {
    Uint8List? photo,
    Uint8List? avatar,
  }) async {
    shown.add((content, photo));
    avatars.add(avatar);
  }
}

void main() {
  late LedgerCubit cubit;
  late _FakeUpdater updater;

  setUp(() async {
    cubit = LedgerCubit(SampleGroupRepository());
    updater = _FakeUpdater();
    HomeWidgetSync(cubit, updater, NoPhotoLoader());
    await cubit.load();
    await pumpEventQueue();
  });

  tearDown(() => cubit.close());

  test('tải xong: widget nhận khoản mới nhất và số tiền mình cần trả', () {
    final (content, photo) = updater.shown.single;
    expect(content!.group, 'Trọ 12');
    expect(content.balanceLabel, 'Bạn cần trả');
    expect(content.balanceAmount, '266.000đ');
    expect(content.balanceTone, WidgetBalanceTone.owe);
    expect(content.payerInitial, 'M');
    expect(content.payerTone, 'f6c0a8');
    expect(content.avatarKey, isNull);
    expect(content.note, 'Trứng');
    expect(content.amountShort, '30k');
    expect(content.amountFull, '30.000đ');
    // Ảnh mẫu không có dữ liệu ảnh thật.
    expect(content.hasPhoto, isFalse);
    expect(photo, isNull);
  });

  test('ghi khoản có ảnh: widget đổi sang khoản đó kèm ảnh', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    cubit.addExpense(
      amount: 1200000,
      note: '',
      participantIds: [cubit.state.meId],
      photoBytes: bytes,
    );
    await pumpEventQueue();

    final (content, photo) = updater.shown.last;
    expect(updater.shown, hasLength(2));
    expect(content!.payerInitial, 'A');
    expect(content.amountShort, '1,2tr');
    expect(content.hasPhoto, isTrue);
    expect(photo, bytes);
    // Khoản tự trả một mình không làm đổi số dư.
    expect(content.balanceAmount, '266.000đ');
  });

  test(
    'thay đổi không liên quan (thả cảm xúc) thì không cập nhật lại',
    () async {
      cubit.setReaction(cubit.state.expenses.first.id, '👍');
      await pumpEventQueue();
      expect(updater.shown, hasLength(1));
    },
  );

  test('người ghi đổi ảnh đại diện: widget nhận ảnh mới', () async {
    final bytes = Uint8List.fromList([9, 8, 7]);
    cubit.addExpense(
      amount: 5000,
      note: '',
      participantIds: [cubit.state.meId],
    );
    await pumpEventQueue();
    expect(updater.avatars.last, isNull);

    cubit.setMyAvatar(bytes);
    await pumpEventQueue();
    expect(updater.shown, hasLength(3));
    expect(updater.avatars.last, bytes);
    expect(updater.shown.last.$1!.avatarKey, isNotNull);
  });

  test('đăng xuất: widget về trạng thái trống', () async {
    cubit.reset();
    await pumpEventQueue();
    expect(updater.shown.last.$1, isNull);
  });

  test('số dư: được nhận, sòng phẳng và nhóm chưa có khoản chi', () async {
    cubit.createGroup(name: 'Đà Lạt', type: GroupType.trip);
    await pumpEventQueue();
    var content = updater.shown.last.$1!;
    expect(content.group, 'Đà Lạt');
    expect(content.balanceLabel, 'Bạn đã sòng phẳng');
    expect(content.balanceAmount, isNull);
    expect(content.payerInitial, isNull);

    cubit.switchGroup(cubit.state.groups.first.id);
    final other = cubit.state.group.members
        .firstWhere((m) => m.id != cubit.state.meId)
        .id;
    cubit.addExpense(
      amount: 2000000,
      note: 'Tiền phòng',
      participantIds: [other],
    );
    await pumpEventQueue();
    content = updater.shown.last.$1!;
    expect(content.balanceLabel, 'Bạn được nhận');
    expect(content.balanceTone, WidgetBalanceTone.owed);
    expect(content.balanceAmount, '1.734.000đ');
  });
}
