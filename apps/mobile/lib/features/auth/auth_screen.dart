import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/supabase_config.dart';
import '../../core/theme/vytal_theme.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

/// Email/password account — required for server entitlements, sync, marketplace.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  var _mode = _AuthMode.signIn;
  var _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = ref.read(authControllerProvider);
      if (_mode == _AuthMode.signIn) {
        await auth.signIn(email: _email.text, password: _password.text);
        if (!mounted) return;
        Navigator.of(context).maybePop();
      } else {
        final res = await auth.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
        if (!mounted) return;
        if (res.session != null) {
          Navigator.of(context).maybePop();
        } else {
          setState(() {
            _info =
                'Check your email to confirm the account, then sign in.';
            _mode = _AuthMode.signIn;
          });
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final user = ref.watch(authUserProvider);

    return SectionScaffold(
      title: 'Account',
      subtitle: 'Server entitlements, sync, and marketplace require sign-in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null) ...[
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signed in', style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    user.email ?? user.id,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await ref.read(authControllerProvider).signOut();
                            if (mounted) setState(() => _busy = false);
                          },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ] else ...[
            GlassPanel(
              child: Text(
                'Pro / Complete grants and cloud sync only apply after the '
                'server verifies your session. Purchases still go through '
                'StoreKit / Play — this account binds them to you.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: extras.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_AuthMode>(
              segments: const [
                ButtonSegment(value: _AuthMode.signIn, label: Text('Sign in')),
                ButtonSegment(value: _AuthMode.signUp, label: Text('Create')),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            const SizedBox(height: 12),
            if (_mode == _AuthMode.signUp) ...[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.redAccent),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 8),
              Text(
                _info!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: extras.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Please wait…'
                    : _mode == _AuthMode.signIn
                        ? 'Sign in'
                        : 'Create account',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _AuthMode { signIn, signUp }
