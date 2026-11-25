import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../screens/account_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/plans_screen.dart';
import '../screens/search_screen.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import 'art.dart';
import 'common.dart';

/// Lets screens inside the main tabs open the side menu and switch tabs.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.openMenu, required this.goToTab, required super.child});
  final VoidCallback openMenu;
  final ValueChanged<int> goToTab;

  static ShellScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope old) => false;
}

/// The header requested by the client: menu on the left, the app's name in
/// the middle, search on the right.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final shell = ShellScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(children: [
        if (shell != null)
          RoundButton(icon: const Icon(Icons.menu_rounded, size: 26), label: s.menu, bare: true, onTap: shell.openMenu)
        else
          const SizedBox(width: 44),
        Expanded(
          child: Semantics(
            header: true,
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFF5A623)]).createShader(r),
              child: Text(
                s.appTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: Colors.white),
              ),
            ),
          ),
        ),
        RoundButton(icon: const Icon(Icons.search_rounded, size: 26), label: s.search, bare: true, onTap: () => push(context, const SearchScreen())),
      ]),
    );
  }
}

/// The side menu: logo, who is signed in, the main places, and language.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentTab, required this.onTab});
  final int currentTab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final p = context.pal;

    Widget item(IconData icon, String label, VoidCallback onTap, {bool selected = false, Widget? trailing}) => ListTile(
          leading: Icon(icon, color: selected ? p.accentText : p.text),
          title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? p.accentText : p.text)),
          trailing: trailing,
          selected: selected,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          selectedTileColor: p.surfaceHi,
          minTileHeight: 52,
          onTap: onTap,
        );

    void go(Widget page) {
      Navigator.pop(context);
      push(context, page);
    }

    return Drawer(
      backgroundColor: p.bg,
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 20), children: [
          Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(Img.logo, width: 56, height: 56)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.appTitle, style: TextStyle(fontFamily: AppTheme.serif, fontSize: 18, fontWeight: FontWeight.w600, color: p.accentText, letterSpacing: 0.8)),
                Text(app.user?.fullName ?? s.guest, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Divider(color: p.border),
          item(Icons.home_rounded, s.home, () => onTab(0), selected: currentTab == 0),
          item(Icons.grid_view_rounded, s.explore, () => onTab(1), selected: currentTab == 1),
          item(Icons.headphones_rounded, s.listen, () => onTab(2), selected: currentTab == 2),
          item(Icons.menu_book_rounded, s.library, () => onTab(3), selected: currentTab == 3),
          Divider(color: p.border),
          item(Icons.workspace_premium_rounded, s.joinPremium, () => go(const PlansScreen()),
              trailing: app.isMember ? Icon(Icons.check_circle_rounded, color: p.accentText) : null),
          item(Icons.settings_rounded, s.accountSettings, () => go(const AccountScreen())),
          if (!app.isSignedIn) item(Icons.login_rounded, s.signInOrUp, () => go(const AuthScreen())),
          Divider(color: p.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(children: [
              Icon(Icons.language_rounded, color: p.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(s.language, style: TextStyle(color: p.muted, fontWeight: FontWeight.w600))),
              const LangToggle(small: true),
            ]),
          ),
          if (app.isSignedIn)
            item(Icons.logout_rounded, s.signOut, () async {
              Navigator.pop(context);
              await app.signOut();
            }),
        ]),
      ),
    );
  }
}
