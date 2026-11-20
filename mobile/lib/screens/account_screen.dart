import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'plans_screen.dart';
import 'reader_screen.dart' show ThemeSwitch;

/// Profile, plan status, language, appearance, text size and sign out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<Access>? _access;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.isSignedIn) _access = app.api.access();
  }

  Future<void> _editProfile(AppUser user) async {
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
            TextField(controller: name, decoration: InputDecoration(labelText: s.fullName), textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            TextField(controller: phone, decoration: InputDecoration(labelText: s.phoneOptional), keyboardType: TextInputType.phone),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 32), children: [
          Row(children: [
            RoundButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), label: s.back, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 12),
            Expanded(child: Text(s.account, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 20),
          if (user == null)
            PrimaryButton(label: s.signInOrUp, onPressed: () => push(context, const AuthScreen()))
          else ...[
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _editProfile(user),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: p.accent,
                  child: Text(user.initials, style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800, fontSize: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Text([user.email, if (user.phone != null) '+${user.phone}'].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.muted)),
                  ]),
                ),
                Icon(Icons.edit_outlined, color: p.muted, semanticLabel: s.editProfile),
              ]),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Access>(
              future: _access,
              builder: (context, snap) {
                final a = snap.data;
                final paid = a?.tier != null;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surfaceHi,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: paid ? p.accent : p.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: const CrossIcon(size: 22, color: Palette.night),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(paid ? '${a!.planName ?? a.tier!} · ${s.active}' : s.freePlan,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(paid && a!.expiresAt != null ? s.planUntil(s.fullDate(a.expiresAt!)) : s.freePlanSub,
                            style: TextStyle(fontSize: 12, color: p.muted)),
                      ]),
                    ),
                    TextButton(
                      onPressed: () => push(context, const PlansScreen()),
                      style: TextButton.styleFrom(foregroundColor: p.accentText, minimumSize: const Size(44, 44)),
                      child: Text(paid ? s.manage : s.joinNow, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          _Card(children: [
            Row(children: [
              Icon(Icons.language_rounded, color: p.accentText, size: 20),
              const SizedBox(width: 10),
              Text(s.appLanguage, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                for (final (code, label) in [('sw', 'Kiswahili'), ('en', 'English')])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: app.lang == code,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => app.setLang(code),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: app.lang == code ? p.accent : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                          child: Text(label,
                              style: TextStyle(fontSize: 14, fontWeight: app.lang == code ? FontWeight.w800 : FontWeight.w600, color: app.lang == code ? p.onAccent : p.muted)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          _Card(children: [
            Text(s.appearance, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ThemeSwitch(value: app.themeMode, onChanged: app.setThemeMode),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text(s.textSize, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              Text('Aa', style: TextStyle(fontFamily: AppTheme.serif, fontSize: 15 * app.fontScale, color: p.accentText)),
            ]),
            Slider(min: AppState.minFont, max: AppState.maxFont, divisions: 7, value: app.fontScale, onChanged: app.setFontScale),
          ]),
          if (user != null) ...[
            const SizedBox(height: 12),
            Material(
              color: p.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: p.border)),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFE26D7A)),
                title: Text(s.signOut, style: const TextStyle(color: Color(0xFFE26D7A), fontWeight: FontWeight.w700)),
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
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.pal.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
