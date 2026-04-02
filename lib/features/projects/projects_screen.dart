import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_controller.dart';
import '../../core/models/assignee_model.dart';
import '../../core/models/project_model.dart';
import '../../core/models/task_model.dart';
import '../../shared/widgets/gantt_chart_view.dart';
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
                          width: 360,
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
              }) {
                return controller.saveProject(
                  title: title,
                  description: description,
                  colorValue: colorValue,
                  timezone: timezone,
                  startDate: startDate,
                  endDate: endDate,
                  phases: phases,
                  taskStatuses: taskStatuses,
                  assignedAssigneeIds: assignedAssigneeIds,
                  projectId: project?.id,
                );
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
            InkWell(
              onTap: onOpenWorkspace,
              child: Text(
                project.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accent,
                  decoration: TextDecoration.underline,
                ),
              ),
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
                    Text(
                      '${project.projectCode} Workspace',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              if (canEdit && _activeTab == _ProjectWorkspaceTab.overview)
                OutlinedButton.icon(
                  onPressed: widget.onEditProject,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit project'),
                ),
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
              canEdit: canEdit,
            ),
            _ProjectWorkspaceTab.risks => _ProjectRecordTab(
              controller: controller,
              project: project,
              type: ProjectRecordType.risk,
              entries: project.riskLog,
              assignees: projectAssignees,
              canEdit: canEdit,
            ),
            _ProjectWorkspaceTab.actions => _ProjectRecordTab(
              controller: controller,
              project: project,
              type: ProjectRecordType.action,
              entries: project.actionLog,
              assignees: projectAssignees,
              canEdit: canEdit,
            ),
            _ProjectWorkspaceTab.decisions => _ProjectRecordTab(
              controller: controller,
              project: project,
              type: ProjectRecordType.decision,
              entries: project.decisionLog,
              assignees: projectAssignees,
              canEdit: canEdit,
            ),
            _ProjectWorkspaceTab.kanban => _ProjectKanbanTab(
              controller: controller,
              project: project,
              tasks: projectTasks,
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
        Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            SizedBox(
              width: 460,
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
              width: 460,
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
                                trailing: Text(_formatDate(task.dueDate)),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _TaskSortOption { dueDateAsc, dueDateDesc, titleAsc, statusAsc }

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
  String? _statusFilter;
  String? _phaseFilter;
  String? _assigneeFilter;
  _TaskSortOption _sortOption = _TaskSortOption.dueDateAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filteredTasks = widget.tasks
        .where((task) {
          final query = _searchController.text.trim().toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              task.taskCode.toLowerCase().contains(query) ||
              task.title.toLowerCase().contains(query) ||
              task.notes.toLowerCase().contains(query);
          final matchesStatus =
              _statusFilter == null || task.status == _statusFilter;
          final matchesPhase =
              _phaseFilter == null || task.phaseId == _phaseFilter;
          final matchesAssignee =
              _assigneeFilter == null || task.assigneeId == _assigneeFilter;
          return matchesQuery &&
              matchesStatus &&
              matchesPhase &&
              matchesAssignee;
        })
        .toList(growable: false);
    filteredTasks.sort((left, right) {
      switch (_sortOption) {
        case _TaskSortOption.dueDateAsc:
          return (left.dueDate ?? DateTime(2100)).compareTo(
            right.dueDate ?? DateTime(2100),
          );
        case _TaskSortOption.dueDateDesc:
          return (right.dueDate ?? DateTime(1900)).compareTo(
            left.dueDate ?? DateTime(1900),
          );
        case _TaskSortOption.titleAsc:
          return left.title.toLowerCase().compareTo(right.title.toLowerCase());
        case _TaskSortOption.statusAsc:
          return left.status.toLowerCase().compareTo(
            right.status.toLowerCase(),
          );
      }
    });

    return SectionCard(
      title: 'Project Tasks',
      subtitle:
          'Filter, sort, and manage the tasks that belong only to this project.',
      child: widget.tasks.isEmpty
          ? const Text('No tasks in this project yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search tasks',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All statuses'),
                          ),
                          ...widget.project.taskStatuses.map(
                            (status) => DropdownMenuItem<String?>(
                              value: status,
                              child: Text(status),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _phaseFilter,
                        decoration: const InputDecoration(labelText: 'Phase'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All phases'),
                          ),
                          ...widget.project.phases.map(
                            (phase) => DropdownMenuItem<String?>(
                              value: phase.id,
                              child: Text(phase.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _phaseFilter = value),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _assigneeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Assignee',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All assignees'),
                          ),
                          ...widget.assignees.map(
                            (assignee) => DropdownMenuItem<String?>(
                              value: assignee.id,
                              child: Text(assignee.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _assigneeFilter = value),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<_TaskSortOption>(
                        initialValue: _sortOption,
                        decoration: const InputDecoration(labelText: 'Sort by'),
                        items: const [
                          DropdownMenuItem(
                            value: _TaskSortOption.dueDateAsc,
                            child: Text('Due date ascending'),
                          ),
                          DropdownMenuItem(
                            value: _TaskSortOption.dueDateDesc,
                            child: Text('Due date descending'),
                          ),
                          DropdownMenuItem(
                            value: _TaskSortOption.titleAsc,
                            child: Text('Title'),
                          ),
                          DropdownMenuItem(
                            value: _TaskSortOption.statusAsc,
                            child: Text('Status'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _sortOption = value!),
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
                const SizedBox(height: 16),
                if (filteredTasks.isEmpty)
                  const Text('No tasks match the current filters.')
                else
                  ...filteredTasks.map(
                    (task) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${task.taskCode} - ${task.title}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Chip(label: Text(task.status)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Assignee: ${controller.assigneeName(task.assigneeId)}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phase: ${controller.phaseName(widget.project.id, task.phaseId)}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Predecessors: ${controller.predecessorSummaries(task).join(', ').ifEmpty('None')}',
                            ),
                            const SizedBox(height: 4),
                            Text('Due: ${_formatDate(task.dueDate)}'),
                            const SizedBox(height: 4),
                            Text(
                              'Milestone: ${task.isMilestone ? 'Yes' : 'No'} • Last changed: ${DateFormat('MMM d, yyyy HH:mm').format(task.lastChangedAt)}',
                            ),
                            if (task.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(task.notes),
                            ],
                            if (widget.canEdit) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _openTaskEditor(context, task: task),
                                    child: const Text('Edit'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        widget.controller.deleteTask(task.id),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _openTaskEditor(BuildContext context, {TaskModel? task}) {
    return showDialog<void>(
      context: context,
      builder: (context) => _ProjectTaskEditorDialog(
        controller: widget.controller,
        project: widget.project,
        assignees: widget.assignees,
        allTasks: widget.tasks,
        initialTask: task,
      ),
    );
  }
}

enum _RecordSortOption { newest, oldest, status, id }

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
  String? _statusFilter;
  String? _assigneeFilter;
  _RecordSortOption _sortOption = _RecordSortOption.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final entries = widget.entries
        .where((entry) {
          final query = _searchController.text.trim().toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              entry.id.toLowerCase().contains(query) ||
              entry.description.toLowerCase().contains(query) ||
              entry.comments.toLowerCase().contains(query);
          final matchesStatus =
              _statusFilter == null || entry.status == _statusFilter;
          final matchesAssignee =
              _assigneeFilter == null || entry.assigneeId == _assigneeFilter;
          return matchesQuery && matchesStatus && matchesAssignee;
        })
        .toList(growable: false);
    entries.sort((left, right) {
      switch (_sortOption) {
        case _RecordSortOption.newest:
          return right.createdAt.compareTo(left.createdAt);
        case _RecordSortOption.oldest:
          return left.createdAt.compareTo(right.createdAt);
        case _RecordSortOption.status:
          return left.status.toLowerCase().compareTo(
            right.status.toLowerCase(),
          );
        case _RecordSortOption.id:
          return left.id.toLowerCase().compareTo(right.id.toLowerCase());
      }
    });

    return SectionCard(
      title: '${_recordLabel(widget.type)} Log',
      subtitle:
          'Filter, sort, download, and upload ${_recordLabel(widget.type).toLowerCase()} entries for this project.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText:
                        'Search ${_recordLabel(widget.type).toLowerCase()}s',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...widget.entries
                        .map((entry) => entry.status)
                        .toSet()
                        .map(
                          (status) => DropdownMenuItem<String?>(
                            value: status,
                            child: Text(status),
                          ),
                        ),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _assigneeFilter,
                  decoration: const InputDecoration(labelText: 'Assignee'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All assignees'),
                    ),
                    ...widget.assignees.map(
                      (assignee) => DropdownMenuItem<String?>(
                        value: assignee.id,
                        child: Text(assignee.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _assigneeFilter = value),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<_RecordSortOption>(
                  initialValue: _sortOption,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: const [
                    DropdownMenuItem(
                      value: _RecordSortOption.newest,
                      child: Text('Newest first'),
                    ),
                    DropdownMenuItem(
                      value: _RecordSortOption.oldest,
                      child: Text('Oldest first'),
                    ),
                    DropdownMenuItem(
                      value: _RecordSortOption.status,
                      child: Text('Status'),
                    ),
                    DropdownMenuItem(
                      value: _RecordSortOption.id,
                      child: Text('ID'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _sortOption = value!),
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
          entries.isEmpty
              ? Text(
                  'No ${_recordLabel(widget.type).toLowerCase()} entries match the current filters.',
                )
              : Column(
                  children: entries
                      .map(
                        (entry) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.id,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    Chip(label: Text(entry.status)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_recordLabel(widget.type)} Description',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(entry.description),
                                const SizedBox(height: 12),
                                Text(
                                  'Assignee: ${controller.assigneeName(entry.assigneeId)}',
                                ),
                                const SizedBox(height: 4),
                                if (widget.type == ProjectRecordType.risk)
                                  Text(
                                    'Probability: ${entry.probability?.name.toUpperCase() ?? 'Unspecified'}',
                                  ),
                                if (widget.type == ProjectRecordType.risk)
                                  const SizedBox(height: 4),
                                Text(
                                  'Comments: ${entry.comments.isEmpty ? 'None' : entry.comments}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Created: ${DateFormat('MMM d, yyyy HH:mm').format(entry.createdAt)}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
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

class _ProjectKanbanTab extends StatelessWidget {
  const _ProjectKanbanTab({
    required this.controller,
    required this.project,
    required this.tasks,
  });

  final AppController controller;
  final ProjectModel project;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: project.taskStatuses
            .map(
              (status) => Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: SectionCard(
                  title: status,
                  subtitle: 'Tasks currently in this workflow column.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final task in tasks.where(
                        (task) => task.status == status,
                      ))
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${task.taskCode} - ${task.title}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(controller.assigneeName(task.assigneeId)),
                                const SizedBox(height: 4),
                                Text('Due: ${_formatDate(task.dueDate)}'),
                              ],
                            ),
                          ),
                        ),
                      if (!tasks.any((task) => task.status == status))
                        const Text('No tasks in this status.'),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
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
          .where((task) => task.dueDate != null)
          .map(
            (task) => GanttChartEntry(
              label: '${task.taskCode} - ${task.title}',
              subtitle:
                  'Task • ${controller.phaseName(project.id, task.phaseId)} • ${task.status}',
              start: task.dueDate,
              end: task.dueDate,
              color: task.isMilestone
                  ? const Color(0xFFD96C45)
                  : const Color(0xFF2E5BFF),
            ),
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
          : GanttChartView(entries: entries, labelWidth: 420),
    );
  }
}

class _ProjectRecordEditorDialog extends StatefulWidget {
  const _ProjectRecordEditorDialog({
    required this.type,
    required this.assignees,
    required this.onSave,
  });

  final ProjectRecordType type;
  final List<AssigneeModel> assignees;
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
    _commentsController = TextEditingController();
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
        width: 500,
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
            TextField(
              controller: _commentsController,
              decoration: const InputDecoration(labelText: 'Comments'),
              minLines: 2,
              maxLines: 4,
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
            await widget.onSave(
              assigneeId: _selectedAssigneeId,
              description: _descriptionController.text,
              comments: _commentsController.text,
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
  })
  onSave;
  final List<AssigneeModel> assignees;
  final ProjectModel? initialProject;
  final List<int> colors;
  final List<String> timezones;
  final String nextProjectCode;
  final bool canManageStatuses;

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
  DateTime? _startDate;
  DateTime? _endDate;

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
    _startDate = widget.initialProject?.startDate;
    _endDate = widget.initialProject?.endDate;
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
        width: 540,
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
  });

  final AppController controller;
  final ProjectModel project;
  final List<AssigneeModel> assignees;
  final List<TaskModel> allTasks;
  final TaskModel? initialTask;

  @override
  State<_ProjectTaskEditorDialog> createState() =>
      _ProjectTaskEditorDialogState();
}

class _ProjectTaskEditorDialogState extends State<_ProjectTaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late String _status;
  late TaskPriority _priority;
  late bool _isMilestone;
  late Set<String> _predecessorTaskCodes;
  String? _assigneeId;
  String? _phaseId;
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
    _status = widget.initialTask?.status ?? widget.project.taskStatuses.first;
    _priority = widget.initialTask?.priority ?? TaskPriority.medium;
    _isMilestone = widget.initialTask?.isMilestone ?? false;
    _predecessorTaskCodes = {
      ...widget.initialTask?.predecessorTaskCodes ?? const <String>[],
    };
    _assigneeId = widget.initialTask?.assigneeId;
    _phaseId = widget.initialTask?.phaseId;
    _dueDate = widget.initialTask?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availablePredecessors = widget.allTasks
        .where((task) => task.id != widget.initialTask?.id)
        .toList(growable: false);
    final previewTaskCode = widget.controller.previewNextTaskCode(
      widget.project.id,
      existingTaskId: widget.initialTask?.id,
    );

    return AlertDialog(
      title: Text(widget.initialTask == null ? 'New task' : 'Edit task'),
      content: SizedBox(
        width: 560,
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
                onChanged: (value) => setState(() => _status = value!),
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
                onChanged: (value) => setState(() => _assigneeId = value),
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
                onChanged: (value) => setState(() => _phaseId = value),
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
                      onChanged: (value) => setState(() => _priority = value!),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Milestone'),
                      value: _isMilestone,
                      onChanged: (value) =>
                          setState(() => _isMilestone = value),
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
              if (availablePredecessors.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No candidate predecessors in this project yet.'),
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
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _predecessorTaskCodes.add(task.taskCode);
                              } else {
                                _predecessorTaskCodes.remove(task.taskCode);
                              }
                            });
                          },
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
                          ? 'No due date selected'
                          : 'Due ${DateFormat('MMM d, yyyy').format(_dueDate!)}',
                    ),
                  ),
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
              ),
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
            await widget.controller.saveTask(
              title: _titleController.text,
              notes: _notesController.text,
              projectId: widget.project.id,
              status: _status,
              priority: _priority,
              dueDate: _dueDate,
              isMilestone: _isMilestone,
              predecessorTaskCodes: _predecessorTaskCodes.toList(
                growable: false,
              ),
              phaseId: _phaseId,
              assigneeId: _assigneeId,
              taskId: widget.initialTask?.id,
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
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _dueDate ?? now,
    );
    if (selected != null) {
      setState(() => _dueDate = selected);
    }
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
    return SizedBox(
      width: 160,
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

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
