import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String _val(String key, String fallback) {
    final v = dotenv.env[key];
    if (v == null || v.trim().isEmpty) return fallback;
    return v.trim();
  }

  static String get supabaseUrl =>
      _val('SUPABASE_URL', 'https://whxqciwphwgzcshejpty.supabase.co');

  static String get supabasePublishableKey =>
      _val('SUPABASE_PUBLISHABLE_KEY', '');

  static String get googleClientId =>
      _val('SUPABASE_AUTH_GOOGLE_CLIENT_ID', '');

  static String get apiBaseUrl => _val(
    'API_BASE_URL',
    'https://whxqciwphwgzcshejpty.supabase.co/functions/v1/api',
  );

  static String get authRedirectUrl =>
      _val('SUPABASE_AUTH_REDIRECT_URL', 'numination://auth');

  static String get appVersion => _val('APP_VERSION', '1.0.0');
}
