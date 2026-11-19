/// Build-time settings. Codemagic passes these with --dart-define.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator → local backend
  );
  static const appName = 'Mate Generous';
}
