import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets/section_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignInMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F1EC), Color(0xFFF7F1E8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final infoWidth = isWide
                        ? (constraints.maxWidth * 0.38).clamp(300.0, 440.0)
                        : constraints.maxWidth;
                    final formWidth = isWide
                        ? (constraints.maxWidth - infoWidth - 24)
                            .clamp(280.0, 540.0)
                        : constraints.maxWidth;

                    final infoCard = SizedBox(
                      width: infoWidth,
                      child: SectionCard(
                        title: 'Focused planning, your data',
                        subtitle:
                            'Use your own Firebase Authentication and Firestore project while keeping the workflow lightweight for teams of one.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('What you can do',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 14),
                            const _InfoRow(
                                text:
                                    'Track projects with color-coded status.'),
                            const _InfoRow(
                                text:
                                    'Manage tasks, priorities, and due dates.'),
                            const _InfoRow(
                                text:
                                    'See upcoming deadlines in a calendar-oriented view.'),
                            const SizedBox(height: 22),
                            OutlinedButton.icon(
                              onPressed: widget.controller.isBusy
                                  ? null
                                  : widget.controller.resetFirebase,
                              icon: const Icon(
                                  Icons.settings_backup_restore_rounded),
                              label: const Text('Reset Firebase connection'),
                            ),
                          ],
                        ),
                      ),
                    );

                    final formCard = SizedBox(
                      width: formWidth,
                      child: SectionCard(
                        title:
                            _isSignInMode ? 'Welcome back' : 'Create account',
                        subtitle:
                            'Email/password sign-in must be enabled in your Firebase project.',
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration:
                                  const InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Password'),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: widget.controller.isBusy
                                    ? null
                                    : _submit,
                                child: Text(
                                  widget.controller.isBusy
                                      ? 'Working...'
                                      : (_isSignInMode
                                          ? 'Sign in'
                                          : 'Create account'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: widget.controller.isBusy
                                        ? null
                                        : () => setState(() =>
                                            _isSignInMode = !_isSignInMode),
                                    child: Text(
                                      _isSignInMode
                                          ? 'Need an account? Sign up'
                                          : 'Already have an account? Sign in',
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: widget.controller.isBusy
                                      ? null
                                      : _resetPassword,
                                  child: const Text('Reset password'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    if (isWide) {
                      return SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            infoCard,
                            const SizedBox(width: 24),
                            formCard,
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          infoCard,
                          const SizedBox(height: 24),
                          formCard,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    if (_isSignInMode) {
      await widget.controller.signIn(email, password);
    } else {
      await widget.controller.signUp(email, password);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    await widget.controller.sendPasswordReset(email);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
