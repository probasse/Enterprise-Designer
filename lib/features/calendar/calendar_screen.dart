import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets/gantt_chart_view.dart';
import '../../shared/widgets/section_card.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final projects = controller.projects
        .where(
          (project) =>
              project.startDate != null ||
              project.endDate != null ||
              project.phases.isNotEmpty,
        )
        .toList(growable: false);

    final entries = <GanttChartEntry>[
      for (final project in projects)
        GanttChartEntry(
          label: '${project.projectCode} - ${project.title}',
          subtitle: 'Project timeline',
          start: project.startDate,
          end: project.endDate,
          color: Color(project.colorValue),
        ),
      for (final project in projects)
        for (final phase in project.phases)
          GanttChartEntry(
            label: '  ${phase.name}',
            subtitle: '${project.projectCode} phase',
            start: phase.startDate,
            end: phase.endDate,
            color: Color(project.colorValue).withValues(alpha: 0.72),
          ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calendar', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'A Gantt-style overview of all visible project timelines and their phases.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (entries.isEmpty)
            const SectionCard(
              title: 'No project timelines',
              subtitle:
                  'Add project dates or phase windows to populate the overview.',
              child: Text(
                'This view focuses on project schedules rather than standalone task dates.',
              ),
            )
          else
            SectionCard(
              title: 'Portfolio Gantt View',
              subtitle:
                  'Projects and phases plotted across a shared schedule window.',
              child: GanttChartView(entries: entries),
            ),
        ],
      ),
    );
  }
}
