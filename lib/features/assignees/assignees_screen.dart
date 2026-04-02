import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models/assignee_model.dart';
import '../../core/models/project_model.dart';
import '../../shared/widgets/section_card.dart';

class AssigneesScreen extends StatelessWidget {
  const AssigneesScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
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
                      'Assignees',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage people separately with role, designation, work hours, and project assignments.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: controller.canManageAssignees
                    ? () => _openEditor(context)
                    : null,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('New assignee'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          controller.assignees.isEmpty
              ? const SectionCard(
                  title: 'No assignees yet',
                  subtitle:
                      'Create assignees here before assigning them to tasks.',
                  child: Text(
                    'Each assignee can belong to one or more projects.',
                  ),
                )
              : Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: controller.assignees
                      .map((assignee) {
                        return SizedBox(
                          width: 340,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignee.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(assignee.email),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Role: ${controller.roleLabel(assignee.role)}',
                                  ),
                                  if (assignee.designation.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Designation: ${assignee.designation}',
                                    ),
                                  ],
                                  if (assignee.workHours.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Work hours: ${assignee.workHours}'),
                                  ],
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: assignee.projectIds.isEmpty
                                        ? const [
                                            Chip(
                                              label: Text(
                                                'No project assignments',
                                              ),
                                            ),
                                          ]
                                        : assignee.projectIds
                                              .map(
                                                (projectId) => Chip(
                                                  label: Text(
                                                    controller.projectCode(
                                                      projectId,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: controller.canManageAssignees
                                            ? () => _openEditor(
                                                context,
                                                assignee: assignee,
                                              )
                                            : null,
                                        child: const Text('Edit'),
                                      ),
                                      TextButton(
                                        onPressed: controller.canManageAssignees
                                            ? () => controller.deleteAssignee(
                                                assignee.id,
                                              )
                                            : null,
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {AssigneeModel? assignee}) {
    return showDialog<void>(
      context: context,
      builder: (context) => _AssigneeEditorDialog(
        projects: controller.projects,
        initialAssignee: assignee,
        onSave:
            ({
              required name,
              required email,
              required role,
              required designation,
              required workHours,
              required projectIds,
            }) {
              return controller.saveAssignee(
                name: name,
                email: email,
                role: role,
                designation: designation,
                workHours: workHours,
                projectIds: projectIds,
                assigneeId: assignee?.id,
              );
            },
      ),
    );
  }
}

class _AssigneeEditorDialog extends StatefulWidget {
  const _AssigneeEditorDialog({
    required this.projects,
    required this.onSave,
    this.initialAssignee,
  });

  final List<ProjectModel> projects;
  final AssigneeModel? initialAssignee;
  final Future<void> Function({
    required String name,
    required String email,
    required AssigneeRole role,
    required String designation,
    required String workHours,
    required List<String> projectIds,
  })
  onSave;

  @override
  State<_AssigneeEditorDialog> createState() => _AssigneeEditorDialogState();
}

class _AssigneeEditorDialogState extends State<_AssigneeEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _designationController;
  late final TextEditingController _workHoursController;
  late Set<String> _projectIds;
  late AssigneeRole _role;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialAssignee?.name ?? '',
    );
    _emailController = TextEditingController(
      text: widget.initialAssignee?.email ?? '',
    );
    _designationController = TextEditingController(
      text: widget.initialAssignee?.designation ?? '',
    );
    _workHoursController = TextEditingController(
      text: widget.initialAssignee?.workHours ?? '',
    );
    _projectIds = {...?widget.initialAssignee?.projectIds};
    _role = widget.initialAssignee?.role ?? AssigneeRole.projectUser;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _designationController.dispose();
    _workHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialAssignee == null ? 'New assignee' : 'Edit assignee',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<AssigneeRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: AssigneeRole.values
                    .map(
                      (role) => DropdownMenuItem<AssigneeRole>(
                        value: role,
                        child: Text(_labelForRole(role)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _role = value!),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _designationController,
                decoration: const InputDecoration(labelText: 'Designation'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _workHoursController,
                decoration: const InputDecoration(
                  labelText: 'Work hours',
                  hintText: 'Mon-Fri, 9:00-17:00',
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Project assignments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.projects.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Create projects first, then attach assignees.'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.projects
                      .map(
                        (project) => FilterChip(
                          label: Text(project.projectCode),
                          selected: _projectIds.contains(project.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _projectIds.add(project.id);
                              } else {
                                _projectIds.remove(project.id);
                              }
                            });
                          },
                        ),
                      )
                      .toList(growable: false),
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
              name: _nameController.text,
              email: _emailController.text,
              role: _role,
              designation: _designationController.text,
              workHours: _workHoursController.text,
              projectIds: _projectIds.toList(growable: false),
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

  String _labelForRole(AssigneeRole role) {
    switch (role) {
      case AssigneeRole.superAdmin:
        return 'SuperAdmin';
      case AssigneeRole.projectAdmin:
        return 'Project Admin';
      case AssigneeRole.projectUser:
        return 'Project User';
      case AssigneeRole.watcher:
        return 'Watcher';
    }
  }
}
