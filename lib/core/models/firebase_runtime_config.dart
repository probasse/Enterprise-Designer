import 'package:firebase_core/firebase_core.dart';

class FirebaseRuntimeConfig {
  const FirebaseRuntimeConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.authDomain,
    this.storageBucket,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String authDomain;
  final String? storageBucket;

  Map<String, String> toJson() {
    return {
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'authDomain': authDomain,
      'storageBucket': storageBucket ?? '',
    };
  }

  factory FirebaseRuntimeConfig.fromJson(Map<String, Object?> json) {
    return FirebaseRuntimeConfig(
      apiKey: json['apiKey'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      messagingSenderId: json['messagingSenderId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      authDomain: json['authDomain'] as String? ?? '',
      storageBucket: (json['storageBucket'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['storageBucket'] as String).trim(),
    );
  }

  List<String> validate() {
    final issues = <String>[];
    if (apiKey.trim().isEmpty) {
      issues.add('API key is required.');
    }
    if (appId.trim().isEmpty) {
      issues.add('App ID is required.');
    }
    if (messagingSenderId.trim().isEmpty) {
      issues.add('Messaging sender ID is required.');
    }
    if (projectId.trim().isEmpty) {
      issues.add('Project ID is required.');
    }
    if (authDomain.trim().isEmpty) {
      issues.add('Auth domain is required.');
    }
    return issues;
  }

  FirebaseOptions toOptions() {
    return FirebaseOptions(
      apiKey: apiKey.trim(),
      appId: appId.trim(),
      messagingSenderId: messagingSenderId.trim(),
      projectId: projectId.trim(),
      authDomain: authDomain.trim(),
      storageBucket: storageBucket?.trim().isEmpty ?? true
          ? null
          : storageBucket!.trim(),
    );
  }
}
