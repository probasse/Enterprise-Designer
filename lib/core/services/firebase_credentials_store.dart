import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/firebase_runtime_config.dart';
import 'runtime_firebase_service.dart';

class FirebaseCredentialsStore {
  FirebaseCredentialsStore({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/firebase_credentials.js';

  final AssetBundle _bundle;

  Future<FirebaseRuntimeConfig?> load() async {
    try {
      final payload = await _bundle.loadString(assetPath);
      final config = FirebaseRuntimeConfigParser.tryParse(payload);
      if (config == null) {
        throw FirebaseSetupException(
          'The Firebase credentials file was found, but it does not contain a valid Firebase web config.',
        );
      }
      return config;
    } on FlutterError {
      return null;
    }
  }
}

class FirebaseRuntimeConfigParser {
  static FirebaseRuntimeConfig? tryParse(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return null;
    }

    final jsonConfig = _tryParseJson(text);
    if (jsonConfig != null) {
      return jsonConfig;
    }

    return _tryParseFirebaseJsSnippet(text);
  }

  static FirebaseRuntimeConfig? _tryParseJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return FirebaseRuntimeConfig.fromJson(decoded);
      }
    } catch (_) {
      // Fall through to the Firebase web snippet parser.
    }
    return null;
  }

  static FirebaseRuntimeConfig? _tryParseFirebaseJsSnippet(String text) {
    final configAnchor = text.indexOf('firebaseConfig');
    final start = text.indexOf('{', configAnchor == -1 ? 0 : configAnchor);
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) {
      return null;
    }

    final objectBody = text.substring(start + 1, end);
    final values = <String, String>{};
    for (final line in objectBody.split('\n')) {
      final cleanedLine = line.trim().replaceFirst(RegExp(r',$'), '');
      if (cleanedLine.isEmpty || !cleanedLine.contains(':')) {
        continue;
      }

      final separatorIndex = cleanedLine.indexOf(':');
      final key = cleanedLine.substring(0, separatorIndex).trim();
      var value = cleanedLine.substring(separatorIndex + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }

    final requiredKeys = [
      'apiKey',
      'appId',
      'messagingSenderId',
      'projectId',
      'authDomain',
    ];
    if (requiredKeys.any((key) => (values[key] ?? '').trim().isEmpty)) {
      return null;
    }

    final storageBucket = values['storageBucket']?.trim();
    return FirebaseRuntimeConfig(
      apiKey: values['apiKey']!,
      appId: values['appId']!,
      messagingSenderId: values['messagingSenderId']!,
      projectId: values['projectId']!,
      authDomain: values['authDomain']!,
      storageBucket: storageBucket == null || storageBucket.isEmpty
          ? null
          : storageBucket,
    );
  }
}
