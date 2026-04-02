import 'package:flutter_test/flutter_test.dart';
import 'package:project_planner/core/models/firebase_runtime_config.dart';

void main() {
  test('validate reports required Firebase fields', () {
    const config = FirebaseRuntimeConfig(
      apiKey: '',
      appId: '',
      messagingSenderId: '',
      projectId: '',
      authDomain: '',
    );

    expect(config.validate(), hasLength(5));
  });

  test('json round-trip preserves configuration values', () {
    const config = FirebaseRuntimeConfig(
      apiKey: 'api-key',
      appId: 'app-id',
      messagingSenderId: 'sender-id',
      projectId: 'project-id',
      authDomain: 'project.firebaseapp.com',
      storageBucket: 'project.appspot.com',
    );

    final decoded = FirebaseRuntimeConfig.fromJson(config.toJson());

    expect(decoded.apiKey, config.apiKey);
    expect(decoded.storageBucket, config.storageBucket);
  });
}
