import 'package:supabase_flutter/supabase_flutter.dart';

/// Cách đăng nhập mà màn đăng nhập có thể đưa ra.
enum SignInMethod {
  apple,
  google,
  phone,

  /// Dùng ngay không cần tài khoản; tài khoản gắn với máy này.
  guest,
}

/// Đăng nhập không thành công, kèm lời giải thích hiện cho người dùng.
class SignInException implements Exception {
  const SignInException(this.message);

  final String message;

  @override
  String toString() => 'SignInException: $message';
}

abstract interface class AuthService {
  /// Các cách đăng nhập đang dùng được, theo thứ tự hiện trên màn đăng nhập.
  List<SignInMethod> get methods;

  /// Đã có phiên đăng nhập, ví dụ còn lưu từ lần mở app trước.
  bool get isSignedIn;

  /// Ném [SignInException] nếu không đăng nhập được.
  Future<void> signIn(SignInMethod method);

  Future<void> signOut();
}

/// Đăng nhập giả cho bản dữ liệu mẫu: cách nào cũng vào thẳng nhóm mẫu, và mỗi
/// lần mở app đều qua màn đăng nhập.
class DemoAuthService implements AuthService {
  var _signedIn = false;

  @override
  List<SignInMethod> get methods => const [
    SignInMethod.apple,
    SignInMethod.google,
    SignInMethod.phone,
  ];

  @override
  bool get isSignedIn => _signedIn;

  @override
  Future<void> signIn(SignInMethod method) async => _signedIn = true;

  @override
  Future<void> signOut() async => _signedIn = false;
}

/// Đăng nhập qua Supabase. Hiện mới có tài khoản khách; Apple, Google và số
/// điện thoại cần cấu hình nhà cung cấp trên Supabase trước khi nối vào đây.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  List<SignInMethod> get methods => const [SignInMethod.guest];

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Future<void> signIn(SignInMethod method) async {
    if (method != SignInMethod.guest) {
      throw const SignInException('Cách đăng nhập này chưa được bật.');
    }
    try {
      await _client.auth.signInAnonymously();
    } on AuthException catch (error) {
      // Máy chủ trả lời nhưng từ chối, thường do chưa bật tài khoản khách.
      throw SignInException(
        error.statusCode == null
            ? 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'
            : 'Máy chủ chưa cho đăng nhập kiểu này. Thử lại sau nhé.',
      );
    } on Exception {
      throw const SignInException(
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on Exception {
      // Mất mạng thì phiên trên máy vẫn được xóa; coi như đã đăng xuất.
    }
  }
}
