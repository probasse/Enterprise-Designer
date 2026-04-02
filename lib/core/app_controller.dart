import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/app_view_state.dart';
import 'models/assignee_model.dart';
import 'models/firebase_runtime_config.dart';
import 'models/project_model.dart';
import 'models/task_filter.dart';
import 'models/task_model.dart';
import 'services/assignee_repository.dart';
import 'services/auth_service.dart';
import 'services/firebase_credentials_store.dart';
import 'services/csv_codec.dart';
import 'services/csv_port_service.dart';
import 'services/local_config_store.dart';
import 'services/project_repository.dart';
import 'services/runtime_firebase_service.dart';
import 'services/task_repository.dart';

class AppController extends ChangeNotifier {
  AppController({
    required LocalConfigStore localConfigStore,
    required RuntimeFirebaseService runtimeFirebaseService,
    FirebaseCredentialsStore? firebaseCredentialsStore,
    CsvCodecService? csvCodecService,
    CsvPortService? csvPortService,
  }) : _localConfigStore = localConfigStore,
       _runtimeFirebaseService = runtimeFirebaseService,
       _firebaseCredentialsStore =
           firebaseCredentialsStore ?? FirebaseCredentialsStore(),
       _csvCodecService = csvCodecService ?? CsvCodecService(),
       _csvPortService = csvPortService ?? createCsvPortService();

  final LocalConfigStore _localConfigStore;
  final RuntimeFirebaseService _runtimeFirebaseService;
  final FirebaseCredentialsStore _firebaseCredentialsStore;
  final CsvCodecService _csvCodecService;
  final CsvPortService _csvPortService;

  AppViewState _viewState = const AppViewState();
  AppViewState get viewState => _viewState;

  FirebaseRuntimeConfig? _runtimeConfig;
  FirebaseRuntimeConfig? get runtimeConfig => _runtimeConfig;

  AuthService? _authService;
  User? _user;
  User? get user => _user;

  List<ProjectModel> _projects = const [];
  List<ProjectModel> get projects => _visibleProjects;

  List<TaskModel> _tasks = const [];
  List<TaskModel> get tasks => _visibleTasks;

  List<AssigneeModel> _assignees = const [];
  List<AssigneeModel> get assignees => _visibleAssignees;

  TaskFilter _taskFilter = const TaskFilter();
  TaskFilter get taskFilter => _taskFilter;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _flashMessage;
  String? get flashMessage => _flashMessage;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<ProjectModel>>? _projectSubscription;
  StreamSubscription<List<TaskModel>>? _taskSubscription;
  StreamSubscription<List<AssigneeModel>>? _assigneeSubscription;

  Future<void> bootstrap() async {
    _setViewState(_viewState.copyWith(isBootstrapping: true, clearError: true));

    try {
      final bundledConfig = await _firebaseCredentialsStore.load();
      if (bundledConfig != null) {
        await _initializeFirebase(bundledConfig, persist: true);
        return;
      }

      final savedConfig = await _localConfigStore.load();
      if (savedConfig == null) {
        _runtimeConfig = null;
        _setViewState(
          _viewState.copyWith(
            isBootstrapping: false,
            isFirebaseConfigured: false,
            isAuthenticated: false,
            clearError: true,
          ),
        );
        return;
      }

      await _initializeFirebase(savedConfig, persist: false);
    } catch (error) {
      _setViewState(
        _viewState.copyWith(
          isBootstrapping: false,
          isFirebaseConfigured: false,
          isAuthenticated: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> configureFirebase(FirebaseRuntimeConfig config) async {
    await _withBusy(() async {
      await _initializeFirebase(config, persist: true);
      _flashMessage = 'Firebase project connected.';
    });
  }

  Future<void> resetFirebase() async {
    await _withBusy(() async {
      await _taskSubscription?.cancel();
      await _projectSubscription?.cancel();
      await _authSubscription?.cancel();
      await _assigneeSubscription?.cancel();
      _tasks = const [];
      _projects = const [];
      _assignees = const [];
      _user = null;
      _authService = null;
      _runtimeConfig = null;
      await _localConfigStore.clear();
      await _runtimeFirebaseService.clear();
      _setViewState(
        const AppViewState(
          isBootstrapping: false,
          isFirebaseConfigured: false,
          isAuthenticated: false,
          activeTab: ShellTab.dashboard,
        ),
      );
      _flashMessage = 'Firebase configuration cleared for this browser.';
    });
  }

  Future<void> signIn(String email, String password) {
    return _withBusy(() async {
      await _ensureAuthService().signIn(email: email, password: password);
      _flashMessage = 'Signed in successfully.';
    });
  }

  Future<void> signUp(String email, String password) {
    return _withBusy(() async {
      await _ensureAuthService().signUp(email: email, password: password);
      _flashMessage = 'Account created.';
    });
  }

  Future<void> sendPasswordReset(String email) {
    return _withBusy(() async {
      await _ensureAuthService().sendPasswordReset(email);
      _flashMessage = 'Password reset email sent.';
    });
  }

  Future<void> signOut() {
    return _withBusy(() async {
      await _ensureAuthService().signOut();
      _flashMessage = 'Signed out.';
    });
  }

  void setActiveTab(ShellTab tab) {
    _setViewState(
      _viewState.copyWith(
        activeTab: tab,
        clearSelectedProject: tab != ShellTab.projects,
      ),
    );
  }

  void openProjectDashboard(String projectId) {
    _setViewState(
      _viewState.copyWith(
        activeTab: ShellTab.projects,
        selectedProjectId: projectId,
      ),
    );
  }

  void closeProjectDashboard() {
    _setViewState(_viewState.copyWith(clearSelectedProject: true));
  }

  void setTaskFilter(TaskFilter filter) {
    _taskFilter = filter;
    notifyListeners();
  }

  List<TaskModel> get filteredTasks {
    final today = DateTime.now();
    return tasks
        .where((task) {
          final matchesProject =
              _taskFilter.projectId == null ||
              task.projectId == _taskFilter.projectId;
          final matchesStatus =
              _taskFilter.status == null || task.status == _taskFilter.status;
          final matchesUpcoming =
              !_taskFilter.upcomingOnly ||
              (task.dueDate != null &&
                  !task.dueDate!.isBefore(
                    DateTime(today.year, today.month, today.day),
                  ));
          return matchesProject && matchesStatus && matchesUpcoming;
        })
        .toList(growable: false)
      ..sort((left, right) {
        final leftDue = left.dueDate ?? DateTime(2100);
        final rightDue = right.dueDate ?? DateTime(2100);
        return leftDue.compareTo(rightDue);
      });
  }

  List<TaskModel> get upcomingTasks {
    final today = DateTime.now();
    return filteredTasks
        .where(
          (task) =>
              task.dueDate != null &&
              !task.dueDate!.isBefore(
                DateTime(today.year, today.month, today.day),
              ),
        )
        .take(6)
        .toList(growable: false);
  }

  List<AssigneeModel> assigneesForProject(String projectId) {
    return assignees
        .where((assignee) => assignee.projectIds.contains(projectId))
        .toList(growable: false);
  }

  List<AssigneeModel> assigneesByRole(AssigneeRole role) {
    return assignees
        .where((assignee) => assignee.role == role)
        .toList(growable: false);
  }

  List<String> taskStatusesForProject(String projectId) {
    return projectById(projectId)?.taskStatuses ?? defaultProjectStatuses;
  }

  List<ProjectPhase> phasesForProject(String projectId) {
    return projectById(projectId)?.phases ?? const [];
  }

  String phaseName(String projectId, String? phaseId) {
    if (phaseId == null || phaseId.isEmpty) {
      return 'No phase';
    }
    return phasesForProject(
          projectId,
        ).firstWhereOrNull((phase) => phase.id == phaseId)?.name ??
        phaseId;
  }

  ProjectModel? projectById(String projectId) {
    return _projects.firstWhereOrNull((project) => project.id == projectId);
  }

  bool canEditProject(String projectId) => canManageStatuses(projectId);

  bool canManageProjectWork(String projectId) => canEditProject(projectId);

  bool get canManageAssignees => _isCurrentUserSuperAdmin || _assignees.isEmpty;

  bool get canCreateProjects => _isCurrentUserSuperAdmin;

  bool canManageStatuses(String projectId) {
    if (_isCurrentUserSuperAdmin) {
      return true;
    }
    final project = projectById(projectId);
    if (project == null) {
      return true;
    }

    final email = _user?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      return false;
    }
    if (project.ownerEmail.toLowerCase() == email) {
      return true;
    }

    final matchingAssignee = _assignees.firstWhereOrNull(
      (assignee) =>
          assignee.email.toLowerCase() == email &&
          assignee.projectIds.contains(projectId),
    );
    if (matchingAssignee == null) {
      return assigneesForProject(projectId).isEmpty;
    }
    return matchingAssignee.role == AssigneeRole.projectAdmin;
  }

  String previewNextProjectCode() => _generateNextProjectCode();

  String previewNextTaskCode(String projectId, {String? existingTaskId}) {
    final existing = existingTaskId == null
        ? null
        : _tasks.firstWhereOrNull((task) => task.id == existingTaskId);
    return existing?.taskCode ?? _generateNextTaskCode(projectId);
  }

  Future<void> saveProject({
    required String title,
    required String description,
    required int colorValue,
    required String timezone,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<ProjectPhase> phases,
    required List<String> taskStatuses,
    required List<String> assignedAssigneeIds,
    String? projectId,
  }) {
    return _withBusy(() async {
      final now = DateTime.now();
      final existing = projectId == null
          ? null
          : _projects.firstWhereOrNull((project) => project.id == projectId);
      if (existing == null && !_isCurrentUserSuperAdmin) {
        throw Exception('Only a SuperAdmin can create new projects.');
      }
      if (existing != null && !canEditProject(existing.id)) {
        throw Exception('Only a Project Admin can edit this project.');
      }
      if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
        throw Exception('Project end date must be on or after the start date.');
      }
      final cleanedStatuses = taskStatuses
          .map((status) => status.trim())
          .where((status) => status.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final cleanedPhases = _normalizePhases(phases);
      final assignedProjectAdmins = _assignees.where(
        (assignee) =>
            assignedAssigneeIds.contains(assignee.id) &&
            assignee.role == AssigneeRole.projectAdmin,
      );
      if (assignedProjectAdmins.isEmpty) {
        throw Exception('Assign at least one Project Admin to the project.');
      }
      final ownerEmail = _resolveProjectOwnerEmail(
        assignedAssigneeIds: assignedAssigneeIds,
        existingProject: existing,
      );
      final project = ProjectModel(
        id: projectId ?? '',
        projectCode: existing?.projectCode ?? _generateNextProjectCode(),
        title: title.trim(),
        description: description.trim(),
        timezone: timezone.trim().isEmpty
            ? _defaultTimezone()
            : timezone.trim(),
        startDate: startDate,
        endDate: endDate,
        phases: cleanedPhases,
        taskStatuses: cleanedStatuses.isEmpty
            ? defaultProjectStatuses
            : cleanedStatuses,
        issueLog: existing?.issueLog ?? const [],
        riskLog: existing?.riskLog ?? const [],
        actionLog: existing?.actionLog ?? const [],
        decisionLog: existing?.decisionLog ?? const [],
        ownerEmail: ownerEmail,
        colorValue: colorValue,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final savedProjectId = await _projectRepository().saveProject(project);
      final persistedProject = project.copyWith(id: savedProjectId);
      if (existing == null) {
        await _ensureCurrentUserProjectAdminAssignment(persistedProject);
      }
      await _syncProjectAssignments(
        projectId: savedProjectId,
        assignedAssigneeIds: assignedAssigneeIds,
      );
      _flashMessage = existing == null
          ? 'Project created.'
          : 'Project updated.';
    });
  }

  Future<void> deleteProject(String projectId) {
    return _withBusy(() async {
      if (!canEditProject(projectId)) {
        throw Exception('Only a Project Admin can delete this project.');
      }
      final tasksForProject = _tasks
          .where((task) => task.projectId == projectId)
          .toList(growable: false);
      for (final task in tasksForProject) {
        await _taskRepository().deleteTask(task.id);
      }

      final affectedAssignees = _assignees
          .where((assignee) => assignee.projectIds.contains(projectId))
          .toList(growable: false);
      for (final assignee in affectedAssignees) {
        await _assigneeRepository().saveAssignee(
          assignee.copyWith(
            projectIds: assignee.projectIds
                .where((id) => id != projectId)
                .toList(growable: false),
            updatedAt: DateTime.now(),
          ),
        );
      }

      await _projectRepository().deleteProject(projectId);
      _flashMessage = 'Project deleted.';
    });
  }

  Future<void> addProjectRecord({
    required String projectId,
    required ProjectRecordType type,
    String? assigneeId,
    required String description,
    required String comments,
    required String status,
    RiskProbability? probability,
  }) {
    return _withBusy(() async {
      final project = projectById(projectId);
      if (project == null) {
        throw Exception('Project not found.');
      }
      if (!canEditProject(projectId)) {
        throw Exception('Only a Project Admin can add log entries.');
      }

      final now = DateTime.now();
      final entry = ProjectRecordEntry(
        id: _generateNextProjectRecordId(project, type),
        assigneeId: assigneeId?.trim().isEmpty ?? true ? null : assigneeId,
        description: description.trim(),
        comments: comments.trim(),
        status: status.trim().isEmpty
            ? defaultRecordStatuses.first
            : status.trim(),
        createdAt: now,
        probability: type == ProjectRecordType.risk
            ? (probability ?? RiskProbability.medium)
            : null,
      );

      final updatedProject = switch (type) {
        ProjectRecordType.issue => project.copyWith(
          issueLog: [...project.issueLog, entry],
          updatedAt: now,
        ),
        ProjectRecordType.risk => project.copyWith(
          riskLog: [...project.riskLog, entry],
          updatedAt: now,
        ),
        ProjectRecordType.action => project.copyWith(
          actionLog: [...project.actionLog, entry],
          updatedAt: now,
        ),
        ProjectRecordType.decision => project.copyWith(
          decisionLog: [...project.decisionLog, entry],
          updatedAt: now,
        ),
      };

      await _projectRepository().saveProject(updatedProject);
      _flashMessage = '${_recordTypeLabel(type)} added.';
    });
  }

  Future<void> saveTask({
    required String title,
    required String notes,
    required String projectId,
    required String status,
    required TaskPriority priority,
    required DateTime? dueDate,
    required bool isMilestone,
    required List<String> predecessorTaskCodes,
    String? phaseId,
    String? assigneeId,
    String? taskId,
    String? changeSummary,
  }) {
    return _withBusy(() async {
      final project = projectById(projectId);
      if (project == null) {
        throw Exception('Select a valid project before saving a task.');
      }

      final normalizedStatus = status.trim();
      if (!project.taskStatuses.contains(normalizedStatus)) {
        throw Exception('Select a valid status for the chosen project.');
      }
      if (phaseId != null &&
          phaseId.isNotEmpty &&
          !project.phases.any((phase) => phase.id == phaseId)) {
        throw Exception('Select a valid phase for the chosen project.');
      }

      final existing = taskId == null
          ? null
          : _tasks.firstWhereOrNull((task) => task.id == taskId);
      final taskCode = existing?.taskCode ?? _generateNextTaskCode(projectId);
      final normalizedPredecessors = predecessorTaskCodes
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (normalizedPredecessors.contains(taskCode)) {
        throw Exception('A task cannot list itself as a predecessor.');
      }

      if (_createsCircularDependency(
        taskCode: taskCode,
        predecessorTaskCodes: normalizedPredecessors,
        taskId: taskId,
      )) {
        throw Exception(
          'Those predecessors would create a circular dependency. Adjust the task chain and try again.',
        );
      }

      final now = DateTime.now();
      final changeLog = [
        ...?existing?.changeLog,
        TaskChangeLogEntry(
          changedAt: now,
          description:
              changeSummary ??
              (existing == null ? 'Task created' : 'Task updated'),
        ),
      ];

      final task = TaskModel(
        id: taskId ?? '',
        taskCode: taskCode,
        projectId: projectId,
        title: title.trim(),
        notes: notes.trim(),
        status: normalizedStatus,
        priority: priority,
        isMilestone: isMilestone,
        dueDate: dueDate,
        predecessorTaskCodes: normalizedPredecessors,
        assigneeId: assigneeId?.isEmpty ?? true ? null : assigneeId,
        phaseId: phaseId?.isEmpty ?? true ? null : phaseId,
        lastChangedAt: now,
        changeLog: changeLog,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _taskRepository().saveTask(task);
      _flashMessage = existing == null
          ? 'Task created with auto-generated ID $taskCode.'
          : 'Task updated.';
    });
  }

  Future<void> deleteTask(String taskId) {
    return _withBusy(() async {
      final task = _tasks.firstWhereOrNull((item) => item.id == taskId);
      if (task != null) {
        final dependents = _tasks
            .where((item) => item.predecessorTaskCodes.contains(task.taskCode))
            .toList(growable: false);
        for (final dependent in dependents) {
          final now = DateTime.now();
          await _taskRepository().saveTask(
            dependent.copyWith(
              predecessorTaskCodes: dependent.predecessorTaskCodes
                  .where((code) => code != task.taskCode)
                  .toList(growable: false),
              lastChangedAt: now,
              updatedAt: now,
              changeLog: [
                ...dependent.changeLog,
                TaskChangeLogEntry(
                  changedAt: now,
                  description:
                      'Removed predecessor ${task.taskCode} after deletion',
                ),
              ],
            ),
          );
        }
      }

      await _taskRepository().deleteTask(taskId);
      _flashMessage = 'Task deleted.';
    });
  }

  Future<void> saveAssignee({
    required String name,
    required String email,
    required AssigneeRole role,
    required String designation,
    required String workHours,
    required List<String> projectIds,
    String? assigneeId,
  }) {
    return _withBusy(() async {
      final isBootstrapSuperAdminCreation =
          _assignees.isEmpty && assigneeId == null;
      if (!_isCurrentUserSuperAdmin && !isBootstrapSuperAdminCreation) {
        throw Exception('Only a SuperAdmin can create or update assignees.');
      }
      final normalizedEmail = email.trim().toLowerCase();
      if (name.trim().isEmpty) {
        throw Exception('Assignee name is required.');
      }
      if (normalizedEmail.isEmpty) {
        throw Exception('Assignee email is required.');
      }
      if (isBootstrapSuperAdminCreation && role != AssigneeRole.superAdmin) {
        throw Exception('The first assignee must be created as a SuperAdmin.');
      }

      final duplicate = _assignees.firstWhereOrNull(
        (assignee) =>
            assignee.email.toLowerCase() == normalizedEmail &&
            assignee.id != assigneeId,
      );
      if (duplicate != null) {
        throw Exception('That assignee email already exists.');
      }

      final now = DateTime.now();
      final existing = assigneeId == null
          ? null
          : _assignees.firstWhereOrNull(
              (assignee) => assignee.id == assigneeId,
            );
      final assignee = AssigneeModel(
        id: assigneeId ?? '',
        name: name.trim(),
        email: normalizedEmail,
        role: role,
        designation: designation.trim(),
        workHours: workHours.trim(),
        projectIds: projectIds,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _assigneeRepository().saveAssignee(assignee);
      _flashMessage = existing == null
          ? 'Assignee created.'
          : 'Assignee updated.';
    });
  }

  Future<void> deleteAssignee(String assigneeId) {
    return _withBusy(() async {
      if (!_isCurrentUserSuperAdmin) {
        throw Exception('Only a SuperAdmin can delete assignees.');
      }
      final impactedTasks = _tasks
          .where((task) => task.assigneeId == assigneeId)
          .toList(growable: false);
      for (final task in impactedTasks) {
        final now = DateTime.now();
        await _taskRepository().saveTask(
          task.copyWith(
            clearAssigneeId: true,
            lastChangedAt: now,
            updatedAt: now,
            changeLog: [
              ...task.changeLog,
              TaskChangeLogEntry(
                changedAt: now,
                description: 'Assignee cleared after assignee deletion',
              ),
            ],
          ),
        );
      }

      await _assigneeRepository().deleteAssignee(assigneeId);
      _flashMessage = 'Assignee deleted.';
    });
  }

  Future<void> exportTasksToCsv({String? projectId}) {
    return _withBusy(() async {
      final scopedTasks = projectId == null
          ? tasks
          : tasks
                .where((task) => task.projectId == projectId)
                .toList(growable: false);
      final rows = <List<String>>[
        const [
          'task_id',
          'task_title',
          'project_id',
          'project_title',
          'timezone',
          'predecessor_task_ids',
          'predecessor_task_titles',
          'phase_id',
          'phase_name',
          'assignee_email',
          'assignee_name',
          'status',
          'priority',
          'due_date',
          'is_milestone',
          'notes',
          'last_changed',
          'change_log',
        ],
        ...scopedTasks.map((task) {
          final assignee = assignees.firstWhereOrNull(
            (item) => item.id == task.assigneeId,
          );
          final project = projectById(task.projectId);
          final predecessorTitles = task.predecessorTaskCodes
              .map((code) => taskTitleByCode(code))
              .join(' | ');
          return [
            task.taskCode,
            task.title,
            project?.projectCode ?? task.projectId,
            projectTitle(task.projectId),
            project?.timezone ?? '',
            task.predecessorTaskCodes.join(' | '),
            predecessorTitles,
            task.phaseId ?? '',
            phaseName(task.projectId, task.phaseId),
            assignee?.email ?? '',
            assignee?.name ?? '',
            task.status,
            task.priority.name,
            task.dueDate?.toIso8601String() ?? '',
            task.isMilestone.toString(),
            task.notes,
            task.lastChangedAt.toIso8601String(),
            task.changeLog.map((entry) => entry.toCsvToken()).join(' || '),
          ];
        }),
      ];

      final csv = _csvCodecService.encodeRows(rows);
      await _csvPortService.downloadCsv(
        filename:
            '${projectId == null ? 'project-planner' : (projectById(projectId)?.projectCode ?? 'project')}-tasks-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.csv',
        content: csv,
      );
      _flashMessage = 'Task list exported to CSV.';
    });
  }

  Future<void> importTasksFromCsv({String? projectId}) {
    return _withBusy(() async {
      final content = await _csvPortService.pickCsv();
      if (content == null || content.trim().isEmpty) {
        return;
      }

      final rows = _csvCodecService.decodeObjects(content);
      for (final row in rows) {
        final incomingTaskCode = row['task_id']?.trim() ?? '';
        if (incomingTaskCode.isEmpty) {
          continue;
        }

        final resolvedProjectId =
            projectId ?? await _resolveProjectForImport(row);
        final project = projectById(resolvedProjectId)!;
        final assigneeId = await _resolveAssigneeForImport(
          row,
          resolvedProjectId,
        );
        final existing = _tasks.firstWhereOrNull(
          (task) =>
              task.taskCode == incomingTaskCode &&
              task.projectId == resolvedProjectId,
        );
        final now = DateTime.now();
        final importedStatus = row['status']?.trim() ?? '';
        final status = project.taskStatuses.contains(importedStatus)
            ? importedStatus
            : project.taskStatuses.first;

        final task = TaskModel(
          id: existing?.id ?? '',
          taskCode: incomingTaskCode,
          projectId: resolvedProjectId,
          title: row['task_title']?.trim().isNotEmpty == true
              ? row['task_title']!.trim()
              : incomingTaskCode,
          notes: row['notes']?.trim() ?? '',
          status: status,
          priority: _parsePriority(row['priority']),
          isMilestone: (row['is_milestone'] ?? '').toLowerCase() == 'true',
          dueDate: _parseDate(row['due_date']),
          predecessorTaskCodes: _splitPipeValues(row['predecessor_task_ids']),
          phaseId: _resolvePhaseIdForImport(
            project,
            row['phase_id'],
            row['phase_name'],
          ),
          assigneeId: assigneeId,
          lastChangedAt: _parseDate(row['last_changed']) ?? now,
          changeLog: [
            ...?existing?.changeLog,
            ..._parseImportedChangeLog(row['change_log']),
            TaskChangeLogEntry(
              changedAt: now,
              description: 'Task imported from CSV',
            ),
          ],
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await _taskRepository().saveTask(task);
      }

      _flashMessage = 'CSV import completed.';
    });
  }

  Future<void> exportProjectRecordsToCsv({
    required String projectId,
    required ProjectRecordType type,
  }) {
    return _withBusy(() async {
      final rows = <List<String>>[
        const [
          'record_id',
          'project_id',
          'project_title',
          'record_type',
          'assignee_email',
          'assignee_name',
          'description',
          'comments',
          'status',
          'probability',
          'created_at',
        ],
        ...projectRecords(type, projectId).map((entry) {
          final assignee = assignees.firstWhereOrNull(
            (item) => item.id == entry.assigneeId,
          );
          return [
            entry.id,
            projectCode(projectId),
            projectTitle(projectId),
            type.name,
            assignee?.email ?? '',
            assignee?.name ?? '',
            entry.description,
            entry.comments,
            entry.status,
            entry.probability?.name ?? '',
            entry.createdAt.toIso8601String(),
          ];
        }),
      ];

      final csv = _csvCodecService.encodeRows(rows);
      await _csvPortService.downloadCsv(
        filename:
            '${projectCode(projectId).toLowerCase()}-${type.name}-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.csv',
        content: csv,
      );
      _flashMessage = '${_recordTypeLabel(type)} list exported to CSV.';
    });
  }

  Future<void> importProjectRecordsFromCsv({
    required String projectId,
    required ProjectRecordType type,
  }) {
    return _withBusy(() async {
      final project = projectById(projectId);
      if (project == null) {
        throw Exception('Project not found.');
      }
      if (!canEditProject(projectId)) {
        throw Exception('Only a Project Admin can import project records.');
      }

      final content = await _csvPortService.pickCsv();
      if (content == null || content.trim().isEmpty) {
        return;
      }

      final rows = _csvCodecService.decodeObjects(content);
      final existingEntries = List<ProjectRecordEntry>.from(
        projectRecords(type, projectId),
      );
      var generatedCount = 0;

      for (final row in rows) {
        final description = row['description']?.trim() ?? '';
        if (description.isEmpty) {
          continue;
        }
        final assigneeId = await _resolveAssigneeForImport(row, projectId);
        final entry = ProjectRecordEntry(
          id: row['record_id']?.trim().isNotEmpty == true
              ? row['record_id']!.trim()
              : _generateImportedProjectRecordId(
                  project,
                  type,
                  existingEntries,
                  generatedCount++,
                ),
          assigneeId: assigneeId,
          description: description,
          comments: row['comments']?.trim() ?? '',
          status: row['status']?.trim().isNotEmpty == true
              ? row['status']!.trim()
              : defaultRecordStatuses.first,
          probability: type == ProjectRecordType.risk
              ? _parseRiskProbability(row['probability']) ??
                    RiskProbability.medium
              : null,
          createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
        );

        final existingIndex = existingEntries.indexWhere(
          (item) => item.id == entry.id,
        );
        if (existingIndex == -1) {
          existingEntries.add(entry);
        } else {
          existingEntries[existingIndex] = entry;
        }
      }

      await _projectRepository().saveProject(
        _projectWithUpdatedRecords(project, type, existingEntries),
      );
      _flashMessage = '${_recordTypeLabel(type)} CSV import completed.';
    });
  }

  String projectTitle(String projectId) {
    return projectById(projectId)?.title ?? 'Unknown project';
  }

  String projectCode(String projectId) {
    return projectById(projectId)?.projectCode ?? projectId;
  }

  String assigneeName(String? assigneeId) {
    if (assigneeId == null || assigneeId.isEmpty) {
      return 'Unassigned';
    }
    return assignees
            .firstWhereOrNull((assignee) => assignee.id == assigneeId)
            ?.name ??
        'Unknown assignee';
  }

  String roleLabel(AssigneeRole role) {
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

  String taskTitleByCode(String taskCode) {
    return tasks.firstWhereOrNull((task) => task.taskCode == taskCode)?.title ??
        taskCode;
  }

  List<String> predecessorSummaries(TaskModel task) {
    return task.predecessorTaskCodes
        .map((code) => '$code - ${taskTitleByCode(code)}')
        .toList(growable: false);
  }

  List<ProjectRecordEntry> projectRecords(
    ProjectRecordType type,
    String projectId,
  ) {
    final project = projectById(projectId);
    if (project == null) {
      return const [];
    }
    return switch (type) {
      ProjectRecordType.issue => project.issueLog,
      ProjectRecordType.risk => project.riskLog,
      ProjectRecordType.action => project.actionLog,
      ProjectRecordType.decision => project.decisionLog,
    };
  }

  ProjectModel _projectWithUpdatedRecords(
    ProjectModel project,
    ProjectRecordType type,
    List<ProjectRecordEntry> records,
  ) {
    final now = DateTime.now();
    return switch (type) {
      ProjectRecordType.issue => project.copyWith(
        issueLog: records,
        updatedAt: now,
      ),
      ProjectRecordType.risk => project.copyWith(
        riskLog: records,
        updatedAt: now,
      ),
      ProjectRecordType.action => project.copyWith(
        actionLog: records,
        updatedAt: now,
      ),
      ProjectRecordType.decision => project.copyWith(
        decisionLog: records,
        updatedAt: now,
      ),
    };
  }

  void clearFlashMessage() {
    _flashMessage = null;
    _setViewState(_viewState.copyWith(clearError: true));
  }

  Future<void> _initializeFirebase(
    FirebaseRuntimeConfig config, {
    required bool persist,
  }) async {
    await _runtimeFirebaseService.initialize(config);
    if (persist) {
      await _localConfigStore.save(config);
    }

    _runtimeConfig = config;
    _authService = AuthService(auth: _runtimeFirebaseService.auth!);
    await _authSubscription?.cancel();
    _authSubscription = _authService!.authStateChanges().listen(
      _handleUserChanged,
    );

    _setViewState(
      _viewState.copyWith(
        isBootstrapping: false,
        isFirebaseConfigured: true,
        isAuthenticated: _authService!.currentUser != null,
        clearError: true,
      ),
    );

    await _handleUserChanged(_authService!.currentUser);
  }

  Future<void> _handleUserChanged(User? user) async {
    _user = user;
    await _projectSubscription?.cancel();
    await _taskSubscription?.cancel();
    await _assigneeSubscription?.cancel();

    if (user == null) {
      _projects = const [];
      _tasks = const [];
      _assignees = const [];
      _setViewState(
        _viewState.copyWith(
          isAuthenticated: false,
          isFirebaseConfigured: _runtimeConfig != null,
        ),
      );
      return;
    }

    _projectSubscription = _projectRepository().watchProjects().listen((
      projects,
    ) {
      _projects = projects;
      notifyListeners();
    }, onError: _handleAsyncError);
    _taskSubscription = _taskRepository().watchTasks().listen((tasks) {
      _tasks = tasks;
      notifyListeners();
    }, onError: _handleAsyncError);
    _assigneeSubscription = _assigneeRepository().watchAssignees().listen((
      assignees,
    ) {
      _assignees = assignees;
      notifyListeners();
    }, onError: _handleAsyncError);

    _setViewState(
      _viewState.copyWith(isAuthenticated: true, isFirebaseConfigured: true),
    );
  }

  void _handleAsyncError(Object error) {
    _setViewState(_viewState.copyWith(errorMessage: _friendlyError(error)));
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    _isBusy = true;
    notifyListeners();
    try {
      await action();
      _setViewState(_viewState.copyWith(clearError: true));
    } catch (error) {
      _setViewState(_viewState.copyWith(errorMessage: _friendlyError(error)));
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('permission-denied')) {
      return 'Firestore rejected the request. Check your Firestore security rules and make sure this signed-in user has access.';
    }
    if (raw.contains('operation-not-allowed')) {
      return 'Email/password authentication is not enabled in this Firebase project.';
    }
    if (raw.contains('wrong-password') || raw.contains('invalid-credential')) {
      return 'The email or password is incorrect.';
    }
    if (raw.contains('email-already-in-use')) {
      return 'That email address already has an account.';
    }
    if (raw.contains('weak-password')) {
      return 'Choose a stronger password with at least 6 characters.';
    }
    if (raw.contains('user-not-found')) {
      return 'No account was found for that email address.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  void _setViewState(AppViewState state) {
    _viewState = state;
    notifyListeners();
  }

  String _recordTypeLabel(ProjectRecordType type) {
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

  RiskProbability? _parseRiskProbability(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return RiskProbability.values.firstWhere(
      (probability) => probability.name == value.trim(),
      orElse: () => RiskProbability.medium,
    );
  }

  List<ProjectModel> get _visibleProjects {
    if (_isCurrentUserSuperAdmin) {
      return List<ProjectModel>.from(_projects);
    }
    final email = _user?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      return const [];
    }
    final visibleProjectIds = _assignees
        .where((assignee) => assignee.email.toLowerCase() == email)
        .expand((assignee) => assignee.projectIds)
        .toSet();
    return _projects
        .where((project) => visibleProjectIds.contains(project.id))
        .toList(growable: false);
  }

  List<TaskModel> get _visibleTasks {
    final visibleProjectIds = _visibleProjects
        .map((project) => project.id)
        .toSet();
    return _tasks
        .where((task) => visibleProjectIds.contains(task.projectId))
        .toList(growable: false);
  }

  List<AssigneeModel> get _visibleAssignees {
    if (_isCurrentUserSuperAdmin) {
      return List<AssigneeModel>.from(_assignees);
    }
    final visibleProjectIds = _visibleProjects
        .map((project) => project.id)
        .toSet();
    final email = _user?.email?.trim().toLowerCase() ?? '';
    return _assignees
        .where((assignee) {
          final assignedToVisibleProject = assignee.projectIds.any(
            (projectId) => visibleProjectIds.contains(projectId),
          );
          return assignedToVisibleProject ||
              assignee.email.toLowerCase() == email;
        })
        .toList(growable: false);
  }

  String _generateNextProjectCode() {
    final usedNumbers = _projects
        .map((project) => _extractNumericSuffix(project.projectCode))
        .whereType<int>()
        .toSet();
    var next = 1;
    while (usedNumbers.contains(next)) {
      next++;
    }
    return 'PRJ-${next.toString().padLeft(3, '0')}';
  }

  String _generateNextTaskCode(String projectId) {
    final project = projectById(projectId);
    final prefix = project?.projectCode ?? 'TSK';
    final usedNumbers = _tasks
        .where((task) => task.projectId == projectId)
        .map((task) => _extractNumericSuffix(task.taskCode))
        .whereType<int>()
        .toSet();
    var next = 1;
    while (usedNumbers.contains(next)) {
      next++;
    }
    return '$prefix-T${next.toString().padLeft(3, '0')}';
  }

  List<ProjectPhase> _normalizePhases(List<ProjectPhase> phases) {
    final cleaned = <ProjectPhase>[];
    var next = 1;
    final usedIds = <String>{};
    for (final phase in phases) {
      final name = phase.name.trim();
      if (name.isEmpty) {
        continue;
      }
      final resolvedId = phase.id.trim().isEmpty
          ? 'PH-${next.toString().padLeft(3, '0')}'
          : phase.id.trim();
      usedIds.add(resolvedId);
      cleaned.add(
        ProjectPhase(
          id: resolvedId,
          name: name,
          startDate: phase.startDate,
          endDate: phase.endDate,
        ),
      );
      next++;
      while (usedIds.contains('PH-${next.toString().padLeft(3, '0')}')) {
        next++;
      }
    }
    return cleaned;
  }

  String _generateNextProjectRecordId(
    ProjectModel project,
    ProjectRecordType type,
  ) {
    final entries = switch (type) {
      ProjectRecordType.issue => project.issueLog,
      ProjectRecordType.risk => project.riskLog,
      ProjectRecordType.action => project.actionLog,
      ProjectRecordType.decision => project.decisionLog,
    };
    final usedNumbers = entries
        .map((entry) => _extractNumericSuffix(entry.id))
        .whereType<int>()
        .toSet();
    var next = 1;
    while (usedNumbers.contains(next)) {
      next++;
    }

    final prefix = switch (type) {
      ProjectRecordType.issue => 'ISS',
      ProjectRecordType.risk => 'RSK',
      ProjectRecordType.action => 'ACT',
      ProjectRecordType.decision => 'DEC',
    };
    return '${project.projectCode}-$prefix-${next.toString().padLeft(3, '0')}';
  }

  String _generateImportedProjectRecordId(
    ProjectModel project,
    ProjectRecordType type,
    List<ProjectRecordEntry> existingEntries,
    int offset,
  ) {
    final existingIds = existingEntries.map((entry) => entry.id).toSet();
    var nextId = _generateNextProjectRecordId(project, type);
    while (existingIds.contains(nextId)) {
      offset++;
      final prefix = nextId.replaceAll(RegExp(r'\d+$'), '');
      nextId = '$prefix${(offset + 1).toString().padLeft(3, '0')}';
    }
    return nextId;
  }

  bool _createsCircularDependency({
    required String taskCode,
    required List<String> predecessorTaskCodes,
    required String? taskId,
  }) {
    final graph = <String, List<String>>{};
    for (final task in _tasks) {
      if (task.id == taskId) {
        continue;
      }
      graph[task.taskCode] = task.predecessorTaskCodes;
    }
    graph[taskCode] = predecessorTaskCodes;

    bool reachesTarget(String current, Set<String> visited) {
      if (current == taskCode) {
        return true;
      }
      if (!visited.add(current)) {
        return false;
      }
      final predecessors = graph[current] ?? const <String>[];
      for (final predecessor in predecessors) {
        if (reachesTarget(predecessor, visited)) {
          return true;
        }
      }
      return false;
    }

    for (final predecessor in predecessorTaskCodes) {
      if (reachesTarget(predecessor, <String>{})) {
        return true;
      }
    }
    return false;
  }

  int? _extractNumericSuffix(String value) {
    final match = RegExp(r'(\d+)$').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  AuthService _ensureAuthService() {
    final authService = _authService;
    if (authService == null) {
      throw Exception('Connect a Firebase project before signing in.');
    }
    return authService;
  }

  ProjectRepository _projectRepository() {
    final firestore = _runtimeFirebaseService.firestore;
    final user = _user;
    if (firestore == null || user == null) {
      throw Exception('Sign in before editing projects.');
    }
    return ProjectRepository(firestore: firestore, userId: user.uid);
  }

  TaskRepository _taskRepository() {
    final firestore = _runtimeFirebaseService.firestore;
    final user = _user;
    if (firestore == null || user == null) {
      throw Exception('Sign in before editing tasks.');
    }
    return TaskRepository(firestore: firestore, userId: user.uid);
  }

  AssigneeRepository _assigneeRepository() {
    final firestore = _runtimeFirebaseService.firestore;
    final user = _user;
    if (firestore == null || user == null) {
      throw Exception('Sign in before editing assignees.');
    }
    return AssigneeRepository(firestore: firestore, userId: user.uid);
  }

  Future<String> _resolveProjectForImport(Map<String, String> row) async {
    final incomingProjectCode = row['project_id']?.trim() ?? '';
    if (incomingProjectCode.isNotEmpty) {
      final existingByCode = _projects.firstWhereOrNull(
        (project) => project.projectCode == incomingProjectCode,
      );
      if (existingByCode != null) {
        return existingByCode.id;
      }
    }

    final incomingTitle = row['project_title']?.trim() ?? '';
    final existingByTitle = _projects.firstWhereOrNull(
      (project) => project.title.toLowerCase() == incomingTitle.toLowerCase(),
    );
    if (existingByTitle != null) {
      return existingByTitle.id;
    }

    final now = DateTime.now();
    final project = ProjectModel(
      id: '',
      projectCode: incomingProjectCode.isEmpty
          ? _generateNextProjectCode()
          : incomingProjectCode,
      title: incomingTitle.isEmpty ? 'Imported Project' : incomingTitle,
      description: 'Created during CSV import.',
      timezone: row['timezone']?.trim().isNotEmpty == true
          ? row['timezone']!.trim()
          : _defaultTimezone(),
      startDate: null,
      endDate: null,
      phases: const [],
      taskStatuses: defaultProjectStatuses,
      issueLog: const [],
      riskLog: const [],
      actionLog: const [],
      decisionLog: const [],
      ownerEmail: _user?.email ?? '',
      colorValue: 0xFF255F4A,
      createdAt: now,
      updatedAt: now,
    );
    await _projectRepository().saveProject(project);
    await _ensureCurrentUserProjectAdminAssignment(project);
    _projects = await _projectRepository().watchProjects().first;
    return _projects
        .firstWhere((item) => item.projectCode == project.projectCode)
        .id;
  }

  Future<String?> _resolveAssigneeForImport(
    Map<String, String> row,
    String projectId,
  ) async {
    final email = row['assignee_email']?.trim().toLowerCase() ?? '';
    final name = row['assignee_name']?.trim() ?? '';
    if (email.isEmpty && name.isEmpty) {
      return null;
    }

    final existing = _assignees.firstWhereOrNull(
      (assignee) => email.isNotEmpty && assignee.email.toLowerCase() == email,
    );
    if (existing != null) {
      if (!existing.projectIds.contains(projectId)) {
        await _assigneeRepository().saveAssignee(
          existing.copyWith(
            projectIds: [...existing.projectIds, projectId],
            updatedAt: DateTime.now(),
          ),
        );
      }
      return existing.id;
    }

    if (!_isCurrentUserSuperAdmin) {
      return null;
    }

    final now = DateTime.now();
    final importedAssignee = AssigneeModel(
      id: '',
      name: name.isEmpty ? email : name,
      email: email.isEmpty
          ? '${name.toLowerCase().replaceAll(' ', '.')}@imported.local'
          : email,
      role: AssigneeRole.projectUser,
      designation: '',
      workHours: '',
      projectIds: [projectId],
      createdAt: now,
      updatedAt: now,
    );
    await _assigneeRepository().saveAssignee(importedAssignee);
    _assignees = await _assigneeRepository().watchAssignees().first;
    return _assignees
        .firstWhere((item) => item.email == importedAssignee.email)
        .id;
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.trim());
  }

  List<TaskChangeLogEntry> _parseImportedChangeLog(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    return value
        .split(' || ')
        .where((token) => token.trim().isNotEmpty)
        .map(TaskChangeLogEntry.fromCsvToken)
        .toList(growable: false);
  }

  TaskPriority _parsePriority(String? value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => TaskPriority.medium,
    );
  }

  List<String> _splitPipeValues(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    return value
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _defaultTimezone() {
    final localName = DateTime.now().timeZoneName.trim();
    return localName.isEmpty ? 'America/New_York' : localName;
  }

  Future<void> _syncProjectAssignments({
    required String projectId,
    required List<String> assignedAssigneeIds,
  }) async {
    final selectedIds = {...assignedAssigneeIds};
    final currentAssignees = List<AssigneeModel>.from(_assignees);
    for (final assignee in currentAssignees) {
      final currentlyAssigned = assignee.projectIds.contains(projectId);
      final shouldBeAssigned = selectedIds.contains(assignee.id);
      if (currentlyAssigned == shouldBeAssigned) {
        continue;
      }

      final updatedProjectIds = shouldBeAssigned
          ? {...assignee.projectIds, projectId}.toList(growable: false)
          : assignee.projectIds
                .where((id) => id != projectId)
                .toList(growable: false);
      await _assigneeRepository().saveAssignee(
        assignee.copyWith(
          projectIds: updatedProjectIds,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  AssigneeRole? get _currentUserRole {
    final email = _user?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      return null;
    }
    return _assignees
        .firstWhereOrNull((assignee) => assignee.email.toLowerCase() == email)
        ?.role;
  }

  bool get _isCurrentUserSuperAdmin =>
      _currentUserRole == AssigneeRole.superAdmin;

  String _resolveProjectOwnerEmail({
    required List<String> assignedAssigneeIds,
    required ProjectModel? existingProject,
  }) {
    final assignedAdmins = _assignees.where(
      (assignee) =>
          assignedAssigneeIds.contains(assignee.id) &&
          assignee.role == AssigneeRole.projectAdmin,
    );
    final projectAdminEmail = assignedAdmins
        .firstWhereOrNull((_) => true)
        ?.email;
    if (projectAdminEmail != null && projectAdminEmail.trim().isNotEmpty) {
      return projectAdminEmail.trim().toLowerCase();
    }
    if (existingProject != null &&
        existingProject.ownerEmail.trim().isNotEmpty) {
      return existingProject.ownerEmail.trim().toLowerCase();
    }
    return (_user?.email ?? '').trim().toLowerCase();
  }

  String? _resolvePhaseIdForImport(
    ProjectModel project,
    String? incomingPhaseId,
    String? incomingPhaseName,
  ) {
    final trimmedId = incomingPhaseId?.trim() ?? '';
    if (trimmedId.isNotEmpty &&
        project.phases.any((phase) => phase.id == trimmedId)) {
      return trimmedId;
    }
    final trimmedName = incomingPhaseName?.trim().toLowerCase() ?? '';
    if (trimmedName.isEmpty) {
      return null;
    }
    return project.phases
        .firstWhereOrNull((phase) => phase.name.toLowerCase() == trimmedName)
        ?.id;
  }

  Future<void> _ensureCurrentUserProjectAdminAssignment(
    ProjectModel project,
  ) async {
    final email = _user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return;
    }

    final existing = _assignees.firstWhereOrNull(
      (assignee) => assignee.email.toLowerCase() == email,
    );
    if (existing == null) {
      if (_isCurrentUserSuperAdmin) {
        return;
      }
      await _assigneeRepository().saveAssignee(
        AssigneeModel(
          id: '',
          name: _user?.displayName?.trim().isNotEmpty == true
              ? _user!.displayName!.trim()
              : email,
          email: email,
          role: AssigneeRole.projectAdmin,
          designation: '',
          workHours: '',
          projectIds: [project.id],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }

    if (!existing.projectIds.contains(project.id) ||
        (existing.role != AssigneeRole.projectAdmin &&
            existing.role != AssigneeRole.superAdmin)) {
      await _assigneeRepository().saveAssignee(
        existing.copyWith(
          role: AssigneeRole.projectAdmin,
          projectIds: {
            ...existing.projectIds,
            project.id,
          }.toList(growable: false),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _projectSubscription?.cancel();
    await _taskSubscription?.cancel();
    await _assigneeSubscription?.cancel();
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) predicate) {
    for (final value in this) {
      if (predicate(value)) {
        return value;
      }
    }
    return null;
  }
}
