import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models/firebase_runtime_config.dart';
import '../../shared/widgets/section_card.dart';

class FirebaseSetupScreen extends StatefulWidget {
  const FirebaseSetupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<FirebaseSetupScreen> createState() => _FirebaseSetupScreenState();
}

class _FirebaseSetupScreenState extends State<FirebaseSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _appIdController = TextEditingController();
  final _messagingSenderIdController = TextEditingController();
  final _projectIdController = TextEditingController();
  final _authDomainController = TextEditingController();
  final _storageBucketController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    _appIdController.dispose();
    _messagingSenderIdController.dispose();
    _projectIdController.dispose();
    _authDomainController.dispose();
    _storageBucketController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E6D6), Color(0xFFE2F0EA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    final infoWidth = isWide
                        ? (constraints.maxWidth * 0.36).clamp(280.0, 440.0)
                        : constraints.maxWidth;
                    final formWidth = isWide
                        ? (constraints.maxWidth - infoWidth - 24)
                            .clamp(300.0, 700.0)
                        : constraints.maxWidth;

                    final infoCard = SizedBox(
                      width: infoWidth,
                      child: SectionCard(
                        title: 'Bring your own Firebase',
                        subtitle:
                            'Connect this planner to your Firebase Authentication and Cloud Firestore project without hardcoding credentials in the app.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Before you continue',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            const _ChecklistItem(
                                text:
                                    'Create a Firebase web app and copy its web config values.'),
                            const _ChecklistItem(
                                text:
                                    'Enable Email/Password under Authentication > Sign-in method.'),
                            const _ChecklistItem(
                                text:
                                    'Create a Cloud Firestore database and allow the signed-in user to read/write their own data.'),
                            const _ChecklistItem(
                                text:
                                    'Add your deployment domain to Authentication > Settings > Authorized domains.'),
                            const _ChecklistItem(
                                text:
                                    'Optional: add assets/firebase_credentials.js to the app bundle and it will connect automatically when the app starts.'),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Your Firebase config is stored in this browser using local storage unless the app bundle provides assets/firebase_credentials.js, which is used automatically on startup.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final formCard = SizedBox(
                      width: formWidth,
                      child: SectionCard(
                        title: 'Firebase web configuration',
                        subtitle:
                            'Paste the values from Firebase console > Project settings > Your apps > SDK setup and configuration.',
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildField(_apiKeyController, 'API key'),
                              const SizedBox(height: 14),
                              _buildField(_appIdController, 'App ID'),
                              const SizedBox(height: 14),
                              _buildField(_messagingSenderIdController,
                                  'Messaging sender ID'),
                              const SizedBox(height: 14),
                              _buildField(_projectIdController, 'Project ID'),
                              const SizedBox(height: 14),
                              _buildField(_authDomainController, 'Auth domain'),
                              const SizedBox(height: 14),
                              _buildField(
                                _storageBucketController,
                                'Storage bucket (optional)',
                                required: false,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: widget.controller.isBusy
                                      ? null
                                      : _saveConfig,
                                  child: Text(
                                    widget.controller.isBusy
                                        ? 'Connecting...'
                                        : 'Connect Firebase project',
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: (value) {
        if (!required) return null;
        if (value == null || value.trim().isEmpty) return '$label is required.';
        return null;
      },
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    final config = FirebaseRuntimeConfig(
      apiKey: _apiKeyController.text,
      appId: _appIdController.text,
      messagingSenderId: _messagingSenderIdController.text,
      projectId: _projectIdController.text,
      authDomain: _authDomainController.text,
      storageBucket: _storageBucketController.text.trim().isEmpty
          ? null
          : _storageBucketController.text,
    );
    await widget.controller.configureFirebase(config);
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
