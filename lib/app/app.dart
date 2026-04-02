import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models/app_view_state.dart';
import 'theme.dart';
import '../features/shell/app_shell.dart';

class ProjectPlannerApp extends StatelessWidget {
  const ProjectPlannerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Project Planner',
          debugShowCheckedModeBanner: false,
          theme: buildPlannerTheme(),
          home: _RootView(controller: controller),
        );
      },
    );
  }
}

class _RootView extends StatelessWidget {
  const _RootView({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final AppViewState state = controller.viewState;

    if (state.isBootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AppShell(controller: controller);
  }
}
