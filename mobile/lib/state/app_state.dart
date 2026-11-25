import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../i18n/strings.dart';

/// App-wide state: who is signed in, language and reading preferences.
class AppState extends ChangeNotifier {
  AppState(this.api);

  final ApiClient api;
  AppUser? user;
  ThemeMode themeMode = ThemeMode.dark;
  double fontScale = 1.0;
  String lang = 'sw';

  /// "standard", "premium", or null (free). Used for member-only features such as sharing.
  String? tier;
  bool get isMember => tier != null;

  /// The reader keeps its own look: cream paper by default, as in the design.
  bool readerLight = true;

  static const minFont = 0.85;
  static const maxFont = 1.6;

  bool get isSignedIn => api.isSignedIn;
  S get s => S(lang);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.dark.index];
    fontScale = prefs.getDouble('fontScale') ?? 1.0;
    lang = prefs.getString('lang') ?? 'sw';
    readerLight = prefs.getBool('readerLight') ?? true;
    await api.loadTokens();
    if (api.isSignedIn) {
      try {
        user = await api.me();
      } catch (_) {
        // Offline at start-up: stay signed in and try again later.
      }
      await refreshAccess();
    }
    notifyListeners();
  }

  Future<void> setLang(String value) async {
    lang = value == 'en' ? 'en' : 'sw';
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('lang', lang);
  }

  Future<void> setReaderLight(bool value) async {
    readerLight = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('readerLight', value);
  }

  /// Re-read the user's plan (after sign-in, or when a screen needs it).
  Future<void> refreshAccess() async {
    if (!api.isSignedIn) {
      tier = null;
      return;
    }
    try {
      tier = (await api.access()).tier;
      notifyListeners();
    } catch (_) {}
  }

  /// Download the essentials in the background (first run, and after sign-in).
  void syncInBackground() => api.prefetch().catchError((_) {});

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('themeMode', mode.index);
  }

  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(minFont, maxFont);
    notifyListeners();
    (await SharedPreferences.getInstance()).setDouble('fontScale', fontScale);
  }

  Future<void> login(String identifier, String password) async {
    user = await api.login(identifier, password);
    notifyListeners();
    await refreshAccess();
    syncInBackground();
  }

  Future<void> register({required String fullName, required String email, String? phone, required String password}) async {
    user = await api.register(fullName: fullName, email: email, phone: phone, password: password);
    notifyListeners();
    await refreshAccess();
    syncInBackground();
  }

  Future<void> resetPassword(String identifier, String code, String newPassword) async {
    user = await api.resetPassword(identifier, code, newPassword);
    notifyListeners();
    await refreshAccess();
    syncInBackground();
  }

  Future<void> updateProfile({required String fullName, String? phone}) async {
    user = await api.updateMe(fullName: fullName, phone: phone);
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.signOut();
    user = null;
    tier = null;
    notifyListeners();
    syncInBackground();
  }
}

extension AppStateX on BuildContext {
  /// The words in the current language. Rebuilds when the language changes.
  S get s => S(select<AppState, String>((a) => a.lang));
}
