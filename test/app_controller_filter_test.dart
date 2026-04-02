import 'package:flutter_test/flutter_test.dart';
import 'package:project_planner/core/app_controller.dart';
import 'package:project_planner/core/models/task_filter.dart';
import 'package:project_planner/core/services/local_config_store.dart';
import 'package:project_planner/core/services/runtime_firebase_service.dart';

void main() {
  test('task filter upcomingOnly preserves future tasks', () {
    final controller = AppController(
      localConfigStore: LocalConfigStore(),
      runtimeFirebaseService: RuntimeFirebaseService(),
    );

    controller.setTaskFilter(const TaskFilter(upcomingOnly: true));

    expect(controller.taskFilter.upcomingOnly, isTrue);
  });
}
