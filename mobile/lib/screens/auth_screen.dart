import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

/// Sign in and registration, as in the template.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startWithRegister = false});
  final bool startWithRegister;

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
  late bool _register = widget.startWithRegister;
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
    String? required(String? v) => (v == null || v.trim().isEmpty) ? s.required : null;
    return AuthFrame(
      title: _register ? s.createAccount : s.welcomeBang,
      subtitle: _register ? s.createAccountSub : s.signInToContinue,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_register) ...[
            WhiteField(controller: _name, hint: s.fullName, icon: Icons.person_outline_rounded, validator: required, capitalize: true),
            const SizedBox(height: 12),
            WhiteField(
              controller: _email,
              hint: s.email,
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? s.badEmail : null,
            ),
            const SizedBox(height: 12),
            WhiteField(controller: _phone, hint: s.phoneOptional, icon: Icons.phone_outlined, keyboard: TextInputType.phone),
          ] else
            WhiteField(controller: _identifier, hint: s.emailOrPhone, icon: Icons.person_outline_rounded, keyboard: TextInputType.emailAddress, validator: required),
          const SizedBox(height: 12),
          WhiteField(
            controller: _password,
            hint: s.password,
            icon: Icons.shield_outlined,
            obscure: _hide,
            onToggleObscure: () => setState(() => _hide = !_hide),
            toggleLabel: s.showPassword,
            validator: (v) => (v == null || v.length < 8) ? s.shortPassword : null,
            onSubmitted: (_) => _submit(),
          ),
          if (_register) ...[
            const SizedBox(height: 6),
            Text(s.passwordHelp, style: const TextStyle(fontSize: 12, color: Color(0xFFD5DAF5))),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 18),
          PrimaryButton(label: _register ? s.register : s.continueBtn, busy: _busy, onPressed: _submit),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Divider(color: Color(0x55FFFFFF))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s.or, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
            const Expanded(child: Divider(color: Color(0x55FFFFFF))),
          ]),
          const SizedBox(height: 12),
          SecondaryButton(solidWhite: true, label: s.continueAsGuest, onPressed: () => Navigator.maybePop(context)),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton(
              onPressed: () => setState(() {
                _register = !_register;
                _error = null;
              }),
              style: TextButton.styleFrom(foregroundColor: Palette.gold, minimumSize: const Size(44, 44)),
              child: Text(_register ? s.signIn : s.createAccountShort, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const Text('|', style: TextStyle(color: Colors.white54)),
            TextButton(
              onPressed: () => push(context, ForgotPasswordScreen(identifier: _identifier.text.trim())),
              style: TextButton.styleFrom(foregroundColor: Palette.gold, minimumSize: const Size(44, 44)),
              child: Text(s.forgotPassword, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Two steps: ask for a code by email, then enter the code and a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.identifier = ''});
  final String identifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.identifier);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_identifier, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    if (!_form.currentState!.validate()) return;
    final app = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_sent) {
        await app.api.forgotPassword(_identifier.text.trim());
        setState(() => _sent = true);
      } else {
        await app.resetPassword(_identifier.text.trim(), _code.text.trim(), _password.text);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on ApiException catch (e) {
      setState(() => _error = errorText(app.s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AuthFrame(
      title: s.resetTitle,
      subtitle: _sent ? s.codeSent : s.resetIntro,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WhiteField(
            controller: _identifier,
            hint: s.emailOrPhone,
            icon: Icons.person_outline_rounded,
            keyboard: TextInputType.emailAddress,
            enabled: !_sent,
            validator: (v) => (v == null || v.trim().isEmpty) ? s.required : null,
          ),
          if (_sent) ...[
            const SizedBox(height: 12),
            WhiteField(
              controller: _code,
              hint: s.code,
              icon: Icons.pin_outlined,
              keyboard: TextInputType.number,
              validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : s.sixDigits,
            ),
            const SizedBox(height: 12),
            WhiteField(
              controller: _password,
              hint: s.newPassword,
              icon: Icons.shield_outlined,
              obscure: _hide,
              onToggleObscure: () => setState(() => _hide = !_hide),
              toggleLabel: s.showPassword,
              validator: (v) => (v == null || v.length < 8) ? s.shortPassword : null,
            ),
            const SizedBox(height: 6),
            Text(s.passwordHelp, style: const TextStyle(fontSize: 12, color: Color(0xFFD5DAF5))),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 18),
          PrimaryButton(label: _sent ? s.setPassword : s.sendCode, busy: _busy, onPressed: _go),
          if (_sent)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _sent = false),
              style: TextButton.styleFrom(foregroundColor: Palette.gold, minimumSize: const Size(44, 44)),
              child: Text(s.sendCode, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}

/// The template's sign-in layout: picture with the cross and name on top,
/// then the form on night blue.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Theme(
      data: AppTheme.of(Palette.dark, Brightness.dark),
      child: Scaffold(
        backgroundColor: Palette.night,
        body: ListView(padding: EdgeInsets.zero, children: [
          SizedBox(
            height: 300,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(Img.loginBanner, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x330B1033), Color(0x000B1033), Color(0xFF0B1033)],
                    stops: [0.0, 0.45, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (Navigator.canPop(context))
                      RoundButton(icon: const Icon(Icons.close_rounded), label: s.close, onImage: true, onTap: () => Navigator.pop(context)),
                  ]),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Column(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset(Img.logo, width: 72, height: 72)),
                  const SizedBox(height: 8),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFF5A623)]).createShader(r),
                    child: const Text('KESHA LA USIKU',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: AppTheme.serif, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: Colors.white,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
                  ),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, color: Color(0xFFD5DAF5), height: 1.4)),
              const SizedBox(height: 20),
              child,
              const SizedBox(height: 18),
              const Center(child: LangToggle(small: true)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The template's white input with an icon.
class WhiteField extends StatelessWidget {
  const WhiteField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.validator,
    this.obscure = false,
    this.onToggleObscure,
    this.toggleLabel,
    this.onSubmitted,
    this.capitalize = false,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final FormFieldValidator<String>? validator;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? toggleLabel;
  final ValueChanged<String>? onSubmitted;
  final bool capitalize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1A1033);
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      obscureText: obscure,
      enabled: enabled,
      onFieldSubmitted: onSubmitted,
      textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.none,
      style: const TextStyle(color: ink, fontSize: 15.5, fontWeight: FontWeight.w600),
      cursorColor: ink,
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFE6E6F0),
        hintText: hint,
        labelText: null,
        hintStyle: const TextStyle(color: Color(0xFF5C5468), fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: ink),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                tooltip: toggleLabel,
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: ink),
                onPressed: onToggleObscure,
              ),
        errorStyle: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w600),
        border: border(Colors.white),
        enabledBorder: border(Colors.white),
        disabledBorder: border(const Color(0xFFE6E6F0)),
        focusedBorder: border(Palette.gold, 2),
        errorBorder: border(const Color(0xFFFF8A8A), 1.5),
        focusedErrorBorder: border(const Color(0xFFFF8A8A), 2),
      ),
    );
  }
}
