abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');

  /// Khóa công khai (publishable, hoặc anon ở project cũ). Không bao giờ đặt
  /// khóa bí mật (secret, service role) vào app.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
