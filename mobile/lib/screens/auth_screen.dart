import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

/// Sign in (email or phone) and registration on one screen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _identifier, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.read<AppState>();
    try {
      if (_register) {
        await app.register(fullName: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), password: _password.text);
      } else {
        await app.login(_identifier.text.trim(), _password.text);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = errorText(app.s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? s.required : null;
    return Scaffold(
      body: Stack(children: [
        Positioned(top: -40, left: 0, right: 0, height: 340, child: CustomPaint(painter: _Rays(p.accent))),
        SafeArea(
          child: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 28), children: [
              Row(children: [
                if (Navigator.canPop(context))
                  RoundButton(icon: const Icon(Icons.close_rounded), label: s.close, onTap: () => Navigator.pop(context)),
                const Spacer(),
                const LangToggle(),
              ]),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(26)),
                  alignment: Alignment.center,
                  child: const CrossIcon(size: 42, color: Palette.night),
                ),
              ),
              const SizedBox(height: 16),
              Text(_register ? s.createAccount : s.welcomeBack,
                  textAlign: TextAlign.center, style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 30, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_register ? s.createAccountSub : s.welcomeBackSub, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.muted)),
              const SizedBox(height: 28),
              if (_register) ...[
                TextFormField(controller: _name, decoration: InputDecoration(labelText: s.fullName), textCapitalization: TextCapitalization.words, validator: required),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: InputDecoration(labelText: s.email),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? s.badEmail : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: s.phoneOptional, hintText: '0712 345 678'),
                  keyboardType: TextInputType.phone,
                ),
              ] else
                TextFormField(
                  controller: _identifier,
                  decoration: InputDecoration(labelText: s.emailOrPhone),
                  keyboardType: TextInputType.emailAddress,
                  validator: required,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: s.password,
                  helperText: _register ? s.passwordHelp : null,
                  suffixIcon: IconButton(
                    tooltip: s.showPassword,
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8) ? s.shortPassword : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 22),
              PrimaryButton(label: _register ? s.register : s.signIn, busy: _busy, onPressed: _submit),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Divider(color: p.border)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s.or, style: TextStyle(color: p.faint, fontWeight: FontWeight.w600))),
                Expanded(child: Divider(color: p.border)),
              ]),
              const SizedBox(height: 14),
              SecondaryButton(label: s.continueAsGuest, onPressed: () => Navigator.maybePop(context)),
              const SizedBox(height: 18),
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_register ? s.haveAccount : s.noAccount, style: TextStyle(color: p.muted)),
                TextButton(
                  onPressed: () => setState(() {
                    _register = !_register;
                    _error = null;
                  }),
                  style: TextButton.styleFrom(foregroundColor: p.accentText, minimumSize: const Size(44, 44)),
                  child: Text(_register ? s.signIn : s.registerFree, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Rays extends CustomPainter {
  _Rays(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * 0.5);
    final rect = Rect.fromCircle(center: c, radius: s.height * 0.5);
    canvas.drawCircle(c, rect.width / 2,
        Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)]).createShader(rect));
  }

  @override
  bool shouldRepaint(_Rays old) => old.color != color;
}
