import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tach/src/services/drafts/draft_store.dart';

void main() {
  late Directory root;
  late FileDraftStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('tach_drafts');
    store = FileDraftStore(root: () async => root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  CaptureDraft draft(String id, int minute, {String note = ''}) => CaptureDraft(
    id: id,
    createdAt: DateTime(2026, 11, 21, 12, minute),
    note: note,
    photoBytes: Uint8List.fromList([1, 2, 3, minute]),
  );

  test('nháp còn nguyên sau khi mở lại app, cũ nhất đứng đầu', () async {
    await store.save(draft('b', 30, note: 'Phở'));
    await store.save(draft('a', 10));

    final reopened = FileDraftStore(root: () async => root);
    final drafts = await reopened.load();
    expect(drafts.map((d) => d.id), ['a', 'b']);
    expect(drafts.last.note, 'Phở');
    expect(drafts.last.photoBytes, [1, 2, 3, 30]);
    expect(drafts.last.createdAt, DateTime(2026, 11, 21, 12, 30));
  });

  test('lưu lại cùng id thì ghi đè, không nhân đôi', () async {
    await store.save(draft('a', 10));
    await store.save(draft('a', 10).withNote('Bún chả'));
    final drafts = await store.load();
    expect(drafts.single.note, 'Bún chả');
  });

  test('xóa một nháp thì ảnh của nó cũng mất', () async {
    await store.save(draft('a', 10));
    await store.save(draft('b', 20));
    await store.remove('a');

    expect((await store.load()).map((d) => d.id), ['b']);
    expect(File('${root.path}/capture_drafts/a.jpg').existsSync(), isFalse);
  });

  test('xóa hết khi đăng xuất', () async {
    await store.save(draft('a', 10));
    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('mất file ảnh thì bỏ qua nháp đó thay vì báo lỗi', () async {
    await store.save(draft('a', 10));
    await store.save(draft('b', 20));
    File('${root.path}/capture_drafts/a.jpg').deleteSync();
    expect((await store.load()).map((d) => d.id), ['b']);
  });

  test('chưa có gì thì trả về rỗng', () async {
    expect(await store.load(), isEmpty);
  });
}
