import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Ảnh đã chụp nhưng chưa biết giá, chờ người dùng điền tiền rồi mới gửi.
class CaptureDraft {
  const CaptureDraft({
    required this.id,
    required this.createdAt,
    this.note = '',
    this.photoBytes,
    this.photoUrl,
  });

  final String id;
  final DateTime createdAt;
  final String note;
  final Uint8List? photoBytes;

  /// Chỉ dùng cho ảnh mẫu ở bản thử nghiệm; ảnh thật luôn có [photoBytes].
  final String? photoUrl;

  CaptureDraft withNote(String note) => CaptureDraft(
    id: id,
    createdAt: createdAt,
    note: note,
    photoBytes: photoBytes,
    photoUrl: photoUrl,
  );
}

/// Nơi giữ các bản nháp. Nháp chỉ nằm trên máy này: chưa gửi cho nhóm, chưa
/// tính vào số dư.
abstract interface class DraftStore {
  /// Cũ nhất đứng đầu.
  Future<List<CaptureDraft>> load();

  /// Thêm nháp mới, hoặc ghi đè nháp cùng id.
  Future<void> save(CaptureDraft draft);

  Future<void> remove(String id);

  Future<void> clear();
}

class MemoryDraftStore implements DraftStore {
  final _drafts = <CaptureDraft>[];

  @override
  Future<List<CaptureDraft>> load() async => [..._drafts];

  @override
  Future<void> save(CaptureDraft draft) async {
    final index = _drafts.indexWhere((d) => d.id == draft.id);
    if (index < 0) {
      _drafts.add(draft);
    } else {
      _drafts[index] = draft;
    }
  }

  @override
  Future<void> remove(String id) async =>
      _drafts.removeWhere((d) => d.id == id);

  @override
  Future<void> clear() async => _drafts.clear();
}

/// Giữ nháp trong thư mục riêng của app: mỗi ảnh một file, kèm một file mục
/// lục. Lỗi đọc ghi được nuốt đi, vì mất một bản nháp không đáng làm hỏng app.
class FileDraftStore implements DraftStore {
  FileDraftStore({Future<Directory> Function()? root})
    : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;

  Future<Directory> _folder() async {
    final folder = Directory('${(await _root()).path}/capture_drafts');
    await folder.create(recursive: true);
    return folder;
  }

  File _index(Directory folder) => File('${folder.path}/index.json');

  File _photo(Directory folder, String id) => File('${folder.path}/$id.jpg');

  Future<List<Map<String, dynamic>>> _readIndex(Directory folder) async {
    final file = _index(folder);
    if (!await file.exists()) return [];
    final rows = jsonDecode(await file.readAsString()) as List;
    return [for (final row in rows) row as Map<String, dynamic>];
  }

  @override
  Future<List<CaptureDraft>> load() async {
    try {
      final folder = await _folder();
      final drafts = <CaptureDraft>[];
      for (final row in await _readIndex(folder)) {
        final id = row['id'] as String;
        final photo = _photo(folder, id);
        final url = row['photoUrl'] as String?;
        final hasFile = await photo.exists();
        // Mất file ảnh thì nháp không còn dùng được.
        if (!hasFile && url == null) continue;
        drafts.add(
          CaptureDraft(
            id: id,
            createdAt: DateTime.parse(row['createdAt'] as String),
            note: row['note'] as String? ?? '',
            photoBytes: hasFile ? await photo.readAsBytes() : null,
            photoUrl: url,
          ),
        );
      }
      return drafts;
    } on Exception {
      return [];
    }
  }

  @override
  Future<void> save(CaptureDraft draft) async {
    try {
      final folder = await _folder();
      final bytes = draft.photoBytes;
      if (bytes != null) await _photo(folder, draft.id).writeAsBytes(bytes);
      final rows = await _readIndex(folder)
        ..removeWhere((row) => row['id'] == draft.id)
        ..add({
          'id': draft.id,
          'createdAt': draft.createdAt.toIso8601String(),
          'note': draft.note,
          'photoUrl': draft.photoUrl,
        })
        ..sort(
          (a, b) =>
              (a['createdAt'] as String).compareTo(b['createdAt'] as String),
        );
      await _index(folder).writeAsString(jsonEncode(rows));
    } on Exception {
      // Xem ghi chú ở đầu lớp.
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      final folder = await _folder();
      final photo = _photo(folder, id);
      if (await photo.exists()) await photo.delete();
      final rows = await _readIndex(folder)
        ..removeWhere((row) => row['id'] == id);
      await _index(folder).writeAsString(jsonEncode(rows));
    } on Exception {
      // Xem ghi chú ở đầu lớp.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final folder = await _folder();
      if (await folder.exists()) await folder.delete(recursive: true);
    } on Exception {
      // Xem ghi chú ở đầu lớp.
    }
  }
}
