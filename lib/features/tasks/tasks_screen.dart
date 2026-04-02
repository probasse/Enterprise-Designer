import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_controller.dart';
import '../../core/models/assignee_model.dart';
import '../../core/models/project_model.dart';
import '../../core/models/task_model.dart';
import '../../shared/widgets/section_card.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final filteredTasks = controller.filteredTasks;
    final availableStatuses = _availableStatusesForFilter();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tasks now use auto-generated IDs, project-specific statuses, and multi-task predecessor chains.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: controller.projects.isEmpty
                    ? null
                    : () => _openTaskEditor(context),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('New task'),
              ),
              OutlinedButton.icon(
                onPressed: controller.tasks.isEmpty
                    ? null
                    : controller.exportTasksToCsv,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export CSV'),
              ),
              OutlinedButton.icon(
                onPressed: controller.importTasksFromCsv,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Import CSV'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Filters',
            subtitle: 'Narrow the task list to what matters right now.',
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    initialValue: controller.taskFilter.projectId,
                    decoration: const InputDecoration(labelText: 'Project'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All projects'),
                      ),
                      ...controller.projects.map(
                        (project) => DropdownMenuItem<String?>(
                          value: project.id,
                          child: Text(project.projectCode),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      controller.setTaskFilter(
                        controller.taskFilter.copyWith(
                          projectId: value,
                          clearProject: value == null,
                          clearStatus: true,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    initialValue: controller.taskFilter.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      ...availableStatuses.map(
                        (status) => DropdownMenuItem<String?>(
                          value: status,
                          child: Text(status),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      controller.setTaskFilter(
                        controller.taskFilter.copyWith(
                          status: value,
                          clearStatus: value == null,
                        ),
                      );
                    },
                  ),
                ),
                FilterChip(
                  label: const Text('Upcoming only'),
                  selected: controller.taskFilter.upcomingOnly,
                  onSelected: (selected) => controller.setTaskFilter(
                    controller.taskFilter.copyWith(upcomingOnly: selected),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          controller.projects.isEmpty
              ? const SectionCard(
                  title: 'Projects required',
                  subtitle: 'Create a project before adding tasks.',
                  child: Text(
                    'Tasks are attached to projects and inherit their status workflow.',
                  ),
                )
              : filteredTasks.isEmpty
              ? const SectionCard(
                  title: 'No matching tasks',
                  subtitle: 'Try creating a task or relaxing the filters.',
                  child: Text(
                    'Imported tasks and due dates will appear here too.',
                  ),
                )
              : Column(
                  children: filteredTasks
                      .map((task) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _TaskTile(
                            task: task,
                            projectCode: controller.projectCode(task.projectId),
                            assigneeName: controller.assigneeName(
                              task.assigneeId,
                            ),
                            phaseName: controller.phaseName(
                              task.projectId,
                              task.phaseId,
                            ),
                            predecessors: controller.predecessorSummaries(task),
                            onEdit: () => _openTaskEditor(context, task: task),
                            onDelete: () => controller.deleteTask(task.id),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
        ],
      ),
    );
  }

  List<String> _availableStatusesForFilter() {
    if (controller.taskFilter.projectId != null) {
      return controller.taskStatusesForProject(
        controller.taskFilter.projectId!,
      );
    }
    final all = <String>{};
    for (final project in controller.projects) {
      all.addAll(project.taskStatuses);
    }
    return all.toList()..sort();
  }

  Future<void> _openTaskEditor(BuildContext context, {TaskModel? task}) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return _TaskEditorDialog(
          controller: controller,
          projects: controller.projects,
          assignees: controller.assignees,
          allTasks: controller.tasks,
          initialTask: task,
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.projectCode,
    required this.assigneeName,
    required this.phaseName,
    required this.predecessors,
    required this.onEdit,
    required this.onDelete,
  });

  final TaskModel task;
  final String projectCode;
  final String assigneeName;
  final String phaseName;
  final List<String> predecessors;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 130,
              decoration: BoxDecoration(
                color: _priorityColor(task.priority),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Chip(label: Text(task.taskCode)),
                      Text(task.title, style: theme.textTheme.titleLarge),
                      Chip(label: Text(projectCode)),
                      Chip(label: Text(task.status)),
                      if (task.isMilestone)
                        const Chip(label: Text('Milestone')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(task.notes.isEmpty ? 'No notes yet.' : task.notes),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      Text(
                        task.dueDate == null
                            ? 'No due date'
                            : 'Due ${DateFormat('EEE, MMM d').format(task.dueDate!)}',
                      ),
                      Text('Assignee: $assigneeName'),
                      Text('Phase: $phaseName'),
                      Text(
                        'Last changed: ${DateFormat('MMM d, yyyy HH:mm').format(task.lastChangedAt)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    predecessors.isEmpty
                        ? 'Predecessors: None'
                        : 'Predecessors: ${predecessors.join(', ')}',
                  ),
                  if (task.changeLog.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Recent changes', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    ...task.changeLog.reversed
                        .take(3)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${DateFormat('MMM d, HH:mm').format(entry.changedAt)} - ${entry.description}',
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                TextButton(onPressed: onEdit, child: const Text('Edit')),
                TextButton(onPressed: onDelete, child: const Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
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
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({
    required this.controller,
    required this.projects,
    required this.assignees,
    required this.allTasks,
    this.initialTask,
  });

  final AppController controller;
  final List<ProjectModel> projects;
  final List<AssigneeModel> assignees;
  final List<TaskModel> allTasks;
  final TaskModel? initialTask;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late String _projectId;
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
    _projectId = widget.initialTask?.projectId ?? widget.projects.first.id;
    _status =
        widget.initialTask?.status ??
        widget.controller.taskStatusesForProject(_projectId).first;
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
    final projectStatuses = widget.controller.taskStatusesForProject(
      _projectId,
    );
    final projectPhases = widget.controller.phasesForProject(_projectId);
    if (!projectStatuses.contains(_status)) {
      _status = projectStatuses.first;
    }
    if (_phaseId != null &&
        !projectPhases.any((phase) => phase.id == _phaseId)) {
      _phaseId = null;
    }

    final availableAssignees = widget.assignees
        .where((assignee) {
          return assignee.projectIds.isEmpty ||
              assignee.projectIds.contains(_projectId);
        })
        .toList(growable: false);

    final availablePredecessors = widget.allTasks
        .where((task) {
          return task.id != widget.initialTask?.id &&
              task.projectId == _projectId;
        })
        .toList(growable: false);

    final previewTaskCode = widget.controller.previewNextTaskCode(
      _projectId,
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
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Project'),
                items: widget.projects
                    .map(
                      (project) => DropdownMenuItem<String>(
                        value: project.id,
                        child: Text(
                          '${project.projectCode} - ${project.title}',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() {
                    _projectId = value!;
                    _predecessorTaskCodes.clear();
                    final statuses = widget.controller.taskStatusesForProject(
                      _projectId,
                    );
                    _status = statuses.first;
                    if (!availableAssignees.any(
                      (assignee) => assignee.id == _assigneeId,
                    )) {
                      _assigneeId = null;
                    }
                    if (!widget.controller
                        .phasesForProject(_projectId)
                        .any((phase) => phase.id == _phaseId)) {
                      _phaseId = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: projectStatuses
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
                  ...availableAssignees.map(
                    (assignee) => DropdownMenuItem<String?>(
                      value: assignee.id,
                      child: Text('${assignee.name} (${assignee.role.name})'),
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
                  ...projectPhases.map(
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
              availablePredecessors.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No candidate predecessors in this project yet.',
                      ),
                    )
                  : Wrap(
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
              projectId: _projectId,
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
