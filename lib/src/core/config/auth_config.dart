/// Cấu hình đăng nhập, truyền qua `--dart-define-from-file=.env`. Cách nào
/// chưa cấu hình thì nút của nó không hiện.
abstract final class AuthConfig {
  /// Bật sau khi app đã có quyền "Sign in with Apple" trong Xcode; thiếu quyền
  /// này thì bấm nút sẽ báo lỗi.
  static const appleEnabled = bool.fromEnvironment('APPLE_SIGN_IN');

  /// Client ID loại iOS và loại Web của Google. Supabase kiểm tra token theo
  /// client loại Web, nên cần cả hai.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get googleEnabled =>
      googleIosClientId.isNotEmpty && googleWebClientId.isNotEmpty;
}
