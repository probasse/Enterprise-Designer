import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/firebase_runtime_config.dart';

class LocalConfigStore {
  static const _configKey = 'firebase_runtime_config';

  Future<FirebaseRuntimeConfig?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final payload = preferences.getString(_configKey);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    return FirebaseRuntimeConfig.fromJson(decoded);
  }

  Future<void> save(FirebaseRuntimeConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_configKey);
  }
}
