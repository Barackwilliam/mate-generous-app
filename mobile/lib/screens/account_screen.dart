import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Akaunti')),
      body: ListView(children: [
        if (app.isSignedIn)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(app.user?.fullName ?? ''),
            subtitle: Text([app.user?.email, app.user?.phone].whereType<String>().join(' · ')),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
              child: const Text('Ingia au jisajili'),
            ),
          ),
        const Divider(),
        const ListTile(title: Text('Mipangilio ya kusoma')),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Mwonekano'),
          trailing: DropdownButton<ThemeMode>(
            value: app.themeMode,
            underline: const SizedBox.shrink(),
            onChanged: (m) => app.setThemeMode(m!),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('Kama simu')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Mchana')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Usiku')),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.text_fields),
          title: const Text('Ukubwa wa maandishi'),
          subtitle: Slider(
            min: AppState.minFont,
            max: AppState.maxFont,
            divisions: 7,
            value: app.fontScale,
            onChanged: app.setFontScale,
          ),
        ),
        if (app.isSignedIn) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Toka'),
            onTap: app.signOut,
          ),
        ],
      ]),
    );
  }
}

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
  bool _hidePassword = true;
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
        await app.register(
            fullName: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), password: _password.text);
      } else {
        await app.login(_identifier.text.trim(), _password.text);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Tafadhali jaza hapa' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Jisajili' : 'Ingia')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          if (_register) ...[
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Jina kamili'),
              textCapitalization: TextCapitalization.words,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Barua pepe'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Weka barua pepe sahihi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Namba ya simu (hiari)', hintText: '0712 345 678'),
              keyboardType: TextInputType.phone,
            ),
          ] else
            TextFormField(
              controller: _identifier,
              decoration: const InputDecoration(labelText: 'Barua pepe au namba ya simu'),
              keyboardType: TextInputType.emailAddress,
              validator: _required,
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _hidePassword,
            decoration: InputDecoration(
              labelText: 'Nenosiri',
              helperText: _register ? 'Angalau herufi 8, isiwe namba tu' : null,
              suffixIcon: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Angalau herufi 8' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_register ? 'Jisajili' : 'Ingia'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _register = !_register;
              _error = null;
            }),
            child: Text(_register ? 'Tayari una akaunti? Ingia' : 'Huna akaunti? Jisajili'),
          ),
        ]),
      ),
    );
  }
}
