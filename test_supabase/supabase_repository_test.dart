// Kiểm thử lớp dữ liệu với một Supabase thật đang chạy trên máy:
//
//   supabase start
//   flutter test test_supabase \
//     --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=<khóa công khai từ `supabase status`>
//
// Không nằm trong `test/` vì cần gọi mạng thật.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tach/src/core/config/supabase_config.dart';
import 'package:tach/src/core/ids/uuid.dart';
import 'package:tach/src/datasource/supabase/supabase_group_repository.dart';
import 'package:tach/src/domain/entities/expense.dart';
import 'package:tach/src/domain/entities/group.dart';
import 'package:tach/src/domain/entities/settlement.dart';
import 'package:tach/src/services/photo/photo_loader.dart';

class _User {
  _User._(this.client, this.photos, this.repository);

  static Future<_User> signUp(String name) async {
    final client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );
    await client.auth.signInAnonymously();
    final photos = SupabasePhotoLoader(client);
    final user = _User._(
      client,
      photos,
      SupabaseGroupRepository(client, photos),
    );
    await user.repository.saveProfile(Member(id: user.id, name: name));
    return user;
  }

  final SupabaseClient client;
  final SupabasePhotoLoader photos;
  final SupabaseGroupRepository repository;

  String get id => client.auth.currentUser!.id;
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Chờ quá 10 giây');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  final configured = SupabaseConfig.isConfigured;

  test(
    'hai người dùng chung một nhóm, người ngoài không thấy gì',
    skip: configured
        ? false
        : 'Chưa truyền SUPABASE_URL và SUPABASE_PUBLISHABLE_KEY',
    () async {
      final an = await _User.signUp('An');
      final minh = await _User.signUp('Minh');
      final outsider = await _User.signUp('Người lạ');
      addTearDown(() async {
        for (final user in [an, minh, outsider]) {
          await user.client.dispose();
        }
      });

      var mine = await an.repository.load();
      expect(mine.me.name, 'An');
      expect(mine.groups, isEmpty);

      final invite = newUuid()
          .replaceAll('-', '')
          .substring(0, 6)
          .toUpperCase();
      final group = Group(
        id: newUuid(),
        name: 'Trọ 12',
        code: 'TRO12',
        type: GroupType.room,
        inviteCode: invite,
        createdBy: an.id,
        members: [mine.me],
      );
      await an.repository.createGroup(group);

      expect(await minh.repository.joinGroup('ZZZZZZ'), isNull);
      expect(await minh.repository.joinGroup(invite), group.id);
      expect(await minh.repository.joinGroup(invite), group.id);

      mine = await an.repository.load();
      expect(mine.groups.single.group.name, 'Trọ 12');
      expect(mine.groups.single.group.type, GroupType.room);
      expect(mine.groups.single.group.inviteCode, invite);
      expect(mine.groups.single.group.members.map((m) => m.name), [
        'An',
        'Minh',
      ]);

      final photo = File('assets/images/onboarding/hotpot.jpg')
          .readAsBytesSync();
      final expense = Expense(
        id: newUuid(),
        payerId: an.id,
        amount: 30000,
        note: 'Trứng',
        photoBytes: photo,
        splits: {an.id: 15000, minh.id: 15000},
        createdAt: DateTime.now(),
      );
      var minhSignals = 0;
      var outsiderSignals = 0;
      final watches = [
        minh.repository.watchGroups({group.id}).listen((_) => minhSignals++),
        outsider.repository
            .watchGroups({group.id})
            .listen((_) => outsiderSignals++),
      ];
      // Kênh công khai cùng tên cũng không được nhận tín hiệu của kênh riêng.
      final eavesdropper = await _User.signUp('Nghe lén');
      var eavesdropped = 0;
      eavesdropper.client
          .channel('group:${group.id}')
          .onBroadcast(event: 'changed', callback: (_) => eavesdropped++)
          .subscribe();
      addTearDown(() async {
        for (final watch in watches) {
          await watch.cancel();
        }
        await eavesdropper.client.dispose();
      });
      // Chờ hai kênh nối xong rồi mới ghi, để tín hiệu không phát trước khi nghe.
      await Future<void>.delayed(const Duration(seconds: 2));

      await an.repository.addExpense(group.id, expense);
      await _until(() => minhSignals > 0);
      expect(outsiderSignals, 0);

      var theirs = await minh.repository.load();
      final seen = theirs.groups.single.expenses.single;
      expect(seen.amount, 30000);
      expect(seen.note, 'Trứng');
      expect(seen.payerId, an.id);
      expect(seen.splits, {an.id: 15000, minh.id: 15000});
      expect(seen.photoUrl, '$remotePhotoPrefix${group.id}/${expense.id}.jpg');
      expect(
        seen.createdAt.difference(DateTime.now()).inMinutes.abs(),
        lessThan(2),
      );

      final path = seen.photoUrl!.substring(remotePhotoPrefix.length);
      final downloaded = await minh.photos.load(path);
      expect(downloaded, isNotNull);
      // JPEG bắt đầu bằng FF D8; ảnh 680 điểm ảnh nén xong phải nhỏ hơn bản gốc.
      expect(downloaded!.sublist(0, 2), [0xFF, 0xD8]);
      expect(downloaded.length, lessThan(photo.length));
      expect(await outsider.photos.load(path), isNull);

      await expectLater(
        an.repository.addExpense(
          group.id,
          Expense(
            id: newUuid(),
            payerId: an.id,
            amount: 30000,
            note: 'Sai',
            splits: {an.id: 15000, minh.id: 10000},
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );

      final mistake = Expense(
        id: newUuid(),
        payerId: an.id,
        amount: 99000,
        note: 'Ghi nhầm',
        photoBytes: photo,
        splits: {an.id: 49500, minh.id: 49500},
        createdAt: DateTime.now(),
      );
      final mistakePhoto = '${group.id}/${mistake.id}.jpg';
      await an.repository.addExpense(group.id, mistake);
      await minh.repository.addComment(
        mistake.id,
        Comment(
          id: newUuid(),
          userId: minh.id,
          text: 'Nhầm rồi',
          createdAt: DateTime.now(),
        ),
      );

      await expectLater(
        minh.repository.deleteExpense(group.id, mistake.id),
        throwsA(isA<PostgrestException>()),
      );
      await minh.client.storage.from('photos').remove([mistakePhoto]);
      expect(await outsider.photos.load(mistakePhoto), isNull);
      expect(await minh.photos.load(mistakePhoto), isNotNull);
      expect((await an.repository.load()).groups.single.expenses, hasLength(2));

      await an.repository.deleteExpense(group.id, mistake.id);
      theirs = await minh.repository.load();
      expect(theirs.groups.single.expenses.single.id, expense.id);
      expect(await SupabasePhotoLoader(minh.client).load(mistakePhoto), isNull);
      await an.repository.deleteExpense(group.id, mistake.id);

      minhSignals = 0;
      await an.repository.saveProfile(Member(id: an.id, name: 'An'));
      await _until(() => minhSignals > 0);
      expect(outsiderSignals, 0);
      expect(eavesdropped, 0);

      await minh.repository.setReaction(expense.id, '👍');
      await minh.repository.setReaction(expense.id, '😂');
      final root = Comment(
        id: newUuid(),
        userId: minh.id,
        text: 'Rẻ ghê',
        createdAt: DateTime.now(),
      );
      await minh.repository.addComment(expense.id, root);
      await an.repository.addComment(
        expense.id,
        Comment(
          id: newUuid(),
          userId: an.id,
          parentId: root.id,
          text: 'Chợ đầu ngõ đó',
          createdAt: DateTime.now(),
        ),
      );

      mine = await an.repository.load();
      var loaded = mine.groups.single.expenses.single;
      expect(loaded.reactions, {minh.id: '😂'});
      expect(loaded.comments.map((c) => c.text), ['Rẻ ghê', 'Chợ đầu ngõ đó']);
      expect(loaded.comments.last.parentId, root.id);
      expect(loaded.editedAt, isNull);

      await expectLater(
        minh.repository.updateExpense(
          loaded.copyWith(amount: 1000, splits: {minh.id: 1000}),
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        an.repository.updateExpense(
          loaded.copyWith(
            amount: 40000,
            splits: {an.id: 15000, minh.id: 15000},
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        an.repository.updateExpense(
          loaded.copyWith(amount: 40000, splits: {outsider.id: 40000}),
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await an.repository.load()).groups.single.expenses.single.amount,
        30000,
      );

      minhSignals = 0;
      await an.repository.updateExpense(
        loaded.copyWith(
          amount: 40000,
          note: ' Trứng, sữa ',
          splits: {minh.id: 40000},
        ),
      );
      await _until(() => minhSignals > 0);
      theirs = await minh.repository.load();
      final edited = theirs.groups.single.expenses.single;
      expect(edited.amount, 40000);
      expect(edited.note, 'Trứng, sữa');
      expect(edited.splits, {minh.id: 40000});
      expect(edited.editedAt, isNotNull);
      expect(edited.createdAt, loaded.createdAt);
      expect(edited.photoUrl, loaded.photoUrl);
      expect(edited.reactions, {minh.id: '😂'});
      expect(edited.comments, hasLength(2));

      await an.repository.updateExpense(loaded);

      await minh.repository.setReaction(expense.id, null);
      mine = await an.repository.load();
      loaded = mine.groups.single.expenses.single;
      expect(loaded.reactions, isEmpty);

      await an.repository.saveProfile(
        Member(
          id: an.id,
          name: 'An',
          bank: const BankAccount(
            bin: '970422',
            bankName: 'MB Bank',
            accountNumber: '0000000001',
            holderName: 'TAI KHOAN MAU AN',
          ),
        ),
      );
      await an.repository.setAvatar(photo);
      theirs = await minh.repository.load();
      final anAtMinh = theirs.groups.single.group.members.first;
      expect(anAtMinh.bank?.bankName, 'MB Bank');
      expect(anAtMinh.avatarBytes, isA<Uint8List>());

      await an.repository.setAvatar(null);
      // Máy Minh đã giữ ảnh cũ trong bộ nhớ; dùng máy khác của An để kiểm tra.
      mine = await an.repository.load();
      expect(mine.me.avatarBytes, isNull);

      await expectLater(
        minh.repository.leaveGroup(group.id),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        an.repository.deleteGroup(group.id),
        throwsA(isA<PostgrestException>()),
      );

      final settlement = Settlement(
        id: newUuid(),
        fromId: minh.id,
        toId: an.id,
        amount: 15000,
        transferCode: 'TRO12 MINH T11',
        status: SettlementStatus.pending,
        createdAt: DateTime.now(),
      );
      await minh.repository.addSettlement(group.id, settlement);
      await expectLater(
        minh.repository.confirmSettlement(settlement.id),
        throwsA(isA<PostgrestException>()),
      );
      await an.repository.confirmSettlement(settlement.id);
      mine = await an.repository.load();
      expect(
        mine.groups.single.settlements.single.status,
        SettlementStatus.confirmed,
      );

      await minh.repository.renameGroup(group.id, 'Trọ 12A');
      expect((await outsider.repository.load()).groups, isEmpty);

      await minh.repository.leaveGroup(group.id);
      expect((await minh.repository.load()).groups, isEmpty);
      mine = await an.repository.load();
      expect(mine.groups.single.group.name, 'Trọ 12A');
      expect(mine.groups.single.group.members.map((m) => m.name), ['An']);
      expect(mine.groups.single.group.formerMembers.map((m) => m.name), [
        'Minh',
      ]);

      // Minh đã rời nhóm nhưng vẫn giữ phần của mình khi An sửa khoản chi.
      await an.repository.updateExpense(loaded.copyWith(note: 'Trứng gà'));
      mine = await an.repository.load();
      expect(mine.groups.single.expenses.single.note, 'Trứng gà');
      expect(mine.groups.single.expenses.single.splits, loaded.splits);

      await an.repository.deleteGroup(group.id);
      expect((await an.repository.load()).groups, isEmpty);
    },
  );
}
