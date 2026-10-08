import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _server = TextEditingController(text: context.read<AppState>().server);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  late bool _showServer = _server.text.isEmpty;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().signIn(_server.text, _email.text, _password.text, name: _name.text, register: _register);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _showServer |= e.code == 'network');
        showMessage(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Constrained(
          maxWidth: 440,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                const SizedBox(height: 36),
                Center(child: Image.asset('assets/icon.png', width: 104, height: 104)),
                const SizedBox(height: 20),
                Text('Nestling', textAlign: TextAlign.center, style: t.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  _register ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: t.bodyLarge?.copyWith(color: Palette.muted),
                ),
                const SizedBox(height: 32),
                if (_showServer) ...[
                  TextFormField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'http://192.168.1.10:8080',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your Nestling server address' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_register) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => _register && (v ?? '').length < 8
                      ? 'At least 8 characters'
                      : (v ?? '').isEmpty
                      ? 'Enter your password'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(_register ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _register = !_register),
                  child: Text(_register ? 'I already have an account' : 'New here? Create an account'),
                ),
                if (!_showServer)
                  TextButton(
                    onPressed: () => setState(() => _showServer = true),
                    child: Text('Server: ${_server.text}', style: const TextStyle(color: Palette.muted)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
