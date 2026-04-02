import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_controller.dart';
import '../../core/models/assignee_model.dart';
import '../../core/models/project_grant.dart';
import '../../core/models/project_model.dart';
import '../../core/models/task_model.dart';
import '../../shared/utils/comment_utils.dart';
import '../../shared/utils/table_column_prefs.dart';
import '../../shared/widgets/custom_data_table.dart';
import '../../shared/widgets/gantt_chart_view.dart';
import '../../shared/widgets/markdown_text.dart';
import '../../shared/widgets/section_card.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.controller});

  final AppController controller;

  static const _colors = [
    0xFF255F4A,
    0xFF4A7C59,
    0xFFD96C45,
    0xFF2E5BFF,
    0xFF6C4AB6,
    0xFFDAA520,
  ];

  static const _timezones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'UTC',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedProjectId = controller.viewState.selectedProjectId;
    if (selectedProjectId != null) {
      final selectedProject = controller.projectById(selectedProjectId);
      if (selectedProject != null) {
        return _ProjectWorkspaceView(
          controller: controller,
          project: selectedProject,
          onEditProject: () =>
              _openProjectEditor(context, project: selectedProject),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final colCount = screenWidth >= 760 ? 2 : 1;
        final projectCardWidth =
            (screenWidth - (colCount - 1) * 18) / colCount;

        return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Projects',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open a project to work through tasks, issues, risks, actions, decisions, kanban, and project calendar views.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: controller.canCreateProjects
                    ? () => _openProjectEditor(context)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('New project'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          controller.projects.isEmpty
              ? const SectionCard(
                  title: 'No projects yet',
                  subtitle: 'You only see projects you are assigned to.',
                  child: Text(
                    'A SuperAdmin creates projects first, then assigns one or more Project Admins as project owners.',
                  ),
                )
              : Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: controller.projects
                      .map(
                        (project) => SizedBox(
                          width: projectCardWidth,
                          child: _ProjectTile(
                            project: project,
                            taskCount: controller.tasks
                                .where((task) => task.projectId == project.id)
                                .length,
                            assigneeCount: controller
                                .assigneesForProject(project.id)
                                .length,
                            canEditProject: controller.canEditProject(
                              project.id,
                            ),
                            onOpenWorkspace: () =>
                                controller.openProjectDashboard(project.id),
                            onEdit: () =>
                                _openProjectEditor(context, project: project),
                            onDelete: () =>
                                controller.deleteProject(project.id),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ],
      ),
        );
      },
    );
  }

  Future<void> _openProjectEditor(
    BuildContext context, {
    ProjectModel? project,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return _ProjectEditorDialog(
          assignees: controller.assignees,
          initialProject: project,
          colors: _colors,
          timezones: _timezones,
          nextProjectCode: controller.previewNextProjectCode(),
          canManageStatuses: project == null
              ? controller.canCreateProjects
              : controller.canEditProject(project.id),
          isSuperAdmin: controller.isSuperAdmin,
          onSave:
              ({
                required title,
                required description,
                required colorValue,
                required timezone,
                required startDate,
                required endDate,
                required phases,
                required taskStatuses,
                required assignedAssigneeIds,
                required isConfidential,
                required grantsByAssigneeId,
                required actualStartStatus,
                required actualEndStatus,
                required actualStartResetStatus,
                required actualEndResetStatus,
                required allowSampleData,
                required workingDays,
                required workDayStartHour,
                required workDayEndHour,
                required publicHolidays,
              }) async {
                await controller.saveProject(
                  title: title,
                  description: description,
                  colorValue: colorValue,
                  timezone: timezone,
                  startDate: startDate,
                  endDate: endDate,
                  phases: phases,
                  taskStatuses: taskStatuses,
                  assignedAssigneeIds: assignedAssigneeIds,
                  isConfidential: isConfidential,
                  actualStartStatus: actualStartStatus,
                  actualEndStatus: actualEndStatus,
                  actualStartResetStatus: actualStartResetStatus,
                  actualEndResetStatus: actualEndResetStatus,
                  allowSampleData: allowSampleData,
                  workingDays: workingDays,
                  workDayStartHour: workDayStartHour,
                  workDayEndHour: workDayEndHour,
                  publicHolidays: publicHolidays,
                  projectId: project?.id,
                );
                if (project?.id != null) {
                  await controller.saveProjectGrants(
                    projectId: project!.id,
                    grantsByAssigneeId: grantsByAssigneeId,
                  );
                }
              },
        );
      },
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.taskCount,
    required this.assigneeCount,
    required this.canEditProject,
    required this.onOpenWorkspace,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectModel project;
  final int taskCount;
  final int assigneeCount;
  final bool canEditProject;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = Color(project.colorValue);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.folder_copy_rounded, color: accent),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpenWorkspace,
                    child: Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: accent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (project.isConfidential) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Confidential',
                    child: Icon(Icons.lock_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text('Project ID: ${project.projectCode}'),
            const SizedBox(height: 4),
            Text('Timezone: ${project.timezone}'),
            const SizedBox(height: 4),
            Text(
              'Window: ${_formatDate(project.startDate)} to ${_formatDate(project.endDate)}',
            ),
            const SizedBox(height: 10),
            Text(project.description),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('$taskCount tasks')),
                Chip(label: Text('$assigneeCount assignees')),
                Chip(label: Text('${project.issueLog.length} issues')),
                Chip(label: Text('${project.riskLog.length} risks')),
                Chip(label: Text('${project.actionLog.length} actions')),
                Chip(label: Text('${project.decisionLog.length} decisions')),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                ElevatedButton(
                  onPressed: onOpenWorkspace,
                  child: const Text('Open project'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: canEditProject ? onEdit : null,
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: canEditProject ? onDelete : null,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProjectWorkspaceTab {
  overview,
  tasks,
  issues,
  risks,
  actions,
  decisions,
  kanban,
  calendar,
}

class _ProjectWorkspaceView extends StatefulWidget {
  const _ProjectWorkspaceView({
    required this.controller,
    required this.project,
    required this.onEditProject,
  });

  final AppController controller;
  final ProjectModel project;
  final VoidCallback onEditProject;

  @override
  State<_ProjectWorkspaceView> createState() => _ProjectWorkspaceViewState();
}

class _ProjectWorkspaceViewState extends State<_ProjectWorkspaceView> {
  _ProjectWorkspaceTab _activeTab = _ProjectWorkspaceTab.overview;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final project = controller.projectById(widget.project.id) ?? widget.project;
    final projectTasks =
        controller.tasks
            .where((task) => task.projectId == project.id)
            .toList(growable: false)
          ..sort((left, right) {
            final leftDate = left.dueDate ?? DateTime(2100);
            final rightDate = right.dueDate ?? DateTime(2100);
            return leftDate.compareTo(rightDate);
          });
    final projectAssignees = controller.assigneesForProject(project.id);
    final canEdit = controller.canManageProjectWork(project.id);

    Future<void> openTaskEditor({TaskModel? task}) {
      final latestProject = controller.projectById(project.id) ?? project;
      return showDialog<void>(
        context: context,
        builder: (dialogContext) => _ProjectTaskEditorDialog(
          controller: controller,
          project: latestProject,
          assignees: controller.assigneesForProject(latestProject.id),
          allTasks: controller.tasks
              .where((item) => item.projectId == latestProject.id)
              .toList(growable: false),
          initialTask: task,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: controller.closeProjectDashboard,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${project.projectCode} Workspace',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ),
                        if (project.isConfidential) ...[
                          const SizedBox(width: 8),
                          Chip(
                            avatar: Icon(
                              Icons.lock_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            label: Text(
                              'Confidential',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .errorContainer
                                .withValues(alpha: 0.3),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              if (canEdit) ...[
                if (_activeTab == _ProjectWorkspaceTab.overview)
                  OutlinedButton.icon(
                    onPressed: widget.onEditProject,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit project'),
                  ),
                const SizedBox(width: 8),
                if (project.allowSampleData)
                  OutlinedButton.icon(
                    onPressed: () => controller.generateSampleData(project.id),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Generate sample data'),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _ProjectWorkspaceTab.values
                .map(
                  (tab) => ChoiceChip(
                    selected: _activeTab == tab,
                    label: Text(_tabLabel(tab)),
                    onSelected: (_) => setState(() => _activeTab = tab),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 20),
          switch (_activeTab) {
            _ProjectWorkspaceTab.overview => _ProjectOverviewTab(
              controller: controller,
              project: project,
              projectTasks: projectTasks,
              projectAssignees: projectAssignees,
            ),
            _ProjectWorkspaceTab.tasks => _ProjectTasksTab(
              controller: controller,
              project: project,
              tasks: projectTasks,
              assignees: projectAssignees,
              canEdit: canEdit,
              onAddTask: () => openTaskEditor(),
            ),
            _ProjectWorkspaceTab.issues => _ProjectRecordTab(
              controller: controller,
              project: project,
              type: ProjectRecordType.issue,
              entries: project.issueLog,
              assignees: projectAssignees,
              canEdit: controller.canManageProjectRecords(
                  project.id, ProjectRecordType.issue),
            ),
            _ProjectWorkspaceTab.risks => _ProjectRecordTab(
              controller: controller,
              project: project,
              type: ProjectRecordType.risk,
              entries: project.riskLog,
              assignees: projectAssignees,
              canEdit: controller.canManageProjectRecords(
                  project.id, ProjectRecordType.risk),
            ),
            _ProjectWorkspaceTab.actions => _ProjectRecordTab(
              controller: controller,
              project: project,
              type: ProjectRecordType.action,
              entries: project.actionLog,
              assignees: projectAssignees,
              canEdit: controller.canManageProjectRecords(
                  project.id, ProjectRecordType.action),
            ),
            _ProjectWorkspaceTab.decisions => _ProjectRecordTab(
              controller: controller,
              project: project,
              type: ProjectRecordType.decision,
              entries: project.decisionLog,
              assignees: projectAssignees,
              canEdit: controller.canManageProjectRecords(
                  project.id, ProjectRecordType.decision),
            ),
            _ProjectWorkspaceTab.kanban => _ProjectKanbanTab(
              controller: controller,
              project: project,
              tasks: projectTasks,
              canEdit: canEdit,
              onStatusChanged: (task, newStatus) {
                final now = DateTime.now();
                return controller.saveTask(
                  taskId: task.id,
                  projectId: task.projectId,
                  title: task.title,
                  notes: task.notes,
                  status: newStatus,
                  priority: task.priority,
                  isMilestone: task.isMilestone,
                  startDate: task.startDate,
                  duration: task.duration,
                  dueDate: task.dueDate,
                  predecessorTaskCodes: task.predecessorTaskCodes,
                  phaseId: task.phaseId,
                  assigneeId: task.assigneeId,
                  actualStartDate: newStatus == project.actualStartStatus
                      ? now
                      : newStatus == project.actualStartResetStatus
                          ? null
                          : task.actualStartDate,
                  actualEndDate: newStatus == project.actualEndStatus
                      ? now
                      : newStatus == project.actualEndResetStatus
                          ? null
                          : task.actualEndDate,
                );
              },
            ),
            _ProjectWorkspaceTab.calendar => _ProjectCalendarTab(
              controller: controller,
              project: project,
              tasks: projectTasks,
            ),
          },
        ],
      ),
    );
  }
}

class _ProjectOverviewTab extends StatelessWidget {
  const _ProjectOverviewTab({
    required this.controller,
    required this.project,
    required this.projectTasks,
    required this.projectAssignees,
  });

  final AppController controller;
  final ProjectModel project;
  final List<TaskModel> projectTasks;
  final List<AssigneeModel> projectAssignees;

  @override
  Widget build(BuildContext context) {
    final canEdit = controller.canManageProjectWork(project.id);
    final upcomingTasks = projectTasks
        .where((task) => task.dueDate != null)
        .take(6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(label: 'Tasks', value: '${projectTasks.length}'),
            _StatCard(label: 'Issues', value: '${project.issueLog.length}'),
            _StatCard(label: 'Risks', value: '${project.riskLog.length}'),
            _StatCard(label: 'Actions', value: '${project.actionLog.length}'),
            _StatCard(
              label: 'Decisions',
              value: '${project.decisionLog.length}',
            ),
            _StatCard(label: 'Team', value: '${projectAssignees.length}'),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            final cardWidth = isWide
                ? (constraints.maxWidth - 18) / 2
                : constraints.maxWidth;
            return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            SizedBox(
              width: cardWidth,
              child: SectionCard(
                title: 'Project Snapshot',
                subtitle:
                    'Schedule, timezone, and workflow settings for this project.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Timezone: ${project.timezone}'),
                    const SizedBox(height: 8),
                    Text(
                      'Window: ${_formatDate(project.startDate)} to ${_formatDate(project.endDate)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Project owner: ${project.ownerEmail.ifEmpty('Not set')}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Phases',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (project.phases.isEmpty)
                      const Text('No phases configured yet.')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: project.phases
                            .map(
                              (phase) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${phase.name} • ${_formatDate(phase.startDate)} to ${_formatDate(phase.endDate)}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Task statuses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: project.taskStatuses
                          .map((status) => Chip(label: Text(status)))
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SectionCard(
                title: 'Upcoming Tasks',
                subtitle: 'The next dated tasks inside this project.',
                child: upcomingTasks.isEmpty
                    ? const Text('No dated tasks yet.')
                    : Column(
                        children: upcomingTasks
                            .map(
                              (task) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${task.taskCode} - ${task.title}'),
                                subtitle: Text(task.status),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_formatDate(task.dueDate)),
                                    const SizedBox(width: 4),
                                    Icon(
                                      canEdit
                                          ? Icons.edit_outlined
                                          : Icons.visibility_outlined,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                  ],
                                ),
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (_) => _ProjectTaskEditorDialog(
                                    controller: controller,
                                    project: project,
                                    assignees: projectAssignees,
                                    allTasks: projectTasks,
                                    initialTask: task,
                                    readOnly: !canEdit,
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ),
          ],
            );
          },
        ),
      ],
    );
  }
}

class _ProjectTasksTab extends StatefulWidget {
  const _ProjectTasksTab({
    required this.controller,
    required this.project,
    required this.tasks,
    required this.assignees,
    required this.canEdit,
    required this.onAddTask,
  });

  final AppController controller;
  final ProjectModel project;
  final List<TaskModel> tasks;
  final List<AssigneeModel> assignees;
  final bool canEdit;
  final VoidCallback onAddTask;

  @override
  State<_ProjectTasksTab> createState() => _ProjectTasksTabState();
}

class _ProjectTasksTabState extends State<_ProjectTasksTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredTasks = widget.tasks
        .where((task) {
          if (searchQuery.isEmpty) return true;
          return task.taskCode.toLowerCase().contains(searchQuery) ||
              task.title.toLowerCase().contains(searchQuery) ||
              task.notes.toLowerCase().contains(searchQuery);
        })
        .toList(growable: false);

    return SectionCard(
      title: 'Project Tasks',
      subtitle:
          'Manage the tasks that belong only to this project. Click column headers to sort or filter.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (widget.canEdit)
                ElevatedButton.icon(
                  onPressed: widget.onAddTask,
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Add task'),
                ),
              OutlinedButton.icon(
                onPressed: () => widget.controller.exportTasksToCsv(
                  projectId: widget.project.id,
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download CSV'),
              ),
              if (widget.canEdit)
                OutlinedButton.icon(
                  onPressed: () => widget.controller.importTasksFromCsv(
                    projectId: widget.project.id,
                  ),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload CSV'),
                ),
            ],
          ),
          if (widget.tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search tasks',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.tasks.isEmpty)
            const Text('No tasks in this project yet.')
          else if (filteredTasks.isEmpty)
            const Text('No tasks match the current search.')
          else
            _TaskTable(
              tasks: filteredTasks,
              controller: controller,
              project: widget.project,
              assignees: widget.assignees,
              canEdit: widget.canEdit,
              onDelete: (task) => widget.controller.deleteTask(task.id),
            ),
        ],
      ),
    );
  }
}

// ── Task table ─────────────────────────────────────────────────────────────

class _TaskTable extends StatefulWidget {
  const _TaskTable({
    required this.tasks,
    required this.controller,
    required this.project,
    required this.assignees,
    required this.canEdit,
    required this.onDelete,
  });

  final List<TaskModel> tasks;
  final AppController controller;
  final ProjectModel project;
  final List<AssigneeModel> assignees;
  final bool canEdit;
  final void Function(TaskModel) onDelete;

  @override
  State<_TaskTable> createState() => _TaskTableState();
}

class _TaskTableState extends State<_TaskTable> {
  // ── Column definitions ────────────────────────────────────────────────────
  static const _taskColDefs = [
    TableColDef(id: 'priority',     label: '',             width: 32,  sortable: false, canHide: false, canReorder: false),
    TableColDef(id: 'id',           label: 'ID',           width: 80),
    TableColDef(id: 'title',        label: 'Title',        width: 200, canHide: false),
    TableColDef(id: 'status',       label: 'Status',       width: 130),
    TableColDef(id: 'phase',        label: 'Phase',        width: 120),
    TableColDef(id: 'assignee',     label: 'Assignee',     width: 130),
    TableColDef(id: 'startDate',    label: 'Start Date',   width: 110),
    TableColDef(id: 'duration',     label: 'Duration',     width: 90,  sortable: false),
    TableColDef(id: 'endDate',      label: 'End Date',        width: 110, sortable: false),
    TableColDef(id: 'dueDate',      label: 'Target Date',     width: 110),
    TableColDef(id: 'milestone',    label: 'Milestone',       width: 90),
    TableColDef(id: 'predecessors', label: 'Predecessors',    width: 160, sortable: false),
    TableColDef(id: 'updatedAt',    label: 'Last Updated',    width: 140),
    TableColDef(id: 'actualStartDate', label: 'Actual Start', width: 150),
    TableColDef(id: 'actualEndDate',   label: 'Actual End',   width: 150),
  ];

  static List<String> get _defaultColOrder =>
      _taskColDefs.map((c) => c.id).toList(growable: false);

  // ── Sort / filter state ───────────────────────────────────────────────────
  String? _sortColId;
  bool _sortAscending = true;
  String? _filterStatus;
  String? _filterPhase;
  String? _filterAssignee;

  // ── Column pref state ─────────────────────────────────────────────────────
  List<String> _colOrder = _defaultColOrder;
  Set<String> _hiddenCols = {};
  Map<String, double> _colWidths = {};
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await TableColPrefs.load('tasks', _defaultColOrder);
    if (mounted) {
      setState(() {
        _colOrder = prefs.order;
        _hiddenCols = prefs.hidden;
        _colWidths = prefs.widths;
        _prefsLoaded = true;
      });
    }
  }

  Future<void> _savePrefs() async {
    await TableColPrefs.save(
        'tasks', TableColPrefs(order: _colOrder, hidden: _hiddenCols, widths: _colWidths));
  }

  void _onResized(String colId, double newWidth) {
    setState(() => _colWidths = {..._colWidths, colId: newWidth});
    _savePrefs();
  }

  void _onReorder(String fromId, String toId) {
    final from = _colOrder.indexOf(fromId);
    final to = _colOrder.indexOf(toId);
    if (from == -1 || to == -1 || from == to) return;
    setState(() {
      _colOrder.removeAt(from);
      _colOrder.insert(to, fromId);
    });
    _savePrefs();
  }

  void _onSort(String colId) {
    setState(() {
      if (_sortColId == colId) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColId = colId;
        _sortAscending = true;
      }
    });
  }

  void _toggleHide(String colId) {
    setState(() {
      if (_hiddenCols.contains(colId)) {
        _hiddenCols = {..._hiddenCols}..remove(colId);
      } else {
        _hiddenCols = {..._hiddenCols, colId};
      }
    });
    _savePrefs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Sort / filter helpers ─────────────────────────────────────────────────

  List<TaskModel> _sorted(List<TaskModel> source) {
    final id = _sortColId;
    if (id == null) return source;
    final result = List<TaskModel>.from(source);
    result.sort((a, b) {
      int cmp;
      switch (id) {
        case 'id':
          cmp = a.taskCode.compareTo(b.taskCode);
        case 'title':
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'status':
          cmp = a.status.toLowerCase().compareTo(b.status.toLowerCase());
        case 'phase':
          cmp = widget.controller
              .phaseName(widget.project.id, a.phaseId)
              .toLowerCase()
              .compareTo(widget.controller
                  .phaseName(widget.project.id, b.phaseId)
                  .toLowerCase());
        case 'assignee':
          cmp = widget.controller
              .assigneeName(a.assigneeId)
              .toLowerCase()
              .compareTo(widget.controller
                  .assigneeName(b.assigneeId)
                  .toLowerCase());
        case 'startDate':
          cmp = (a.startDate ?? DateTime(2100))
              .compareTo(b.startDate ?? DateTime(2100));
        case 'dueDate':
          cmp = (a.dueDate ?? DateTime(2100))
              .compareTo(b.dueDate ?? DateTime(2100));
        case 'actualStartDate':
          cmp = (a.actualStartDate ?? DateTime(2100))
              .compareTo(b.actualStartDate ?? DateTime(2100));
        case 'actualEndDate':
          cmp = (a.actualEndDate ?? DateTime(2100))
              .compareTo(b.actualEndDate ?? DateTime(2100));
        case 'milestone':
          cmp = (a.isMilestone ? 1 : 0).compareTo(b.isMilestone ? 1 : 0);
        case 'updatedAt':
          cmp = a.updatedAt.compareTo(b.updatedAt);
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return result;
  }

  List<TaskModel> _filtered(List<TaskModel> source) {
    return source.where((t) {
      if (_filterStatus != null && t.status != _filterStatus) return false;
      if (_filterPhase != null && t.phaseId != _filterPhase) return false;
      if (_filterAssignee != null && t.assigneeId != _filterAssignee) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  // ── Visible columns ───────────────────────────────────────────────────────

  static const _actionsColDef = TableColDef(
    id: 'actions', label: '', width: 56,
    sortable: false, canHide: false, canReorder: false,
  );

  List<TableColDef> _visibleCols() {
    final byId = {for (final c in _taskColDefs) c.id: c};
    final cols = _colOrder
        .where((id) => !_hiddenCols.contains(id))
        .map((id) {
          final col = byId[id];
          if (col == null) return null;
          final w = _colWidths[id];
          return w != null ? col.withWidth(w) : col;
        })
        .whereType<TableColDef>()
        .toList();
    if (widget.canEdit) cols.add(_actionsColDef);
    return cols;
  }

  // ── Cell builders ─────────────────────────────────────────────────────────

  Widget _cellFor(String colId, TaskModel task, BuildContext context) {
    final theme = Theme.of(context);
    switch (colId) {
      case 'priority':
        return Tooltip(
          message: task.priority.name.toUpperCase(),
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: _priorityColor(task.priority),
              shape: BoxShape.circle,
            ),
          ),
        );
      case 'id':
        return Text(task.taskCode,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600));
      case 'title':
        return SizedBox(
          width: 176,
          child: Tooltip(
            message: task.notes.isEmpty ? task.title : task.notes,
            child: Row(children: [
              if (task.isMilestone)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.flag_rounded,
                      size: 14, color: Color(0xFFD96C45)),
                ),
              Expanded(
                child: Text(task.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        );
      case 'status':
        return _statusCell(context, task);
      case 'phase':
        return _phaseCell(context, task);
      case 'assignee':
        return _assigneeCell(context, task);
      case 'startDate':
        return _startDateCell(context, task);
      case 'duration':
        return _durationCell(context, task);
      case 'endDate':
        return Text(
          _formatDateTime(task.endDate),
          style: theme.textTheme.bodySmall,
        );
      case 'dueDate':
        return _dueDateCell(context, task);
      case 'milestone':
        if (!widget.canEdit) {
          return task.isMilestone
              ? Icon(Icons.check_rounded,
                  size: 18, color: theme.colorScheme.primary)
              : const SizedBox.shrink();
        }
        return Tooltip(
          message: task.isMilestone ? 'Milestone — tap to unset' : 'Tap to mark as milestone',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _saveField(task, isMilestone: !task.isMilestone),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(
                task.isMilestone ? Icons.flag_rounded : Icons.flag_outlined,
                size: 18,
                color: task.isMilestone
                    ? const Color(0xFFD96C45)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      case 'predecessors':
        return _predecessorsCell(context, task);
      case 'updatedAt':
        return Text(
          DateFormat('MMM d, yyyy HH:mm').format(task.updatedAt),
          style: theme.textTheme.bodySmall,
        );
      case 'actualStartDate':
        return Text(
          task.actualStartDate == null
              ? '—'
              : DateFormat('MMM d, yyyy HH:mm').format(task.actualStartDate!),
          style: theme.textTheme.bodySmall,
        );
      case 'actualEndDate':
        return Text(
          task.actualEndDate == null
              ? '—'
              : DateFormat('MMM d, yyyy HH:mm').format(task.actualEndDate!),
          style: theme.textTheme.bodySmall,
        );
      case 'actions':
        return IconButton(
          tooltip: 'Delete task',
          icon: Icon(Icons.delete_outline_rounded,
              size: 18, color: theme.colorScheme.error),
          onPressed: () => widget.onDelete(task),
          visualDensity: VisualDensity.compact,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final displayTasks = _sorted(_filtered(widget.tasks));
    final visibleCols = _visibleCols();
    final hideable = _taskColDefs.where((c) => c.canHide).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toolbar: filters + column visibility ────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              // Status filter
              _filterChip(context, 'Status',
                  _filterStatus ?? 'All statuses', Icons.tune_rounded, () async {
                final v = await _showStringPicker(
                    context,
                    'Filter by Status',
                    [null, ...widget.project.taskStatuses],
                    _filterStatus);
                if (v != null || mounted) {
                  setState(() => _filterStatus = v == '' ? null : v);
                }
              }),
              // Phase filter
              _filterChip(context, 'Phase',
                  _filterPhase == null
                      ? 'All phases'
                      : widget.controller
                          .phaseName(widget.project.id, _filterPhase),
                  Icons.tune_rounded, () async {
                final phases = [null, ...widget.project.phases.map((p) => p.id)];
                final v = await _showStringPicker(
                    context,
                    'Filter by Phase',
                    phases,
                    _filterPhase,
                    labelFor: (id) => id == null
                        ? 'All phases'
                        : widget.controller
                            .phaseName(widget.project.id, id));
                if (v != null || mounted) {
                  setState(() => _filterPhase = v == '' ? null : v);
                }
              }),
              // Assignee filter
              _filterChip(context, 'Assignee',
                  _filterAssignee == null
                      ? 'All assignees'
                      : widget.controller.assigneeName(_filterAssignee),
                  Icons.tune_rounded, () async {
                final ids = [null, ...widget.assignees.map((a) => a.id)];
                final v = await _showStringPicker(
                    context,
                    'Filter by Assignee',
                    ids,
                    _filterAssignee,
                    labelFor: (id) => id == null
                        ? 'All assignees'
                        : widget.controller.assigneeName(id));
                if (v != null || mounted) {
                  setState(() => _filterAssignee = v == '' ? null : v);
                }
              }),
              // Column visibility button
              _colVisButton(context, hideable, theme),
              // Auto column width button
              IconButton(
                tooltip: 'Reset column widths',
                icon: const Icon(Icons.fit_screen_rounded, size: 20),
                onPressed: () {
                  setState(() => _colWidths = {});
                  _savePrefs();
                },
              ),
            ],
          ),
        ),
        // ── Table ───────────────────────────────────────────────────────────
        CustomDataTable(
          columns: visibleCols,
          sortColId: _sortColId,
          sortAscending: _sortAscending,
          onSort: _onSort,
          onReorder: _onReorder,
          onResized: _onResized,
          pinnedLeadingCount: 0,
          pinnedTrailingCount: widget.canEdit ? 1 : 0,
          rows: [
            for (final task in displayTasks)
              [for (final col in visibleCols) _cellFor(col.id, task, context)],
          ],
          rowColor: (i) {
            final task = displayTasks[i];
            return task.isOverdue
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.25)
                : null;
          },
        ),
      ],
    );
  }

  // ── Filter chip helper ────────────────────────────────────────────────────

  Widget _filterChip(BuildContext context, String label, String value,
      IconData icon, VoidCallback onTap) {
    final active = !value.startsWith('All');
    return ActionChip(
      avatar: Icon(icon, size: 14),
      label: Text(value, overflow: TextOverflow.ellipsis),
      backgroundColor: active
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      onPressed: onTap,
    );
  }

  // ── Column visibility button ──────────────────────────────────────────────

  Widget _colVisButton(BuildContext context, List<TableColDef> hideable,
      ThemeData theme) {
    return PopupMenuButton<String>(
      tooltip: 'Show/hide columns',
      icon: const Icon(Icons.view_column_outlined),
      itemBuilder: (_) => hideable
          .map(
            (col) => CheckedPopupMenuItem<String>(
              value: col.id,
              checked: !_hiddenCols.contains(col.id),
              child: Text(col.label),
            ),
          )
          .toList(growable: false),
      onSelected: _toggleHide,
    );
  }

  // ── String picker dialog ──────────────────────────────────────────────────

  Future<String?> _showStringPicker(
    BuildContext context,
    String title,
    List<String?> options,
    String? current, {
    String Function(String?)? labelFor,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: options
            .map((v) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(v ?? ''),
                  child: Text(labelFor?.call(v) ??
                      (v == null ? 'All' : v)),
                ))
            .toList(),
      ),
    );
  }

  // ── Actual date auto-timestamp helper ────────────────────────────────────

  ({DateTime? actualStart, DateTime? actualEnd, bool clearActualStart, bool clearActualEnd}) _resolveActualDates({
    required TaskModel existing,
    required String newStatus,
  }) {
    final project = widget.project;
    final now = DateTime.now();
    final DateTime? resolvedStart;
    final bool clearStart;
    if (newStatus == project.actualStartStatus) {
      resolvedStart = now;
      clearStart = false;
    } else if (newStatus == project.actualStartResetStatus) {
      resolvedStart = null;
      clearStart = true;
    } else {
      resolvedStart = existing.actualStartDate;
      clearStart = false;
    }
    final DateTime? resolvedEnd;
    final bool clearEnd;
    if (newStatus == project.actualEndStatus) {
      resolvedEnd = now;
      clearEnd = false;
    } else if (newStatus == project.actualEndResetStatus) {
      resolvedEnd = null;
      clearEnd = true;
    } else {
      resolvedEnd = existing.actualEndDate;
      clearEnd = false;
    }
    return (
      actualStart: resolvedStart,
      actualEnd: resolvedEnd,
      clearActualStart: clearStart,
      clearActualEnd: clearEnd,
    );
  }

  // ── Field save helper ─────────────────────────────────────────────────────

  Future<void> _saveField(
    TaskModel task, {
    String? status,
    String? phaseId,
    bool clearPhaseId = false,
    String? assigneeId,
    bool clearAssigneeId = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? startDate,
    bool clearStartDate = false,
    String? duration,
    List<String>? predecessorTaskCodes,
    bool? isMilestone,
  }) async {
    final newStatus = status ?? task.status;
    final (:actualStart, :actualEnd, :clearActualStart, :clearActualEnd) =
        _resolveActualDates(existing: task, newStatus: newStatus);
    await widget.controller.saveTask(
      taskId: task.id,
      projectId: task.projectId,
      title: task.title,
      notes: task.notes,
      status: newStatus,
      priority: task.priority,
      isMilestone: isMilestone ?? task.isMilestone,
      startDate: clearStartDate ? null : startDate ?? task.startDate,
      duration: duration ?? task.duration,
      dueDate: clearDueDate ? null : dueDate ?? task.dueDate,
      predecessorTaskCodes: predecessorTaskCodes ?? task.predecessorTaskCodes,
      phaseId: clearPhaseId ? null : phaseId ?? task.phaseId,
      assigneeId: clearAssigneeId ? null : assigneeId ?? task.assigneeId,
      actualStartDate: clearActualStart ? null : actualStart,
      actualEndDate: clearActualEnd ? null : actualEnd,
    );
  }

  // ── Inline edit cell helpers ──────────────────────────────────────────────

  Widget _statusCell(BuildContext context, TaskModel task) {
    if (!widget.canEdit) {
      return Chip(
        label: Text(task.status, style: Theme.of(context).textTheme.labelSmall),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      );
    }
    return DropdownButton<String>(
      value: widget.project.taskStatuses.contains(task.status)
          ? task.status
          : widget.project.taskStatuses.first,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: widget.project.taskStatuses
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (value) {
        if (value != null && value != task.status) _saveField(task, status: value);
      },
    );
  }

  Widget _phaseCell(BuildContext context, TaskModel task) {
    final phaseName =
        widget.controller.phaseName(widget.project.id, task.phaseId);
    if (!widget.canEdit) {
      return Text(phaseName, style: Theme.of(context).textTheme.bodySmall);
    }
    return DropdownButton<String?>(
      value: task.phaseId,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        ...widget.project.phases.map((p) =>
            DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
      ],
      onChanged: (value) {
        if (value != task.phaseId) {
          _saveField(task, phaseId: value, clearPhaseId: value == null);
        }
      },
    );
  }

  Widget _assigneeCell(BuildContext context, TaskModel task) {
    final theme = Theme.of(context);
    final name = widget.controller.assigneeName(task.assigneeId);
    // Check OOO for this task's assignee
    final assignee = task.assigneeId == null
        ? null
        : widget.assignees.cast<AssigneeModel?>().firstWhere(
            (a) => a?.id == task.assigneeId,
            orElse: () => null,
          );
    final isOoo = assignee != null && _isAssigneeOoo(task, assignee);
    if (!widget.canEdit) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: theme.textTheme.bodySmall),
          if (isOoo) ...[
            const SizedBox(width: 6),
            Chip(
              label: const Text('OOO'),
              backgroundColor:
                  theme.colorScheme.errorContainer.withValues(alpha: 0.6),
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: DropdownButton<String?>(
            value: task.assigneeId,
            isDense: true,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
              ...widget.assignees.map((a) =>
                  DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
            ],
            onChanged: (value) {
              if (value != task.assigneeId) {
                _saveField(task, assigneeId: value, clearAssigneeId: value == null);
              }
            },
          ),
        ),
        if (isOoo) ...[
          const SizedBox(width: 6),
          Chip(
            label: const Text('OOO'),
            backgroundColor:
                theme.colorScheme.errorContainer.withValues(alpha: 0.6),
            labelStyle: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  bool _isAssigneeOoo(TaskModel task, AssigneeModel assignee) {
    if (assignee.oooRanges.isEmpty) return false;
    final start = task.startDate;
    if (start == null) return false;
    final end = computeTaskEndDate(task, widget.project) ??
        task.dueDate ??
        start.add(const Duration(days: 1));
    return assignee.oooRanges
        .any((r) => r.start.isBefore(end) && r.end.isAfter(start));
  }

  Widget _dueDateCell(BuildContext context, TaskModel task) {
    final theme = Theme.of(context);
    final isOverdue = task.isOverdue;
    final label = _formatDateTime(task.dueDate);
    if (!widget.canEdit) {
      return Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isOverdue ? theme.colorScheme.error : null,
          fontWeight: isOverdue ? FontWeight.w600 : null,
        ),
      );
    }
    return InkWell(
      onTap: () async {
        final picked = await _pickDateTime(context, task.dueDate);
        if (picked != null) await _saveField(task, dueDate: picked);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOverdue ? theme.colorScheme.error : null,
              fontWeight: isOverdue ? FontWeight.w600 : null,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_calendar_outlined,
              size: 14, color: theme.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _startDateCell(BuildContext context, TaskModel task) {
    final theme = Theme.of(context);
    final label = _formatDateTime(task.startDate);
    final hasPredecessors = task.predecessorTaskCodes.isNotEmpty;
    // Read-only when not canEdit OR when predecessors control the start date
    if (!widget.canEdit || hasPredecessors) {
      return Text(label, style: theme.textTheme.bodySmall);
    }
    return InkWell(
      onTap: () async {
        final picked = await _pickDateTime(context, task.startDate);
        if (picked != null) {
          await _saveField(task, startDate: picked, clearStartDate: false);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(decoration: TextDecoration.underline),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_calendar_outlined,
              size: 14, color: theme.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _durationCell(BuildContext context, TaskModel task) {
    final theme = Theme.of(context);
    final label = task.duration.isEmpty ? '—' : task.duration;
    if (!widget.canEdit) {
      return Text(label, style: theme.textTheme.bodySmall);
    }
    return InkWell(
      onTap: () async {
        final controller =
            TextEditingController(text: task.duration);
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Set Duration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 2d, 1w, 3mo, 8 (hours)',
                    helperText:
                        'Units: plain number = hours · d = days · w = weeks · mo = months',
                  ),
                  onSubmitted: (_) =>
                      Navigator.of(ctx).pop(controller.text.trim()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (result != null) {
          await _saveField(task, duration: result);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(decoration: TextDecoration.underline),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit_outlined,
              size: 14, color: theme.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _predecessorsCell(BuildContext context, TaskModel task) {
    final theme = Theme.of(context);
    final summaries = widget.controller.predecessorSummaries(task);
    final label = summaries.join(', ').ifEmpty('—');
    if (!widget.canEdit) {
      return SizedBox(
        width: 136,
        child: Text(label,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      );
    }
    final allProjectTasks = widget.controller.tasks
        .where((t) => t.projectId == widget.project.id && t.id != task.id)
        .toList(growable: false);
    return InkWell(
      onTap: () async {
        final selected = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => _PredecessorPickerDialog(
            allTasks: allProjectTasks,
            currentCodes: task.predecessorTaskCodes.toSet(),
          ),
        );
        if (selected != null) {
          // Auto-compute start date = max(endDate ?? dueDate) of selected predecessors
          DateTime? latestEnd;
          for (final code in selected) {
            final pred = allProjectTasks.cast<TaskModel?>()
                .firstWhere((t) => t?.taskCode == code, orElse: () => null);
            final predEnd = (pred == null)
                ? null
                : computeTaskEndDate(pred, widget.project) ?? pred.dueDate;
            if (predEnd != null &&
                (latestEnd == null || predEnd.isAfter(latestEnd))) {
              latestEnd = predEnd;
            }
          }
          await _saveField(task,
              predecessorTaskCodes: selected.toList(growable: false),
              startDate: selected.isEmpty ? null : latestEnd,
              clearStartDate: selected.isEmpty);
        }
      },
      child: SizedBox(
        width: 136,
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(decoration: TextDecoration.underline),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.edit_outlined, size: 14, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

// ── Predecessor picker dialog ───────────────────────────────────────────────

class _PredecessorPickerDialog extends StatefulWidget {
  const _PredecessorPickerDialog({
    required this.allTasks,
    required this.currentCodes,
  });

  final List<TaskModel> allTasks;
  final Set<String> currentCodes;

  @override
  State<_PredecessorPickerDialog> createState() =>
      _PredecessorPickerDialogState();
}

class _PredecessorPickerDialogState extends State<_PredecessorPickerDialog> {
  late Set<String> _selected;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.currentCodes);
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.allTasks]
      ..sort((a, b) => a.taskCode.compareTo(b.taskCode));
    final filtered = _searchQuery.isEmpty
        ? sorted
        : sorted.where((t) =>
            t.taskCode.toLowerCase().contains(_searchQuery) ||
            t.title.toLowerCase().contains(_searchQuery)).toList(growable: false);

    return AlertDialog(
      title: const Text('Select predecessors'),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.9).clamp(280.0, 520.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by ID or title…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
              ),
              autofocus: false,
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No matching tasks.'),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filtered
                            .map((task) => FilterChip(
                                  label: Text('${task.taskCode} – ${task.title}'),
                                  selected: _selected.contains(task.taskCode),
                                  onSelected: (on) => setState(() {
                                    if (on) {
                                      _selected.add(task.taskCode);
                                    } else {
                                      _selected.remove(task.taskCode);
                                    }
                                  }),
                                ))
                            .toList(growable: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

Color _priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return const Color(0xFF4A7C59);
    case TaskPriority.medium:
      return const Color(0xFFDAA520);
    case TaskPriority.high:
      return const Color(0xFFD96C45);
  }
}



class _ProjectRecordTab extends StatefulWidget {
  const _ProjectRecordTab({
    required this.controller,
    required this.project,
    required this.type,
    required this.entries,
    required this.assignees,
    required this.canEdit,
  });

  final AppController controller;
  final ProjectModel project;
  final ProjectRecordType type;
  final List<ProjectRecordEntry> entries;
  final List<AssigneeModel> assignees;
  final bool canEdit;

  @override
  State<_ProjectRecordTab> createState() => _ProjectRecordTabState();
}

class _ProjectRecordTabState extends State<_ProjectRecordTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredEntries = widget.entries
        .where((entry) {
          if (searchQuery.isEmpty) return true;
          return entry.id.toLowerCase().contains(searchQuery) ||
              entry.description.toLowerCase().contains(searchQuery) ||
              entry.comments.toLowerCase().contains(searchQuery);
        })
        .toList(growable: false);

    return SectionCard(
      title: '${_recordLabel(widget.type)} Log',
      subtitle:
          'Manage ${_recordLabel(widget.type).toLowerCase()} entries. Click column headers to sort or filter.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 160, maxWidth: 260),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText:
                        'Search ${_recordLabel(widget.type).toLowerCase()}s',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (widget.canEdit)
                ElevatedButton.icon(
                  onPressed: () => _openAddDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text('Add ${_recordLabel(widget.type)}'),
                ),
              OutlinedButton.icon(
                onPressed: () => controller.exportProjectRecordsToCsv(
                  projectId: widget.project.id,
                  type: widget.type,
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download CSV'),
              ),
              if (widget.canEdit)
                OutlinedButton.icon(
                  onPressed: () => controller.importProjectRecordsFromCsv(
                    projectId: widget.project.id,
                    type: widget.type,
                  ),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload CSV'),
                ),
            ],
          ),
          if (!widget.canEdit) ...[
            const SizedBox(height: 12),
            const Text(
              'Only a Project Admin can add or import project records.',
            ),
          ],
          const SizedBox(height: 16),
          filteredEntries.isEmpty
              ? Text(
                  'No ${_recordLabel(widget.type).toLowerCase()} entries match the current search.',
                )
              : _RecordTable(
                  entries: filteredEntries,
                  controller: controller,
                  project: widget.project,
                  assignees: widget.assignees,
                  type: widget.type,
                  canEdit: widget.canEdit,
                  onDelete: (entry) => controller.deleteProjectRecord(
                    projectId: widget.project.id,
                    type: widget.type,
                    entryId: entry.id,
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _openAddDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => _ProjectRecordEditorDialog(
        type: widget.type,
        assignees: widget.assignees,
        userName: widget.controller.currentUserName,
        onSave:
            ({
              assigneeId,
              required description,
              required comments,
              required status,
              probability,
            }) {
              return widget.controller.addProjectRecord(
                projectId: widget.project.id,
                type: widget.type,
                assigneeId: assigneeId,
                description: description,
                comments: comments,
                status: status,
                probability: probability,
              );
            },
      ),
    );
  }
}

// ── Record table ────────────────────────────────────────────────────────────

class _RecordTable extends StatefulWidget {
  const _RecordTable({
    required this.entries,
    required this.controller,
    required this.project,
    required this.assignees,
    required this.type,
    required this.canEdit,
    required this.onDelete,
  });

  final List<ProjectRecordEntry> entries;
  final AppController controller;
  final ProjectModel project;
  final List<AssigneeModel> assignees;
  final ProjectRecordType type;
  final bool canEdit;
  final void Function(ProjectRecordEntry) onDelete;

  @override
  State<_RecordTable> createState() => _RecordTableState();
}

class _RecordTableState extends State<_RecordTable> {
  // ── Column definitions ────────────────────────────────────────────────────
  // Base columns shared by all record types
  static const _baseColDefs = [
    TableColDef(id: 'id',          label: 'ID',          width: 80),
    TableColDef(id: 'description', label: 'Description', width: 220, canHide: false),
    TableColDef(id: 'status',      label: 'Status',      width: 130),
    TableColDef(id: 'assignee',    label: 'Assignee',    width: 130),
    TableColDef(id: 'comments',    label: 'Comments',    width: 200, sortable: false),
    TableColDef(id: 'probability', label: 'Probability', width: 120),
    TableColDef(id: 'createdAt',   label: 'Created',     width: 110),
    TableColDef(id: 'updatedBy',   label: 'Updated By',  width: 130),
    TableColDef(id: 'updatedAt',   label: 'Last Updated',width: 140),
  ];

  bool get _isRisk => widget.type == ProjectRecordType.risk;

  List<TableColDef> get _allColDefs => _isRisk
      ? _baseColDefs
      : _baseColDefs.where((c) => c.id != 'probability').toList(growable: false);

  List<String> get _defaultColOrder =>
      _allColDefs.map((c) => c.id).toList(growable: false);

  // ── Sort / filter state ───────────────────────────────────────────────────
  String? _sortColId;
  bool _sortAscending = true;
  String? _filterStatus;
  String? _filterAssignee;
  RiskProbability? _filterProbability;

  // ── Column pref state ─────────────────────────────────────────────────────
  List<String> _colOrder = [];
  Set<String> _hiddenCols = {};
  Map<String, double> _colWidths = {};
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _colOrder = _defaultColOrder;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final key = widget.type.name; // 'issue', 'risk', 'action', 'decision'
    final prefs = await TableColPrefs.load(key, _defaultColOrder);
    if (mounted) {
      setState(() {
        _colOrder = prefs.order;
        _hiddenCols = prefs.hidden;
        _colWidths = prefs.widths;
        _prefsLoaded = true;
      });
    }
  }

  Future<void> _savePrefs() async {
    final key = widget.type.name;
    await TableColPrefs.save(
        key, TableColPrefs(order: _colOrder, hidden: _hiddenCols, widths: _colWidths));
  }

  void _onResized(String colId, double newWidth) {
    setState(() => _colWidths = {..._colWidths, colId: newWidth});
    _savePrefs();
  }

  void _onReorder(String fromId, String toId) {
    final from = _colOrder.indexOf(fromId);
    final to = _colOrder.indexOf(toId);
    if (from == -1 || to == -1 || from == to) return;
    setState(() {
      _colOrder.removeAt(from);
      _colOrder.insert(to, fromId);
    });
    _savePrefs();
  }

  void _onSort(String colId) {
    setState(() {
      if (_sortColId == colId) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColId = colId;
        _sortAscending = true;
      }
    });
  }

  void _toggleHide(String colId) {
    setState(() {
      if (_hiddenCols.contains(colId)) {
        _hiddenCols = {..._hiddenCols}..remove(colId);
      } else {
        _hiddenCols = {..._hiddenCols, colId};
      }
    });
    _savePrefs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Sort / filter helpers ─────────────────────────────────────────────────

  List<ProjectRecordEntry> _sorted(List<ProjectRecordEntry> source) {
    final id = _sortColId;
    if (id == null) return source;
    final result = List<ProjectRecordEntry>.from(source);
    result.sort((a, b) {
      int cmp;
      switch (id) {
        case 'id':
          cmp = a.id.compareTo(b.id);
        case 'description':
          cmp = a.description.toLowerCase().compareTo(b.description.toLowerCase());
        case 'status':
          cmp = a.status.toLowerCase().compareTo(b.status.toLowerCase());
        case 'assignee':
          cmp = widget.controller
              .assigneeName(a.assigneeId)
              .toLowerCase()
              .compareTo(widget.controller.assigneeName(b.assigneeId).toLowerCase());
        case 'probability':
          cmp = (a.probability?.index ?? -1).compareTo(b.probability?.index ?? -1);
        case 'createdAt':
          cmp = a.createdAt.compareTo(b.createdAt);
        case 'updatedAt':
          cmp = (a.updatedAt ?? a.createdAt).compareTo(b.updatedAt ?? b.createdAt);
        case 'updatedBy':
          cmp = a.updatedBy.toLowerCase().compareTo(b.updatedBy.toLowerCase());
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return result;
  }

  List<ProjectRecordEntry> _filtered(List<ProjectRecordEntry> source) {
    return source.where((entry) {
      if (_filterStatus != null && entry.status != _filterStatus) return false;
      if (_filterAssignee != null && entry.assigneeId != _filterAssignee) return false;
      if (_isRisk && _filterProbability != null &&
          entry.probability != _filterProbability) return false;
      return true;
    }).toList(growable: false);
  }

  // ── Visible columns ───────────────────────────────────────────────────────

  static const _actionsColDef = TableColDef(
    id: 'actions', label: '', width: 56,
    sortable: false, canHide: false, canReorder: false,
  );

  List<TableColDef> _visibleCols() {
    final byId = {for (final c in _allColDefs) c.id: c};
    final cols = _colOrder
        .where((id) => !_hiddenCols.contains(id))
        .map((id) {
          final col = byId[id];
          if (col == null) return null;
          final w = _colWidths[id];
          return w != null ? col.withWidth(w) : col;
        })
        .whereType<TableColDef>()
        .toList();
    if (widget.canEdit) cols.add(_actionsColDef);
    return cols;
  }

  // ── Cell builders ─────────────────────────────────────────────────────────

  Widget _cellFor(String colId, ProjectRecordEntry entry, BuildContext context) {
    final theme = Theme.of(context);
    switch (colId) {
      case 'id':
        return Text(entry.id,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600));
      case 'description':
        return _textCell(context, entry, entry.description,
            '${_recordLabel(widget.type)} Description',
            width: 196, maxLines: 3,
            onSave: (v) => _saveField(entry, description: v));
      case 'status':
        return _statusCell(context, entry);
      case 'assignee':
        return _assigneeCell(context, entry);
      case 'comments':
        return _textCell(context, entry, entry.comments, 'Comments',
            width: 176, isComments: true,
            onSave: (v) => _saveField(entry, comments: v));
      case 'probability':
        return _probabilityCell(context, entry);
      case 'createdAt':
        return Text(DateFormat('MMM d, yyyy').format(entry.createdAt),
            style: theme.textTheme.bodySmall);
      case 'updatedBy':
        return Text(entry.updatedBy.isEmpty ? '—' : entry.updatedBy,
            style: theme.textTheme.bodySmall);
      case 'updatedAt':
        return Text(
          entry.updatedAt == null
              ? '—'
              : DateFormat('MMM d, yyyy HH:mm').format(entry.updatedAt!),
          style: theme.textTheme.bodySmall,
        );
      case 'actions':
        return IconButton(
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline_rounded,
              size: 18, color: theme.colorScheme.error),
          onPressed: () => widget.onDelete(entry),
          visualDensity: VisualDensity.compact,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final displayEntries = _sorted(_filtered(widget.entries));
    final visibleCols = _visibleCols();
    final hideable = _allColDefs.where((c) => c.canHide).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toolbar ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _filterChip(context, 'Status',
                  _filterStatus ?? 'All statuses', Icons.tune_rounded, () async {
                final v = await _showStringPicker(context, 'Filter by Status',
                    [null, ...defaultRecordStatuses], _filterStatus);
                if (v != null || mounted) {
                  setState(() => _filterStatus = v == '' ? null : v);
                }
              }),
              _filterChip(context, 'Assignee',
                  _filterAssignee == null
                      ? 'All assignees'
                      : widget.controller.assigneeName(_filterAssignee),
                  Icons.tune_rounded, () async {
                final ids = [null, ...widget.assignees.map((a) => a.id)];
                final v = await _showStringPicker(
                    context, 'Filter by Assignee', ids, _filterAssignee,
                    labelFor: (id) => id == null
                        ? 'All assignees'
                        : widget.controller.assigneeName(id));
                if (v != null || mounted) {
                  setState(() => _filterAssignee = v == '' ? null : v);
                }
              }),
              if (_isRisk)
                _filterChip(context, 'Probability',
                    _filterProbability == null
                        ? 'All probabilities'
                        : _filterProbability!.name.toUpperCase(),
                    Icons.tune_rounded, () async {
                  final options = [null, ...RiskProbability.values];
                  final v = await _showStringPicker(
                      context, 'Filter by Probability',
                      options.map((p) => p?.name).toList(), _filterProbability?.name,
                      labelFor: (s) => s == null ? 'All probabilities' : s.toUpperCase());
                  if (v != null || mounted) {
                    setState(() => _filterProbability = v == ''
                        ? null
                        : RiskProbability.values
                            .where((p) => p.name == v)
                            .firstOrNull);
                  }
                }),
              // Column visibility button
              PopupMenuButton<String>(
                tooltip: 'Show/hide columns',
                icon: const Icon(Icons.view_column_outlined),
                itemBuilder: (_) => hideable
                    .map((col) => CheckedPopupMenuItem<String>(
                          value: col.id,
                          checked: !_hiddenCols.contains(col.id),
                          child: Text(col.label),
                        ))
                    .toList(growable: false),
                onSelected: _toggleHide,
              ),
              // Auto column width button
              IconButton(
                tooltip: 'Reset column widths',
                icon: const Icon(Icons.fit_screen_rounded, size: 20),
                onPressed: () {
                  setState(() => _colWidths = {});
                  _savePrefs();
                },
              ),
            ],
          ),
        ),
        // ── Table ──────────────────────────────────────────────────────────
        CustomDataTable(
          columns: visibleCols,
          sortColId: _sortColId,
          sortAscending: _sortAscending,
          onSort: _onSort,
          onReorder: _onReorder,
          onResized: _onResized,
          pinnedLeadingCount: 0,
          pinnedTrailingCount: widget.canEdit ? 1 : 0,
          rows: [
            for (final entry in displayEntries)
              [for (final col in visibleCols) _cellFor(col.id, entry, context)],
          ],
        ),
      ],
    );
  }

  // ── Filter chip helper ────────────────────────────────────────────────────

  Widget _filterChip(BuildContext context, String label, String value,
      IconData icon, VoidCallback onTap) {
    final active = !value.startsWith('All');
    return ActionChip(
      avatar: Icon(icon, size: 14),
      label: Text(value, overflow: TextOverflow.ellipsis),
      backgroundColor:
          active ? Theme.of(context).colorScheme.primaryContainer : null,
      onPressed: onTap,
    );
  }

  // ── String picker dialog ──────────────────────────────────────────────────

  Future<String?> _showStringPicker(
    BuildContext context,
    String title,
    List<String?> options,
    String? current, {
    String Function(String?)? labelFor,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: options
            .map((v) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(v ?? ''),
                  child: Text(labelFor?.call(v) ?? (v == null ? 'All' : v)),
                ))
            .toList(),
      ),
    );
  }

  // ── Field save helper ─────────────────────────────────────────────────────

  Future<void> _saveField(
    ProjectRecordEntry entry, {
    String? status,
    String? assigneeId,
    bool clearAssigneeId = false,
    String? description,
    String? comments,
    RiskProbability? probability,
    bool clearProbability = false,
  }) async {
    await widget.controller.updateProjectRecord(
      projectId: widget.project.id,
      type: widget.type,
      entryId: entry.id,
      status: status,
      assigneeId: assigneeId,
      clearAssigneeId: clearAssigneeId,
      description: description,
      comments: comments,
      probability: probability,
      clearProbability: clearProbability,
    );
  }

  // ── Inline edit cell widgets ──────────────────────────────────────────────

  Widget _statusCell(BuildContext context, ProjectRecordEntry entry) {
    if (!widget.canEdit) {
      return Chip(
        label: Text(entry.status, style: Theme.of(context).textTheme.labelSmall),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      );
    }
    return DropdownButton<String>(
      value: defaultRecordStatuses.contains(entry.status)
          ? entry.status
          : defaultRecordStatuses.first,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: defaultRecordStatuses
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (value) {
        if (value != null && value != entry.status) _saveField(entry, status: value);
      },
    );
  }

  Widget _assigneeCell(BuildContext context, ProjectRecordEntry entry) {
    final name = widget.controller.assigneeName(entry.assigneeId);
    if (!widget.canEdit) {
      return Text(name, style: Theme.of(context).textTheme.bodySmall);
    }
    return DropdownButton<String?>(
      value: entry.assigneeId,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
        ...widget.assignees.map(
            (a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
      ],
      onChanged: (value) {
        if (value != entry.assigneeId) {
          _saveField(entry, assigneeId: value, clearAssigneeId: value == null);
        }
      },
    );
  }

  Widget _probabilityCell(BuildContext context, ProjectRecordEntry entry) {
    if (!widget.canEdit) {
      return Text(entry.probability?.name.toUpperCase() ?? '—',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return DropdownButton<RiskProbability?>(
      value: entry.probability,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: [
        const DropdownMenuItem<RiskProbability?>(value: null, child: Text('—')),
        ...RiskProbability.values.map((p) => DropdownMenuItem<RiskProbability?>(
              value: p,
              child: Text(p.name.toUpperCase()),
            )),
      ],
      onChanged: (value) {
        if (value != entry.probability) {
          _saveField(entry, probability: value, clearProbability: value == null);
        }
      },
    );
  }

  Widget _textCell(
    BuildContext context,
    ProjectRecordEntry entry,
    String value,
    String fieldLabel, {
    required Future<void> Function(String newValue) onSave,
    int maxLines = 2,
    double width = 200,
    bool isComments = false,
  }) {
    final theme = Theme.of(context);
    if (!widget.canEdit) {
      return SizedBox(
        width: width,
        child: isComments
            ? MarkdownText(value.isEmpty ? '—' : value,
                style: theme.textTheme.bodySmall,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis)
            : Text(value.isEmpty ? '—' : value,
                style: theme.textTheme.bodySmall,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis),
      );
    }
    return InkWell(
      onTap: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => _RecordTextEditDialog(
            label: fieldLabel,
            initialValue: value,
            isComments: isComments,
            userName: widget.controller.currentUserName,
          ),
        );
        if (result != null) await onSave(result);
      },
      child: SizedBox(
        width: width,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: isComments
                  ? MarkdownText(value.isEmpty ? '—' : value,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(decoration: TextDecoration.underline),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis)
                  : Text(value.isEmpty ? '—' : value,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(decoration: TextDecoration.underline),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.edit_outlined, size: 14, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

// ── Record text-edit dialog ─────────────────────────────────────────────────

class _RecordTextEditDialog extends StatefulWidget {
  const _RecordTextEditDialog({
    required this.label,
    required this.initialValue,
    this.isComments = false,
    this.userName = '',
  });

  final String label;
  final String initialValue;
  final bool isComments;
  final String userName;

  @override
  State<_RecordTextEditDialog> createState() => _RecordTextEditDialogState();
}

class _RecordTextEditDialogState extends State<_RecordTextEditDialog> {
  // For comments mode: new text goes here; existing is shown read-only below.
  // For non-comment fields: single editable controller.
  late final TextEditingController _controller;
  final TextEditingController _newCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    _newCommentController.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    if (widget.isComments) {
      final newText = _newCommentController.text.trim();
      if (newText.isEmpty) {
        // Nothing new typed — return existing unchanged.
        Navigator.of(context).pop(widget.initialValue);
      } else {
        final prefix = commentTimestampPrefix(widget.userName);
        final separator = widget.initialValue.isEmpty ? '' : '\n';
        Navigator.of(context).pop(prefix + newText + separator + widget.initialValue);
      }
    } else {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isComments) {
      return AlertDialog(
        title: const Text('Add Comment'),
        content: SizedBox(
          width: (MediaQuery.of(context).size.width * 0.9).clamp(280.0, 580.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarkdownToolbar(controller: _newCommentController),
              const SizedBox(height: 8),
              TextField(
                controller: _newCommentController,
                decoration: const InputDecoration(
                  labelText: 'New comment',
                  hintText: 'Use **bold**, *italic*, `code`, - bullet, 1. numbered',
                ),
                minLines: 4,
                maxLines: 10,
                autofocus: true,
              ),
              if (widget.initialValue.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: theme.colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Previous comments',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55))),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: MarkdownText(
                      widget.initialValue,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _save(context),
            child: const Text('Save'),
          ),
        ],
      );
    }

    // ── Non-comment field ────────────────────────────────────────────────────
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.9).clamp(280.0, 560.0),
        child: TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 8,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _save(context),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProjectKanbanTab extends StatefulWidget {
  const _ProjectKanbanTab({
    required this.controller,
    required this.project,
    required this.tasks,
    required this.canEdit,
    required this.onStatusChanged,
  });

  final AppController controller;
  final ProjectModel project;
  final List<TaskModel> tasks;
  final bool canEdit;
  final Future<void> Function(TaskModel task, String newStatus) onStatusChanged;

  @override
  State<_ProjectKanbanTab> createState() => _ProjectKanbanTabState();
}

class _ProjectKanbanTabState extends State<_ProjectKanbanTab> {
  /// The status column currently being hovered over during a drag.
  String? _hoverStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.project.taskStatuses
            .map((status) => _buildColumn(context, theme, status))
            .toList(growable: false),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, ThemeData theme, String status) {
    final columnTasks =
        widget.tasks.where((t) => t.status == status).toList(growable: false);
    final isHover = _hoverStatus == status;

    Widget column = Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: SectionCard(
        title: status,
        subtitle: 'Tasks currently in this workflow column.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final task in columnTasks)
              _buildCard(context, theme, task),
            if (columnTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No tasks in this status.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!widget.canEdit) return column;

    return DragTarget<TaskModel>(
      onWillAcceptWithDetails: (details) {
        if (details.data.status == status) return false;
        setState(() => _hoverStatus = status);
        return true;
      },
      onLeave: (_) => setState(() {
        if (_hoverStatus == status) _hoverStatus = null;
      }),
      onAcceptWithDetails: (details) {
        setState(() => _hoverStatus = null);
        widget.onStatusChanged(details.data, status);
      },
      builder: (ctx, candidateData, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: isHover
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
              )
            : const BoxDecoration(),
        child: column,
      ),
    );
  }

  Widget _buildCard(BuildContext context, ThemeData theme, TaskModel task) {
    final assignee = task.assigneeId == null
        ? null
        : widget.controller.assignees.cast<AssigneeModel?>().firstWhere(
            (a) => a?.id == task.assigneeId,
            orElse: () => null,
          );
    final isOoo = assignee != null && _checkOoo(task, assignee);
    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${task.taskCode} - ${task.title}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.controller.assigneeName(task.assigneeId),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (isOoo)
                  Chip(
                    label: const Text('OOO'),
                    backgroundColor:
                        theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Target: ${_formatDateTime(task.dueDate)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );

    if (!widget.canEdit) return card;

    return Draggable<TaskModel>(
      data: task,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 252,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${task.taskCode} - ${task.title}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.controller.assigneeName(task.assigneeId),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: card,
      ),
    );
  }

  bool _checkOoo(TaskModel task, AssigneeModel assignee) {
    if (assignee.oooRanges.isEmpty) return false;
    final start = task.startDate;
    if (start == null) return false;
    final end = computeTaskEndDate(task, widget.project) ??
        task.dueDate ??
        start.add(const Duration(days: 1));
    return assignee.oooRanges
        .any((r) => r.start.isBefore(end) && r.end.isAfter(start));
  }
}

class _ProjectCalendarTab extends StatelessWidget {
  const _ProjectCalendarTab({
    required this.controller,
    required this.project,
    required this.tasks,
  });

  final AppController controller;
  final ProjectModel project;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final entries = <GanttChartEntry>[
      ...project.phases.map(
        (phase) => GanttChartEntry(
          label: phase.name,
          subtitle: 'Phase',
          start: phase.startDate,
          end: phase.endDate,
          color: Color(project.colorValue).withValues(alpha: 0.72),
        ),
      ),
      ...tasks
          .where((task) => task.startDate != null || task.dueDate != null)
          .map(
            (task) {
              final taskStart = task.startDate;
              final taskEnd = taskStart != null
                  ? computeTaskEndDate(task, project) ?? task.dueDate ?? taskStart
                  : task.dueDate;
              return GanttChartEntry(
                label: '${task.taskCode} - ${task.title}',
                subtitle:
                    'Task • ${controller.phaseName(project.id, task.phaseId)} • ${task.status}',
                start: taskStart ?? taskEnd,
                end: taskEnd ?? taskStart,
                color: task.isMilestone
                    ? const Color(0xFFD96C45)
                    : const Color(0xFF2E5BFF),
              );
            },
          ),
    ];

    return SectionCard(
      title: 'Project Gantt View',
      subtitle: 'A Gantt-style view of the project phases and dated tasks.',
      child:
          entries
              .where((entry) => entry.start != null || entry.end != null)
              .isEmpty
          ? const Text('No dated project items yet.')
          : GanttChartView(
              entries: entries,
              publicHolidays: project.publicHolidays,
            ),
    );
  }
}

class _ProjectRecordEditorDialog extends StatefulWidget {
  const _ProjectRecordEditorDialog({
    required this.type,
    required this.assignees,
    required this.onSave,
    this.userName = '',
  });

  final ProjectRecordType type;
  final List<AssigneeModel> assignees;
  final String userName;
  final Future<void> Function({
    String? assigneeId,
    required String description,
    required String comments,
    required String status,
    RiskProbability? probability,
  })
  onSave;

  @override
  State<_ProjectRecordEditorDialog> createState() =>
      _ProjectRecordEditorDialogState();
}

class _ProjectRecordEditorDialogState
    extends State<_ProjectRecordEditorDialog> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _commentsController;
  String? _selectedAssigneeId;
  String _selectedStatus = defaultRecordStatuses.first;
  RiskProbability? _selectedProbability = RiskProbability.medium;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _commentsController = TextEditingController(
      text: commentTimestampPrefix(widget.userName),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _recordLabel(widget.type);
    return AlertDialog(
      title: Text('Add $label'),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.9).clamp(280.0, 500.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _selectedAssigneeId,
              decoration: const InputDecoration(labelText: 'Assignee'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                ...widget.assignees.map(
                  (assignee) => DropdownMenuItem<String?>(
                    value: assignee.id,
                    child: Text('${assignee.name} (${assignee.email})'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedAssigneeId = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: '$label description'),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 14),
            MarkdownToolbar(controller: _commentsController),
            const SizedBox(height: 6),
            TextField(
              controller: _commentsController,
              decoration: const InputDecoration(
                labelText: 'Comments',
                hintText: 'Use **bold**, *italic*, `code`, - bullet, 1. numbered',
              ),
              minLines: 4,
              maxLines: 8,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: defaultRecordStatuses
                  .map(
                    (status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _selectedStatus = value!),
            ),
            if (widget.type == ProjectRecordType.risk) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<RiskProbability?>(
                initialValue: _selectedProbability,
                decoration: const InputDecoration(labelText: 'Probability'),
                items: const [
                  DropdownMenuItem<RiskProbability?>(
                    value: null,
                    child: Text('Unspecified'),
                  ),
                  DropdownMenuItem(
                    value: RiskProbability.low,
                    child: Text('Low'),
                  ),
                  DropdownMenuItem(
                    value: RiskProbability.medium,
                    child: Text('Medium'),
                  ),
                  DropdownMenuItem(
                    value: RiskProbability.high,
                    child: Text('High'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedProbability = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            // Strip the timestamp prefix if the user typed nothing after it.
            final rawComments = _commentsController.text;
            final prefix = commentTimestampPrefix(widget.userName);
            final comments = rawComments == prefix ? '' : rawComments;
            await widget.onSave(
              assigneeId: _selectedAssigneeId,
              description: _descriptionController.text,
              comments: comments,
              status: _selectedStatus,
              probability: _selectedProbability,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({
    required this.onSave,
    required this.assignees,
    required this.colors,
    required this.timezones,
    required this.nextProjectCode,
    required this.canManageStatuses,
    required this.isSuperAdmin,
    this.initialProject,
  });

  final Future<void> Function({
    required String title,
    required String description,
    required int colorValue,
    required String timezone,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<ProjectPhase> phases,
    required List<String> taskStatuses,
    required List<String> assignedAssigneeIds,
    required bool isConfidential,
    required Map<String, Set<String>> grantsByAssigneeId,
    required String? actualStartStatus,
    required String? actualEndStatus,
    required String? actualStartResetStatus,
    required String? actualEndResetStatus,
    required bool allowSampleData,
    required List<int> workingDays,
    required int workDayStartHour,
    required int workDayEndHour,
    required List<DateTime> publicHolidays,
  })
  onSave;
  final List<AssigneeModel> assignees;
  final ProjectModel? initialProject;
  final List<int> colors;
  final List<String> timezones;
  final String nextProjectCode;
  final bool canManageStatuses;
  final bool isSuperAdmin;

  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _statusController;
  late final TextEditingController _phaseNameController;
  late int _selectedColor;
  late String _selectedTimezone;
  late List<String> _statuses;
  late List<ProjectPhase> _phases;
  late Set<String> _assignedAssigneeIds;
  late Map<String, Set<String>> _grantsByAssigneeId;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _isConfidential;
  String? _actualStartStatus;
  String? _actualEndStatus;
  String? _actualStartResetStatus;
  String? _actualEndResetStatus;
  late bool _allowSampleData;
  late List<int> _workingDays;
  late int _workDayStartHour;
  late int _workDayEndHour;
  List<DateTime> _publicHolidays = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialProject?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialProject?.description ?? '',
    );
    _statusController = TextEditingController();
    _phaseNameController = TextEditingController();
    _selectedColor = widget.initialProject?.colorValue ?? widget.colors.first;
    _selectedTimezone =
        widget.initialProject?.timezone ?? widget.timezones.first;
    _statuses = List<String>.from(
      widget.initialProject?.taskStatuses ?? defaultProjectStatuses,
    );
    _phases = List<ProjectPhase>.from(
      widget.initialProject?.phases ?? const [],
    );
    _assignedAssigneeIds = {
      for (final assignee in widget.assignees)
        if (widget.initialProject != null &&
            assignee.projectIds.contains(widget.initialProject!.id))
          assignee.id,
    };
    _grantsByAssigneeId = {
      for (final assignee in widget.assignees)
        if (widget.initialProject != null &&
            assignee.projectGrants.containsKey(widget.initialProject!.id))
          assignee.id: Set<String>.from(
            assignee.projectGrants[widget.initialProject!.id]!,
          ),
    };
    _startDate = widget.initialProject?.startDate;
    _endDate = widget.initialProject?.endDate;
    _isConfidential = widget.initialProject?.isConfidential ?? false;
    _actualStartStatus = widget.initialProject?.actualStartStatus;
    _actualEndStatus = widget.initialProject?.actualEndStatus;
    _actualStartResetStatus = widget.initialProject?.actualStartResetStatus;
    _actualEndResetStatus = widget.initialProject?.actualEndResetStatus;
    _allowSampleData = widget.initialProject?.allowSampleData ?? true;
    _workingDays = List<int>.from(
      widget.initialProject?.workingDays ?? [1, 2, 3, 4, 5],
    );
    _workDayStartHour = widget.initialProject?.workDayStartHour ?? 9;
    _workDayEndHour = widget.initialProject?.workDayEndHour ?? 17;
    _publicHolidays = List<DateTime>.from(
      widget.initialProject?.publicHolidays ?? [],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _statusController.dispose();
    _phaseNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialProject == null ? 'New project' : 'Edit project',
      ),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.9).clamp(280.0, 540.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Project ID: ${widget.initialProject?.projectCode ?? widget.nextProjectCode}',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Project title'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedTimezone,
                decoration: const InputDecoration(labelText: 'Timezone'),
                items: widget.timezones
                    .map(
                      (timezone) => DropdownMenuItem<String>(
                        value: timezone,
                        child: Text(timezone),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _selectedTimezone = value!),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _startDate == null
                          ? 'Start date not set'
                          : 'Start: ${DateFormat('MMM d, yyyy').format(_startDate!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.canManageStatuses
                        ? () => _pickDate(isStartDate: true)
                        : null,
                    child: const Text('Pick'),
                  ),
                  if (_startDate != null)
                    TextButton(
                      onPressed: widget.canManageStatuses
                          ? () => setState(() => _startDate = null)
                          : null,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _endDate == null
                          ? 'End date not set'
                          : 'End: ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: widget.canManageStatuses
                        ? () => _pickDate(isStartDate: false)
                        : null,
                    child: const Text('Pick'),
                  ),
                  if (_endDate != null)
                    TextButton(
                      onPressed: widget.canManageStatuses
                          ? () => setState(() => _endDate = null)
                          : null,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Color',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: widget.colors
                    .map(
                      (colorValue) => InkWell(
                        onTap: () =>
                            setState(() => _selectedColor = colorValue),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == colorValue
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Task Statuses',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses
                    .map(
                      (status) => InputChip(
                        label: Text(status),
                        onDeleted: widget.canManageStatuses
                            ? () => setState(() => _statuses.remove(status))
                            : null,
                      ),
                    )
                    .toList(growable: false),
              ),
              if (widget.canManageStatuses) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _statusController,
                        decoration: const InputDecoration(
                          labelText: 'Add custom status',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addStatus,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              // ── Actual Date Triggers ─────────────────────────────────────
              if (widget.canManageStatuses) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Actual Date Triggers',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select which status automatically records the Actual Start and Actual End timestamps when a task moves to that status.',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Actual Start Status',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButton<String?>(
                            value: _actualStartStatus,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('— Not set —')),
                              ..._statuses.map((s) =>
                                  DropdownMenuItem<String?>(
                                      value: s, child: Text(s))),
                            ],
                            onChanged: (v) =>
                                setState(() => _actualStartStatus = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Actual End Status',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButton<String?>(
                            value: _actualEndStatus,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('— Not set —')),
                              ..._statuses.map((s) =>
                                  DropdownMenuItem<String?>(
                                      value: s, child: Text(s))),
                            ],
                            onChanged: (v) =>
                                setState(() => _actualEndStatus = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select which status clears (resets) the Actual Start and Actual End timestamps.',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reset Actual Start',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButton<String?>(
                            value: _actualStartResetStatus,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('— Not set —')),
                              ..._statuses.map((s) =>
                                  DropdownMenuItem<String?>(
                                      value: s, child: Text(s))),
                            ],
                            onChanged: (v) =>
                                setState(() => _actualStartResetStatus = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reset Actual End',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButton<String?>(
                            value: _actualEndResetStatus,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('— Not set —')),
                              ..._statuses.map((s) =>
                                  DropdownMenuItem<String?>(
                                      value: s, child: Text(s))),
                            ],
                            onChanged: (v) =>
                                setState(() => _actualEndResetStatus = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              // ── Work Calendar ────────────────────────────────────────────
              if (widget.canManageStatuses) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Work Calendar',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Defines the working days and hours used to calculate task end dates.',
                  ),
                ),
                const SizedBox(height: 12),
                // Working days
                Text('Working Days',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final entry in [
                      (1, 'Mon'),
                      (2, 'Tue'),
                      (3, 'Wed'),
                      (4, 'Thu'),
                      (5, 'Fri'),
                      (6, 'Sat'),
                      (7, 'Sun'),
                    ])
                      FilterChip(
                        label: Text(entry.$2),
                        selected: _workingDays.contains(entry.$1),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _workingDays.add(entry.$1);
                              _workingDays.sort();
                            } else {
                              _workingDays.remove(entry.$1);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Work hours
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start Hour',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButton<int>(
                            value: _workDayStartHour,
                            isExpanded: true,
                            items: List.generate(
                              24,
                              (h) => DropdownMenuItem<int>(
                                value: h,
                                child: Text(
                                    '${h.toString().padLeft(2, '0')}:00'),
                              ),
                            ),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _workDayStartHour = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('End Hour',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          DropdownButton<int>(
                            value: _workDayEndHour,
                            isExpanded: true,
                            items: List.generate(
                              24,
                              (h) => DropdownMenuItem<int>(
                                value: h,
                                child: Text(
                                    '${h.toString().padLeft(2, '0')}:00'),
                              ),
                            ),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _workDayEndHour = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Public holidays
                Row(
                  children: [
                    Text('Public Holidays',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Holiday'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          final dateOnly = DateTime(
                              picked.year, picked.month, picked.day);
                          if (!_publicHolidays.any((d) =>
                              d.year == dateOnly.year &&
                              d.month == dateOnly.month &&
                              d.day == dateOnly.day)) {
                            setState(() {
                              _publicHolidays.add(dateOnly);
                              _publicHolidays.sort();
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
                if (_publicHolidays.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _publicHolidays
                        .map(
                          (d) => Chip(
                            label: Text(
                                DateFormat('MMM d, yyyy').format(d)),
                            onDeleted: () {
                              setState(() => _publicHolidays.remove(d));
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 18),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Project Phases',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tasks can be mapped to these project phases, and the global calendar will show the project timeline with each phase window.',
                ),
              ),
              const SizedBox(height: 12),
              if (_phases.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No phases added yet.'),
                )
              else
                Column(
                  children: _phases
                      .map(
                        (phase) => _PhaseEditorTile(
                          phase: phase,
                          enabled: widget.canManageStatuses,
                          onPickStart: () => _pickPhaseDate(phase.id, true),
                          onPickEnd: () => _pickPhaseDate(phase.id, false),
                          onClearStart: () => _clearPhaseDate(phase.id, true),
                          onClearEnd: () => _clearPhaseDate(phase.id, false),
                          onDelete: () => _deletePhase(phase.id),
                        ),
                      )
                      .toList(growable: false),
                ),
              if (widget.canManageStatuses) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phaseNameController,
                        decoration: const InputDecoration(
                          labelText: 'Add project phase',
                          hintText: 'Discovery, Build, UAT',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addPhase,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              // ── Confidential toggle (SuperAdmin only) ──────────────
              if (widget.isSuperAdmin) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Confidential'),
                  subtitle: const Text(
                    'Mark this project as confidential. Only visible to assigned team members.',
                  ),
                  secondary: Icon(
                    Icons.lock_rounded,
                    color: _isConfidential
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  value: _isConfidential,
                  onChanged: (value) =>
                      setState(() => _isConfidential = value),
                ),
                const SizedBox(height: 8),
              ],
              // ── Allow Sample Data toggle (Project Admin only) ────────
              if (widget.canManageStatuses) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow Sample Data'),
                  subtitle: const Text(
                    'When enabled, project admins can generate sample tasks for this project.',
                  ),
                  secondary: const Icon(Icons.data_array_rounded),
                  value: _allowSampleData,
                  onChanged: (value) =>
                      setState(() => _allowSampleData = value),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Project Team',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Project Admins are the project owners. SuperAdmins can create projects and assign Project Admins, Project Users, or Watchers.',
                ),
              ),
              const SizedBox(height: 12),
              _AssigneeSelectionGroup(
                label: 'Project Admins',
                assignees: widget.assignees
                    .where(
                      (assignee) => assignee.role == AssigneeRole.projectAdmin,
                    )
                    .toList(growable: false),
                selectedIds: _assignedAssigneeIds,
                enabled: widget.canManageStatuses,
                onChanged: _toggleAssignee,
              ),
              const SizedBox(height: 12),
              _AssigneeSelectionGroup(
                label: 'SuperAdmins',
                assignees: widget.assignees
                    .where(
                      (assignee) => assignee.role == AssigneeRole.superAdmin,
                    )
                    .toList(growable: false),
                selectedIds: _assignedAssigneeIds,
                enabled: false,
                onChanged: _toggleAssignee,
              ),
              const SizedBox(height: 12),
              _AssigneeSelectionGroup(
                label: 'Project Users',
                assignees: widget.assignees
                    .where(
                      (assignee) => assignee.role == AssigneeRole.projectUser,
                    )
                    .toList(growable: false),
                selectedIds: _assignedAssigneeIds,
                enabled: widget.canManageStatuses,
                onChanged: _toggleAssignee,
              ),
              const SizedBox(height: 12),
              _AssigneeSelectionGroup(
                label: 'Watchers',
                assignees: widget.assignees
                    .where((assignee) => assignee.role == AssigneeRole.watcher)
                    .toList(growable: false),
                selectedIds: _assignedAssigneeIds,
                enabled: widget.canManageStatuses,
                onChanged: _toggleAssignee,
              ),

              // ── User Permissions ────────────────────────────────────────
              if (widget.canManageStatuses &&
                  widget.initialProject != null) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'User Permissions',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Grant Project Users the ability to add and update content on this project.',
                  ),
                ),
                const SizedBox(height: 12),
                ...() {
                  final projectUsers = widget.assignees
                      .where(
                        (a) =>
                            a.role == AssigneeRole.projectUser &&
                            _assignedAssigneeIds.contains(a.id),
                      )
                      .toList(growable: false);
                  if (projectUsers.isEmpty) {
                    return [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No Project Users are assigned to this project yet.',
                        ),
                      ),
                    ];
                  }
                  return projectUsers.map((assignee) {
                    final grants =
                        _grantsByAssigneeId[assignee.id] ?? <String>{};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignee.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            children: [
                              _GrantCheckbox(
                                label: 'Tasks',
                                grant: ProjectGrant.tasks,
                                grants: grants,
                                onChanged: (updated) => setState(() =>
                                    _grantsByAssigneeId[assignee.id] =
                                        updated),
                              ),
                              _GrantCheckbox(
                                label: 'Issues',
                                grant: ProjectGrant.issues,
                                grants: grants,
                                onChanged: (updated) => setState(() =>
                                    _grantsByAssigneeId[assignee.id] =
                                        updated),
                              ),
                              _GrantCheckbox(
                                label: 'Risks',
                                grant: ProjectGrant.risks,
                                grants: grants,
                                onChanged: (updated) => setState(() =>
                                    _grantsByAssigneeId[assignee.id] =
                                        updated),
                              ),
                              _GrantCheckbox(
                                label: 'Actions',
                                grant: ProjectGrant.actions,
                                grants: grants,
                                onChanged: (updated) => setState(() =>
                                    _grantsByAssigneeId[assignee.id] =
                                        updated),
                              ),
                              _GrantCheckbox(
                                label: 'Decisions',
                                grant: ProjectGrant.decisions,
                                grants: grants,
                                onChanged: (updated) => setState(() =>
                                    _grantsByAssigneeId[assignee.id] =
                                        updated),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await widget.onSave(
              title: _titleController.text,
              description: _descriptionController.text,
              colorValue: _selectedColor,
              timezone: _selectedTimezone,
              startDate: _startDate,
              endDate: _endDate,
              phases: _phases,
              taskStatuses: _statuses,
              assignedAssigneeIds: _assignedAssigneeIds.toList(growable: false),
              isConfidential: _isConfidential,
              grantsByAssigneeId: _grantsByAssigneeId,
              actualStartStatus: _actualStartStatus,
              actualEndStatus: _actualEndStatus,
              actualStartResetStatus: _actualStartResetStatus,
              actualEndResetStatus: _actualEndResetStatus,
              allowSampleData: _allowSampleData,
              workingDays: _workingDays,
              workDayStartHour: _workDayStartHour,
              workDayEndHour: _workDayEndHour,
              publicHolidays: _publicHolidays,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _addStatus() {
    final candidate = _statusController.text.trim();
    if (candidate.isEmpty) {
      return;
    }
    if (_statuses.any(
      (status) => status.toLowerCase() == candidate.toLowerCase(),
    )) {
      _statusController.clear();
      return;
    }
    setState(() {
      _statuses = [..._statuses, candidate];
      _statusController.clear();
    });
  }

  void _addPhase() {
    final candidate = _phaseNameController.text.trim();
    if (candidate.isEmpty) {
      return;
    }
    final nextNumber = _phases.length + 1;
    setState(() {
      _phases = [
        ..._phases,
        ProjectPhase(
          id: 'PH-${nextNumber.toString().padLeft(3, '0')}',
          name: candidate,
          startDate: null,
          endDate: null,
        ),
      ];
      _phaseNameController.clear();
    });
  }

  void _toggleAssignee(String assigneeId, bool selected) {
    setState(() {
      if (selected) {
        _assignedAssigneeIds.add(assigneeId);
      } else {
        _assignedAssigneeIds.remove(assigneeId);
      }
    });
  }

  void _deletePhase(String phaseId) {
    setState(() {
      _phases = _phases
          .where((phase) => phase.id != phaseId)
          .toList(growable: false);
    });
  }

  Future<void> _pickPhaseDate(String phaseId, bool isStart) async {
    final phase = _phases.firstWhere((item) => item.id == phaseId);
    final initialDate =
        (isStart ? phase.startDate : phase.endDate) ??
        _startDate ??
        DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _phases = _phases
          .map(
            (item) => item.id == phaseId
                ? ProjectPhase(
                    id: item.id,
                    name: item.name,
                    startDate: isStart ? selected : item.startDate,
                    endDate: isStart ? item.endDate : selected,
                  )
                : item,
          )
          .toList(growable: false);
    });
  }

  void _clearPhaseDate(String phaseId, bool isStart) {
    setState(() {
      _phases = _phases
          .map(
            (item) => item.id == phaseId
                ? ProjectPhase(
                    id: item.id,
                    name: item.name,
                    startDate: isStart ? null : item.startDate,
                    endDate: isStart ? item.endDate : null,
                  )
                : item,
          )
          .toList(growable: false);
    });
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      if (isStartDate) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }
}

class _PhaseEditorTile extends StatelessWidget {
  const _PhaseEditorTile({
    required this.phase,
    required this.enabled,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClearStart,
    required this.onClearEnd,
    required this.onDelete,
  });

  final ProjectPhase phase;
  final bool enabled;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClearStart;
  final VoidCallback onClearEnd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    phase.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: enabled ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text('Start: ${_formatDate(phase.startDate)}')),
                TextButton(
                  onPressed: enabled ? onPickStart : null,
                  child: const Text('Pick'),
                ),
                if (phase.startDate != null)
                  TextButton(
                    onPressed: enabled ? onClearStart : null,
                    child: const Text('Clear'),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text('End: ${_formatDate(phase.endDate)}')),
                TextButton(
                  onPressed: enabled ? onPickEnd : null,
                  child: const Text('Pick'),
                ),
                if (phase.endDate != null)
                  TextButton(
                    onPressed: enabled ? onClearEnd : null,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTaskEditorDialog extends StatefulWidget {
  const _ProjectTaskEditorDialog({
    required this.controller,
    required this.project,
    required this.assignees,
    required this.allTasks,
    this.initialTask,
    this.readOnly = false,
  });

  final AppController controller;
  final ProjectModel project;
  final List<AssigneeModel> assignees;
  final List<TaskModel> allTasks;
  final TaskModel? initialTask;
  final bool readOnly;

  @override
  State<_ProjectTaskEditorDialog> createState() =>
      _ProjectTaskEditorDialogState();
}

class _ProjectTaskEditorDialogState extends State<_ProjectTaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _durationController;
  final TextEditingController _predecessorSearchController = TextEditingController();
  late String _status;
  late TaskPriority _priority;
  late bool _isMilestone;
  late Set<String> _predecessorTaskCodes;
  String? _assigneeId;
  String? _phaseId;
  DateTime? _startDate;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialTask?.title ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialTask?.notes ?? '',
    );
    _durationController = TextEditingController(
      text: widget.initialTask?.duration ?? '',
    );
    _durationController.addListener(() => setState(() {}));
    _predecessorSearchController.addListener(() => setState(() {}));
    _status = widget.initialTask?.status ?? widget.project.taskStatuses.first;
    _priority = widget.initialTask?.priority ?? TaskPriority.medium;
    _isMilestone = widget.initialTask?.isMilestone ?? false;
    _predecessorTaskCodes = {
      ...widget.initialTask?.predecessorTaskCodes ?? const <String>[],
    };
    _assigneeId = widget.initialTask?.assigneeId;
    _phaseId = widget.initialTask?.phaseId;
    _dueDate = widget.initialTask?.dueDate;

    // Recompute start date from predecessor end dates so stale stored values
    // are corrected each time the dialog opens.
    if (_predecessorTaskCodes.isNotEmpty) {
      DateTime? latest;
      for (final code in _predecessorTaskCodes) {
        final pred = widget.allTasks.cast<TaskModel?>()
            .firstWhere((t) => t?.taskCode == code, orElse: () => null);
        final predEnd = (pred == null)
            ? null
            : computeTaskEndDate(pred, widget.project) ?? pred.dueDate;
        if (predEnd != null &&
            (latest == null || predEnd.isAfter(latest))) {
          latest = predEnd;
        }
      }
      _startDate = latest ?? widget.initialTask?.startDate;
    } else {
      _startDate = widget.initialTask?.startDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _predecessorSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final predSearchQuery =
        _predecessorSearchController.text.trim().toLowerCase();
    final availablePredecessors = (widget.allTasks
            .where((task) => task.id != widget.initialTask?.id)
            .toList(growable: false)
          ..sort((a, b) => a.taskCode.compareTo(b.taskCode)))
        .where((t) =>
            predSearchQuery.isEmpty ||
            t.taskCode.toLowerCase().contains(predSearchQuery) ||
            t.title.toLowerCase().contains(predSearchQuery))
        .toList(growable: false);
    final endDate = (_startDate != null &&
            _durationController.text.trim().isNotEmpty)
        ? applyTaskDuration(
            _startDate!,
            _durationController.text.trim(),
            workingDays: widget.project.workingDays,
            workDayStartHour: widget.project.workDayStartHour,
            workDayEndHour: widget.project.workDayEndHour,
            publicHolidays: widget.project.publicHolidays,
          )
        : null;
    final previewTaskCode = widget.controller.previewNextTaskCode(
      widget.project.id,
      existingTaskId: widget.initialTask?.id,
    );

    return AlertDialog(
      title: Text(
        widget.initialTask == null
            ? 'New task'
            : widget.readOnly
                ? 'Task Details'
                : 'Edit task',
      ),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width * 0.9).clamp(280.0, 560.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Task ID: $previewTaskCode'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task title'),
                enabled: !widget.readOnly,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: widget.project.taskStatuses
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ),
                    )
                    .toList(growable: false),
                onChanged: widget.readOnly
                    ? null
                    : (value) => setState(() => _status = value!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _assigneeId,
                decoration: const InputDecoration(labelText: 'Assignee'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...widget.assignees.map(
                    (assignee) => DropdownMenuItem<String?>(
                      value: assignee.id,
                      child: Text(assignee.name),
                    ),
                  ),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (value) => setState(() => _assigneeId = value),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _phaseId,
                decoration: const InputDecoration(labelText: 'Phase'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No phase'),
                  ),
                  ...widget.project.phases.map(
                    (phase) => DropdownMenuItem<String?>(
                      value: phase.id,
                      child: Text(phase.name),
                    ),
                  ),
                ],
                onChanged: widget.readOnly
                    ? null
                    : (value) => setState(() => _phaseId = value),
              ),
              const SizedBox(height: 14),
              // ── Start date ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _startDate == null
                          ? 'No start date'
                          : 'Start: ${DateFormat('MMM d, yyyy HH:mm').format(_startDate!)}',
                    ),
                  ),
                  if (!widget.readOnly) ...[
                    TextButton(
                      onPressed: _pickStartDate,
                      child: const Text('Pick'),
                    ),
                    if (_startDate != null)
                      TextButton(
                        onPressed: () => setState(() => _startDate = null),
                        child: const Text('Clear'),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              // ── Duration ──────────────────────────────────────────────
              TextField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  hintText: 'e.g. 5d',
                  helperText: '5 = 5 hrs · 5d = days · 2w = weeks · 1mo = months',
                ),
                enabled: !widget.readOnly,
              ),
              const SizedBox(height: 8),
              // ── End date (derived) ────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  endDate == null
                      ? 'End date: —'
                      : 'End date: ${DateFormat('MMM d, yyyy HH:mm').format(endDate)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TaskPriority>(
                      initialValue: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: TaskPriority.values
                          .map(
                            (priority) => DropdownMenuItem<TaskPriority>(
                              value: priority,
                              child: Text(priority.name.toUpperCase()),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: widget.readOnly
                          ? null
                          : (value) => setState(() => _priority = value!),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Milestone'),
                      value: _isMilestone,
                      onChanged: widget.readOnly
                          ? null
                          : (value) => setState(() => _isMilestone = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                minLines: 3,
                maxLines: 5,
                enabled: !widget.readOnly,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Predecessors',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _predecessorSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by ID or title…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: predSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => _predecessorSearchController.clear(),
                        )
                      : null,
                  isDense: true,
                ),
                enabled: !widget.readOnly,
              ),
              const SizedBox(height: 8),
              if (widget.allTasks
                      .where((t) => t.id != widget.initialTask?.id)
                      .isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No candidate predecessors in this project yet.'),
                )
              else if (availablePredecessors.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No tasks match the search.'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availablePredecessors
                      .map(
                        (task) => FilterChip(
                          label: Text('${task.taskCode} - ${task.title}'),
                          selected: _predecessorTaskCodes.contains(
                            task.taskCode,
                          ),
                          onSelected: widget.readOnly
                              ? null
                              : (selected) => _onPredecessorToggled(
                                    task.taskCode,
                                    selected,
                                  ),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? 'No target date selected'
                          : 'Target ${DateFormat('MMM d, yyyy HH:mm').format(_dueDate!)}',
                    ),
                  ),
                  if (!widget.readOnly) ...[
                    TextButton(
                      onPressed: _pickDate,
                      child: const Text('Pick date'),
                    ),
                    if (_dueDate != null)
                      TextButton(
                        onPressed: () => setState(() => _dueDate = null),
                        child: const Text('Clear'),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: widget.readOnly
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await widget.controller.saveTask(
                    title: _titleController.text,
                    notes: _notesController.text,
                    projectId: widget.project.id,
                    status: _status,
                    priority: _priority,
                    startDate: _startDate,
                    duration: _durationController.text.trim(),
                    dueDate: _dueDate,
                    isMilestone: _isMilestone,
                    predecessorTaskCodes: _predecessorTaskCodes.toList(
                      growable: false,
                    ),
                    phaseId: _phaseId,
                    assigneeId: _assigneeId,
                    taskId: widget.initialTask?.id,
                    actualStartDate: _status == widget.project.actualStartStatus
                        ? DateTime.now()
                        : _status == widget.project.actualStartResetStatus
                            ? null
                            : widget.initialTask?.actualStartDate,
                    actualEndDate: _status == widget.project.actualEndStatus
                        ? DateTime.now()
                        : _status == widget.project.actualEndResetStatus
                            ? null
                            : widget.initialTask?.actualEndDate,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Save'),
              ),
            ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await _pickDateTime(context, _dueDate);
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickDateTime(context, _startDate);
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  void _onPredecessorToggled(String taskCode, bool selected) {
    setState(() {
      if (selected) {
        _predecessorTaskCodes.add(taskCode);
      } else {
        _predecessorTaskCodes.remove(taskCode);
      }
      if (_predecessorTaskCodes.isEmpty) {
        _startDate = null;
        return;
      }
      // Auto-fill start date = max(endDate ?? dueDate of all selected predecessors)
      DateTime? latest;
      for (final code in _predecessorTaskCodes) {
        final pred = widget.allTasks
            .cast<TaskModel?>()
            .firstWhere((t) => t?.taskCode == code, orElse: () => null);
        final predEnd = (pred == null)
            ? null
            : computeTaskEndDate(pred, widget.project) ?? pred.dueDate;
        if (predEnd != null &&
            (latest == null || predEnd.isAfter(latest))) {
          latest = predEnd;
        }
      }
      if (latest != null) _startDate = latest;
    });
  }
}

class _GrantCheckbox extends StatelessWidget {
  const _GrantCheckbox({
    required this.label,
    required this.grant,
    required this.grants,
    required this.onChanged,
  });

  final String label;
  final String grant;
  final Set<String> grants;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: grants.contains(grant),
          onChanged: (checked) {
            final updated = Set<String>.from(grants);
            if (checked == true) {
              updated.add(grant);
            } else {
              updated.remove(grant);
            }
            onChanged(updated);
          },
        ),
        Text(label),
      ],
    );
  }
}

class _AssigneeSelectionGroup extends StatelessWidget {
  const _AssigneeSelectionGroup({
    required this.label,
    required this.assignees,
    required this.selectedIds,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final List<AssigneeModel> assignees;
  final Set<String> selectedIds;
  final bool enabled;
  final void Function(String assigneeId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (assignees.isEmpty)
          Text('No $label available yet.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: assignees
                .map(
                  (assignee) => FilterChip(
                    label: Text('${assignee.name} (${assignee.email})'),
                    selected: selectedIds.contains(assignee.id),
                    onSelected: enabled
                        ? (selected) => onChanged(assignee.id, selected)
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

String _tabLabel(_ProjectWorkspaceTab tab) {
  switch (tab) {
    case _ProjectWorkspaceTab.overview:
      return 'Overview';
    case _ProjectWorkspaceTab.tasks:
      return 'Tasks';
    case _ProjectWorkspaceTab.issues:
      return 'Issues';
    case _ProjectWorkspaceTab.risks:
      return 'Risks';
    case _ProjectWorkspaceTab.actions:
      return 'Actions';
    case _ProjectWorkspaceTab.decisions:
      return 'Decisions';
    case _ProjectWorkspaceTab.kanban:
      return 'Kanban Board';
    case _ProjectWorkspaceTab.calendar:
      return 'Calendar View';
  }
}

String _recordLabel(ProjectRecordType type) {
  switch (type) {
    case ProjectRecordType.issue:
      return 'Issue';
    case ProjectRecordType.risk:
      return 'Risk';
    case ProjectRecordType.action:
      return 'Action';
    case ProjectRecordType.decision:
      return 'Decision';
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Not set';
  }
  return DateFormat('MMM d, yyyy').format(value);
}

/// Formats a date+time value for task start / target date display.
String _formatDateTime(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('MMM d, yyyy HH:mm').format(value);
}

/// Shows a date picker followed by a time picker and returns the combined
/// [DateTime], or `null` if the user cancels either step.
Future<DateTime?> _pickDateTime(
  BuildContext context,
  DateTime? initial,
) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: initial != null
        ? TimeOfDay.fromDateTime(initial)
        : const TimeOfDay(hour: 9, minute: 0),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
