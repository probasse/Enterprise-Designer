import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_planner/core/services/firebase_credentials_store.dart';

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('Unable to load asset: $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final asset = assets[key];
    if (asset == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return asset;
  }
}

void main() {
  test(
    'parses Firebase web snippet credentials from the bundled file',
    () async {
      const fileContents = '''
// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "api-key",
  authDomain: "example.firebaseapp.com",
  projectId: "example-project",
  storageBucket: "example-project.firebasestorage.app",
  messagingSenderId: "1234567890",
  appId: "1:1234567890:web:abcdef123456"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
''';

      final config = FirebaseRuntimeConfigParser.tryParse(fileContents);

      expect(config, isNotNull);
      expect(config!.apiKey, 'api-key');
      expect(config.projectId, 'example-project');
      expect(config.storageBucket, 'example-project.firebasestorage.app');
    },
  );

  test('loads Firebase credentials from the expected asset path', () async {
    final store = FirebaseCredentialsStore(
      bundle: _FakeAssetBundle({
        FirebaseCredentialsStore.assetPath: '''
const firebaseConfig = {
  apiKey: "api-key",
  authDomain: "example.firebaseapp.com",
  projectId: "example-project",
  messagingSenderId: "1234567890",
  appId: "1:1234567890:web:abcdef123456"
};
''',
      }),
    );

    final config = await store.load();

    expect(config, isNotNull);
    expect(config!.authDomain, 'example.firebaseapp.com');
  });
}
