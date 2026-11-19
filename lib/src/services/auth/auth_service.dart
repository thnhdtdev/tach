import 'package:supabase_flutter/supabase_flutter.dart';

enum SignInMethod { apple, google, phone, guest }

class SignInException implements Exception {
  const SignInException(this.message);

  final String message;

  @override
  String toString() => 'SignInException: $message';
}

abstract interface class AuthService {
  List<SignInMethod> get methods;

  bool get isSignedIn;

  /// Ném [SignInException] nếu không đăng nhập được.
  Future<void> signIn(SignInMethod method);

  Future<void> signOut();
}

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
