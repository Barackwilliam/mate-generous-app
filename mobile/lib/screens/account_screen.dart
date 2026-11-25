import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';
import 'auth_screen.dart';
import 'plans_screen.dart';
import 'reader_screen.dart' show Segmented, ThemeSwitch;

/// Profile, plan status, language, appearance, text size and sign out.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _editProfile(BuildContext context, AppUser user) async {
    final app = context.read<AppState>();
    final s = app.s;
    final name = TextEditingController(text: user.fullName);
    final phone = TextEditingController(text: user.phone == null ? '' : '0${user.phone!.substring(3)}');
    String? error;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pal.bg,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.editProfile, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            WhiteField(controller: name, hint: s.fullName, icon: Icons.person_outline_rounded, capitalize: true),
            const SizedBox(height: 12),
            WhiteField(controller: phone, hint: s.phoneOptional, icon: Icons.phone_outlined, keyboard: TextInputType.phone),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: s.save,
              onPressed: () async {
                try {
                  await app.updateProfile(fullName: name.text.trim(), phone: phone.text.trim());
                  if (context.mounted) Navigator.pop(context);
                } on ApiException catch (e) {
                  setSheet(() => error = errorText(s, e));
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final p = context.pal;
    final user = app.user;

    Widget card(List<Widget> children) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        );

    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 32), children: [
            Row(children: [
              RoundButton(icon: const Icon(Icons.arrow_back_rounded), label: s.back, bare: true, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(child: Text(s.account, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 16),
            if (user == null)
              PrimaryButton(label: s.signInOrUp, onPressed: () => push(context, const AuthScreen()))
            else ...[
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _editProfile(context, user),
                child: Row(children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(gradient: Palette.goldGradient, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(user.initials, style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text([user.email, if (user.phone != null) '+${user.phone}'].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.muted)),
                    ]),
                  ),
                  Icon(Icons.edit_rounded, color: p.muted, semanticLabel: s.editProfile),
                ]),
              ),
              const SizedBox(height: 16),
              LiveData<Access>(
                load: () => app.api.access(),
                loading: const SizedBox.shrink(),
                builder: (context, a, _) {
                  final paid = a.tier != null;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF3A1A86), Color(0xFF1B2462)]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: paid ? p.accent : p.border),
                    ),
                    child: Row(children: [
                      Image.asset(Img.premium, width: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(paid ? '${a.planName ?? a.tier!} · ${s.active}' : s.freePlan,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text(paid && a.expiresAt != null ? s.planUntil(s.fullDate(a.expiresAt!)) : s.freePlanSub,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFFD5DAF5))),
                        ]),
                      ),
                      TextButton(
                        onPressed: () => push(context, const PlansScreen()),
                        style: TextButton.styleFrom(foregroundColor: Palette.gold, minimumSize: const Size(44, 44)),
                        child: Text(paid ? s.manage : s.joinNow, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  );
                },
              ),
            ],
            const SizedBox(height: 14),
            card([
              Row(children: [
                Icon(Icons.language_rounded, color: p.accentText, size: 20),
                const SizedBox(width: 10),
                Text(s.appLanguage, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              Segmented<String>(options: const {'sw': 'Kiswahili', 'en': 'English'}, value: app.lang, onChanged: app.setLang),
            ]),
            const SizedBox(height: 12),
            card([
              Text(s.appearance, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ThemeSwitch(value: app.themeMode, onChanged: app.setThemeMode),
              const SizedBox(height: 16),
              Text(s.readerLook, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Segmented<bool>(options: {true: s.light, false: s.dark}, value: app.readerLight, onChanged: app.setReaderLight),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text(s.textSize, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800))),
                Text('Aa', style: TextStyle(fontFamily: AppTheme.serif, fontSize: 15 * app.fontScale, color: p.accentText)),
              ]),
              Slider(min: AppState.minFont, max: AppState.maxFont, divisions: 7, value: app.fontScale, onChanged: app.setFontScale),
            ]),
            if (user != null) ...[
              const SizedBox(height: 12),
              Material(
                color: p.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.border)),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFFF8A8A)),
                  title: Text(s.signOut, style: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w800)),
                  onTap: () async {
                    await app.signOut();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(s.openSourceFonts, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.faint)),
          ]),
        ),
      ),
    );
  }
}
