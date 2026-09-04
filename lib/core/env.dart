import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabasePublishableKey =>
      dotenv.get('SUPABASE_PUBLISHABLE_KEY', fallback: '');
  static String get googleClientId =>
      dotenv.get('SUPABASE_AUTH_GOOGLE_CLIENT_ID', fallback: '');
  static String get apiBaseUrl => dotenv.get(
        'API_BASE_URL',
        fallback: 'https://backend-one-livid-77.vercel.app/api',
      );
  static String get authRedirectUrl =>
      dotenv.get('SUPABASE_AUTH_REDIRECT_URL', fallback: 'numination://auth');
  static String get appVersion =>
      dotenv.get('APP_VERSION', fallback: '1.0.0');
}
