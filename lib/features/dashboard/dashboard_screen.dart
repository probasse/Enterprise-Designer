import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets/section_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final projects = controller.projects;
    final tasks = controller.tasks;
    final openTasks = tasks.where((t) => t.status != 'Completed').length;
    final completedTasks = tasks.where((t) => t.status == 'Completed').length;
    final blockedTasks = tasks.where((t) => t.status == 'Blocked').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 600;
        // Stat cards: fill row on narrow, fixed 200 on wide
        final statCardWidth = isNarrow ? (width - 18) / 2 : 200.0;
        // Content cards: full-width on narrow, split on wide
        final deadlinesWidth = isNarrow ? width : (width * 0.58).clamp(300.0, 640.0);
        final tipsWidth = isNarrow ? width : (width - deadlinesWidth - 18).clamp(200.0, 440.0);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Stay on top of project IDs, upcoming deadlines, and the current workflow status mix.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  _StatCard(
                      label: 'Projects',
                      value: '${projects.length}',
                      width: statCardWidth),
                  _StatCard(
                      label: 'Open tasks',
                      value: '$openTasks',
                      width: statCardWidth),
                  _StatCard(
                      label: 'Completed',
                      value: '$completedTasks',
                      width: statCardWidth),
                  _StatCard(
                      label: 'Blocked',
                      value: '$blockedTasks',
                      width: statCardWidth),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: deadlinesWidth,
                    child: SectionCard(
                      title: 'Upcoming deadlines',
                      subtitle:
                          'Your next due dates across every project, sorted soonest first.',
                      child: controller.upcomingTasks.isEmpty
                          ? const Text(
                              'No upcoming deadlines yet. Add a due date to any task.',
                            )
                          : Column(
                              children: controller.upcomingTasks
                                  .map(
                                    (task) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          '${task.taskCode} - ${task.title}'),
                                      subtitle: Text(
                                        '${controller.projectCode(task.projectId)} • ${task.status}',
                                      ),
                                      trailing: Text(
                                        task.dueDate == null
                                            ? 'No target date'
                                            : DateFormat('MMM d, HH:mm')
                                                .format(task.dueDate!),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                  ),
                  SizedBox(
                    width: tipsWidth,
                    child: SectionCard(
                      title: 'Planner tips',
                      subtitle:
                          'A few practices that help the richer workflow stay tidy.',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TipRow(
                              text:
                                  'Let project-specific statuses reflect real team flow.'),
                          _TipRow(
                              text:
                                  'Use Project Admin assignees to manage status changes.'),
                          _TipRow(
                              text:
                                  'Dependencies should stay acyclic to keep the schedule healthy.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.width});

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(value, style: Theme.of(context).textTheme.headlineLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.arrow_forward, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
