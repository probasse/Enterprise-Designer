import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/firebase_runtime_config.dart';

class RuntimeFirebaseService {
  static const _appName = 'project-planner-runtime-app';

  FirebaseApp? _app;

  FirebaseApp? get app => _app;

  FirebaseAuth? get auth =>
      _app == null ? null : FirebaseAuth.instanceFor(app: _app!);

  FirebaseFirestore? get firestore =>
      _app == null ? null : FirebaseFirestore.instanceFor(app: _app!);

  Future<void> initialize(FirebaseRuntimeConfig config) async {
    final issues = config.validate();
    if (issues.isNotEmpty) {
      throw FirebaseSetupException(issues.join('\n'));
    }

    await _disposeCurrentApp();

    try {
      _app = await Firebase.initializeApp(
        name: _appName,
        options: config.toOptions(),
      );
    } on FirebaseException catch (error) {
      throw FirebaseSetupException(_friendlyMessage(error));
    } catch (error) {
      throw FirebaseSetupException(
        'Unable to initialize Firebase. Please confirm your web app settings and try again.',
      );
    }
  }

  Future<void> clear() async {
    await _disposeCurrentApp();
  }

  Future<void> _disposeCurrentApp() async {
    if (_app != null) {
      try {
        await auth?.signOut();
      } catch (_) {
        // Best effort sign-out before app teardown.
      }
      await _app!.delete();
      _app = null;
    } else {
      for (final app in Firebase.apps.where((item) => item.name == _appName)) {
        await app.delete();
      }
    }
  }

  String _friendlyMessage(FirebaseException error) {
    final code = error.code.toLowerCase();
    if (code.contains('invalid-api-key')) {
      return 'The API key looks invalid. Double-check the Firebase web config.';
    }
    if (code.contains('auth-domain-config-required')) {
      return 'Auth domain is required for web sign-in. Add the authDomain from your Firebase app settings.';
    }
    if (code.contains('project-not-found')) {
      return 'Firebase could not find that project. Verify the project ID and app configuration.';
    }
    return error.message ??
        'Firebase setup failed. Confirm your web app config and enabled Firebase services.';
  }
}

class FirebaseSetupException implements Exception {
  FirebaseSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}
