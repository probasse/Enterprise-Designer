import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/app_controller.dart';
import 'core/services/firebase_credentials_store.dart';
import 'core/services/local_config_store.dart';
import 'core/services/runtime_firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    localConfigStore: LocalConfigStore(),
    runtimeFirebaseService: RuntimeFirebaseService(),
    firebaseCredentialsStore: FirebaseCredentialsStore(),
  );
  await controller.bootstrap();

  runApp(ProjectPlannerApp(controller: controller));
}
