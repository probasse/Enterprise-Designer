import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models/app_view_state.dart';
import '../../shared/widgets/feedback_banner.dart';
import '../assignees/assignees_screen.dart';
import '../auth/auth_screen.dart';
import '../calendar/calendar_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../projects/projects_screen.dart';
import '../setup/firebase_setup_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.viewState;

    if (!state.isFirebaseConfigured) {
      return FirebaseSetupScreen(controller: controller);
    }

    if (!state.isAuthenticated) {
      return AuthScreen(controller: controller);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 980;
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4EFE7), Color(0xFFE6F1EC)],
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (!isCompact)
                    _PlannerRail(
                      selectedTab: state.activeTab,
                      onSelected: controller.setActiveTab,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        FeedbackBanner(controller: controller),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: _BodySwitcher(controller: controller),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: isCompact
              ? NavigationBar(
                  selectedIndex: state.activeTab.index,
                  onDestinationSelected: (index) =>
                      controller.setActiveTab(ShellTab.values[index]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_open_outlined),
                      selectedIcon: Icon(Icons.folder_open),
                      label: 'Projects',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'Assignees',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

class _PlannerRail extends StatelessWidget {
  const _PlannerRail({required this.selectedTab, required this.onSelected});

  final ShellTab selectedTab;
  final ValueChanged<ShellTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Project Planner', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Organize projects, tasks, and due dates from your own Firebase project.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              for (final tab in ShellTab.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    selected: selectedTab == tab,
                    selectedTileColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    leading: Icon(_iconForTab(tab)),
                    title: Text(_labelForTab(tab)),
                    onTap: () => onSelected(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForTab(ShellTab tab) {
    switch (tab) {
      case ShellTab.dashboard:
        return Icons.space_dashboard_rounded;
      case ShellTab.projects:
        return Icons.folder_copy_rounded;
      case ShellTab.calendar:
        return Icons.calendar_month_rounded;
      case ShellTab.assignees:
        return Icons.people_rounded;
    }
  }

  String _labelForTab(ShellTab tab) {
    switch (tab) {
      case ShellTab.dashboard:
        return 'Dashboard';
      case ShellTab.projects:
        return 'Projects';
      case ShellTab.calendar:
        return 'Calendar';
      case ShellTab.assignees:
        return 'Assignees';
    }
  }
}

class _BodySwitcher extends StatelessWidget {
  const _BodySwitcher({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.viewState.activeTab) {
      case ShellTab.dashboard:
        return DashboardScreen(controller: controller);
      case ShellTab.projects:
        return ProjectsScreen(controller: controller);
      case ShellTab.calendar:
        return CalendarScreen(controller: controller);
      case ShellTab.assignees:
        return AssigneesScreen(controller: controller);
    }
  }
}
