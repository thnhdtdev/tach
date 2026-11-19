import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Tiền tố của [Expense.photoUrl] khi ảnh nằm trong kho ảnh trên máy chủ:
/// `remote:<id nhóm>/<id khoản chi>.jpg`.
const remotePhotoPrefix = 'remote:';

/// Tải ảnh khoản chi từ kho ảnh trên máy chủ.
abstract interface class PhotoLoader {
  /// Trả về dữ liệu ảnh, hoặc `null` nếu không tải được.
  Future<Uint8List?> load(String path);

  /// Ghi sẵn ảnh vừa tải lên để khỏi phải tải về lại.
  void remember(String path, Uint8List bytes);
}

/// Bản dữ liệu mẫu không có kho ảnh.
class NoPhotoLoader implements PhotoLoader {
  @override
  Future<Uint8List?> load(String path) async => null;

  @override
  void remember(String path, Uint8List bytes) {}
}

/// Tải ảnh từ kho `photos` của Supabase, giữ lại các ảnh xem gần đây trong bộ
/// nhớ để vuốt qua lại không phải tải lại.
class SupabasePhotoLoader implements PhotoLoader {
  SupabasePhotoLoader(this._client);

  /// Mỗi ảnh khoảng 150 KB, nên chừng này ảnh chiếm cỡ 10 MB bộ nhớ.
  static const _capacity = 64;

  final SupabaseClient _client;

  /// Giữ thứ tự thêm vào: ảnh ở đầu là ảnh lâu chưa xem nhất.
  final _cache = <String, Uint8List>{};
  final _loading = <String, Future<Uint8List?>>{};

  @override
  Future<Uint8List?> load(String path) {
    final cached = _cache.remove(path);
    if (cached != null) {
      // Đưa về cuối hàng: ảnh vừa xem là ảnh bị bỏ sau cùng.
      _cache[path] = cached;
      return Future.value(cached);
    }
    return _loading[path] ??= _download(path);
  }

  Future<Uint8List?> _download(String path) async {
    try {
      final bytes = await _client.storage.from('photos').download(path);
      remember(path, bytes);
      return bytes;
    } on Exception {
      return null;
    } finally {
      _loading.remove(path);
    }
  }

  @override
  void remember(String path, Uint8List bytes) {
    _cache.remove(path);
    _cache[path] = bytes;
    while (_cache.length > _capacity) {
      _cache.remove(_cache.keys.first);
    }
  }
}
