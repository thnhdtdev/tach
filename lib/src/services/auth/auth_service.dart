import 'package:supabase_flutter/supabase_flutter.dart';

import 'identity_provider.dart';

enum SignInMethod { apple, google, phone, guest }

class SignInException implements Exception {
  const SignInException(this.message);

  final String message;

  @override
  String toString() => 'SignInException: $message';
}

/// Người dùng tự đóng bảng đăng nhập; giao diện không cần báo lỗi.
class SignInCancelled extends SignInException {
  const SignInCancelled() : super('Đã hủy đăng nhập.');
}

abstract interface class AuthService {
  List<SignInMethod> get methods;

  bool get isSignedIn;

  /// Tài khoản khách không có cách đăng nhập lại: đăng xuất là mất tài khoản.
  bool get isGuest;

  /// Các cách mà tài khoản khách có thể liên kết để giữ dữ liệu. Rỗng khi
  /// không phải tài khoản khách.
  List<SignInMethod> get linkMethods;

  /// Ném [SignInException] nếu không đăng nhập được, [SignInCancelled] nếu
  /// người dùng tự hủy.
  Future<void> signIn(SignInMethod method);

  /// Gắn tài khoản Apple hoặc Google vào tài khoản khách đang dùng, giữ nguyên
  /// dữ liệu. Ném như [signIn].
  Future<void> link(SignInMethod method);

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
  bool get isGuest => false;

  @override
  List<SignInMethod> get linkMethods => const [];

  @override
  Future<void> signIn(SignInMethod method) async => _signedIn = true;

  @override
  Future<void> link(SignInMethod method) async {}

  @override
  Future<void> signOut() async => _signedIn = false;
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client, {this.providers = const []});

  static const _offline =
      'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';

  final SupabaseClient _client;
  final List<IdentityProvider> providers;

  @override
  List<SignInMethod> get methods => [
    for (final provider in providers) provider.method,
    SignInMethod.guest,
  ];

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  bool get isGuest => _client.auth.currentUser?.isAnonymous ?? false;

  @override
  List<SignInMethod> get linkMethods =>
      isGuest ? [for (final provider in providers) provider.method] : const [];

  @override
  Future<void> signIn(SignInMethod method) async {
    if (method == SignInMethod.guest) {
      await _run(_client.auth.signInAnonymously);
      return;
    }
    final (provider, credential) = await _authenticate(method);
    await _run(
      () => _client.auth.signInWithIdToken(
        provider: provider,
        idToken: credential.idToken,
        nonce: credential.rawNonce,
      ),
    );
  }

  @override
  Future<void> link(SignInMethod method) async {
    final (provider, credential) = await _authenticate(method);
    await _run(
      () => _client.auth.linkIdentityWithIdToken(
        provider: provider,
        idToken: credential.idToken,
        nonce: credential.rawNonce,
      ),
      onRefused:
          'Tài khoản này đã gắn với một tài khoản Tach khác. Chọn tài khoản '
          'khác, hoặc đăng xuất rồi đăng nhập bằng tài khoản đó.',
    );
  }

  Future<(OAuthProvider, IdCredential)> _authenticate(
    SignInMethod method,
  ) async {
    final provider = providers.where((p) => p.method == method).firstOrNull;
    if (provider == null) {
      throw const SignInException('Cách đăng nhập này chưa được bật.');
    }
    final credential = await provider.authenticate();
    if (credential == null) throw const SignInCancelled();
    return (
      method == SignInMethod.apple ? OAuthProvider.apple : OAuthProvider.google,
      credential,
    );
  }

  Future<void> _run(
    Future<Object?> Function() request, {
    String onRefused = 'Máy chủ chưa cho đăng nhập kiểu này. Thử lại sau nhé.',
  }) async {
    try {
      await request();
    } on AuthException catch (error) {
      // Không có mã trạng thái nghĩa là yêu cầu chưa tới được máy chủ.
      throw SignInException(error.statusCode == null ? _offline : onRefused);
    } on Exception {
      throw const SignInException(_offline);
    }
  }

  @override
  Future<void> signOut() async {
    for (final provider in providers) {
      await provider.signOut();
    }
    try {
      await _client.auth.signOut();
    } on Exception {
      // Mất mạng thì phiên trên máy vẫn được xóa; coi như đã đăng xuất.
    }
  }
}
