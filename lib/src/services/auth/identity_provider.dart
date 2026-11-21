import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_service.dart';

/// Kết quả xác thực với Apple hoặc Google, đủ để Supabase tạo phiên đăng nhập.
class IdCredential {
  const IdCredential({required this.idToken, this.rawNonce});

  final String idToken;

  /// Chuỗi ngẫu nhiên gốc; bản băm của nó nằm trong [idToken] để máy chủ đối
  /// chiếu, chống dùng lại token.
  final String? rawNonce;
}

abstract interface class IdentityProvider {
  SignInMethod get method;

  /// Trả về `null` khi người dùng tự đóng bảng đăng nhập. Ném
  /// [SignInException] khi có lỗi.
  Future<IdCredential?> authenticate();

  Future<void> signOut();
}

String _newRawNonce() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
}

String _hash(String rawNonce) =>
    sha256.convert(utf8.encode(rawNonce)).toString();

class AppleIdentity implements IdentityProvider {
  @override
  SignInMethod get method => SignInMethod.apple;

  @override
  Future<IdCredential?> authenticate() async {
    final rawNonce = _newRawNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _hash(rawNonce),
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const SignInException(
          'Apple không trả về thông tin đăng nhập. Thử lại nhé.',
        );
      }
      return IdCredential(idToken: idToken, rawNonce: rawNonce);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw const SignInException(
        'Chưa đăng nhập được bằng Apple. Thử lại nhé.',
      );
    } on SignInWithAppleException {
      throw const SignInException(
        'Máy này chưa dùng được đăng nhập bằng Apple.',
      );
    }
  }

  @override
  Future<void> signOut() async {}
}

class GoogleIdentity implements IdentityProvider {
  GoogleIdentity({required this.iosClientId, required this.webClientId});

  final String iosClientId;
  final String webClientId;

  // Thư viện chỉ cho khởi tạo một lần, nên chuỗi ngẫu nhiên này dùng cho cả
  // phiên chạy app.
  final _rawNonce = _newRawNonce();
  Future<void>? _ready;

  @override
  SignInMethod get method => SignInMethod.google;

  @override
  Future<IdCredential?> authenticate() async {
    try {
      await (_ready ??= GoogleSignIn.instance.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
        nonce: _hash(_rawNonce),
      ));
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const SignInException(
          'Google không trả về thông tin đăng nhập. Thử lại nhé.',
        );
      }
      return IdCredential(idToken: idToken, rawNonce: _rawNonce);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const SignInException(
        'Chưa đăng nhập được bằng Google. Thử lại nhé.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (_ready == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } on Exception {
      // Phiên Google còn sót chỉ làm lần sau khỏi phải chọn lại tài khoản.
    }
  }
}
