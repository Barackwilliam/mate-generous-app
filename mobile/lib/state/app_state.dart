import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// App-wide state: who is signed in, and reading preferences.
class AppState extends ChangeNotifier {
  AppState(this.api);

  final ApiClient api;
  AppUser? user;
  ThemeMode themeMode = ThemeMode.system;
  double fontScale = 1.0;

  static const minFont = 0.85;
  static const maxFont = 1.6;

  bool get isSignedIn => api.isSignedIn;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index];
    fontScale = prefs.getDouble('fontScale') ?? 1.0;
    await api.loadTokens();
    if (api.isSignedIn) {
      try {
        user = await api.me();
      } catch (_) {
        // Offline at start-up: stay signed in and try again later.
      }
    }
    notifyListeners();
  }

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
  }

  Future<void> register({required String fullName, required String email, String? phone, required String password}) async {
    user = await api.register(fullName: fullName, email: email, phone: phone, password: password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.signOut();
    user = null;
    notifyListeners();
  }
}
