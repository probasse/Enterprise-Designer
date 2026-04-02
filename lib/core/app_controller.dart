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
import 'models/notification_model.dart';
import 'models/project_grant.dart';
import 'services/notification_repository.dart';
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

  // ── Impersonation ────────────────────────────────────────────────────────
  AssigneeModel? _impersonatedAssignee;
  bool get isImpersonating => _impersonatedAssignee != null;
  AssigneeModel? get impersonatedAssignee => _impersonatedAssignee;

  /// The actual logged-in user's SuperAdmin status, ignoring impersonation.
  bool get isRealSuperAdmin => _isRealSuperAdmin;

  void startImpersonation(String assigneeId) {
    if (!_isRealSuperAdmin) return;
    final target = _assignees.firstWhereOrNull((a) => a.id == assigneeId);
    if (target == null) return;
    // Cannot impersonate yourself
    if (target.email.toLowerCase() == _user?.email?.trim().toLowerCase()) return;
    _impersonatedAssignee = target;
    _flashMessage =
        'Viewing as ${target.name} (${roleLabel(target.role)}). Changes you make will still be saved as your own account.';
    notifyListeners();
  }

  void stopImpersonation() {
    final name = _impersonatedAssignee?.name ?? '';
    _impersonatedAssignee = null;
    _flashMessage = 'Stopped impersonating $name. Back to your own account.';
    notifyListeners();
  }

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<ProjectModel>>? _projectSubscription;
  StreamSubscription<List<TaskModel>>? _taskSubscription;
  StreamSubscription<List<AssigneeModel>>? _assigneeSubscription;
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;

  List<NotificationModel> _notifications = const [];

  List<NotificationModel> get visibleNotifications {
    final assigneeId = _currentUserAssigneeId;
    if (assigneeId == null) return const [];
    return _notifications
        .where((n) => n.recipientAssigneeId == assigneeId)
        .toList(growable: false);
  }

  int get unreadNotificationCount =>
      visibleNotifications.where((n) => !n.isRead).length;

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
      await _notificationSubscription?.cancel();
      _tasks = const [];
      _projects = const [];
      _assignees = const [];
      _notifications = const [];
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

  bool canManageProjectWork(String projectId) {
    if (canEditProject(projectId)) return true;
    return _currentUserHasGrant(projectId, ProjectGrant.tasks);
  }

  bool canManageProjectRecords(String projectId, ProjectRecordType type) {
    if (canEditProject(projectId)) return true;
    return _currentUserHasGrant(projectId, ProjectGrant.forRecordType(type));
  }

  bool get canManageAssignees => _isCurrentUserSuperAdmin || _assignees.isEmpty;

  bool get canCreateProjects => _isCurrentUserSuperAdmin;

  /// Display name of the currently active user (respects impersonation).
  String get currentUserName {
    if (_impersonatedAssignee != null) return _impersonatedAssignee!.name;
    final email = _user?.email?.trim().toLowerCase() ?? '';
    final assignee = _assignees.firstWhereOrNull(
      (a) => a.email.toLowerCase() == email,
    );
    if (assignee != null && assignee.name.isNotEmpty) return assignee.name;
    final displayName = _user?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    return email;
  }

  /// The [AssigneeModel] for the currently logged-in real user (not impersonated).
  AssigneeModel? get currentUserAssignee {
    final id = _realUserAssigneeId;
    if (id == null) return null;
    return _assignees.firstWhereOrNull((a) => a.id == id);
  }

  /// Role label of the currently active user (respects impersonation).
  String get currentUserRoleLabel {
    final role = _currentUserRole;
    if (role == null) return '';
    return roleLabel(role);
  }

  bool canManageStatuses(String projectId) {
    if (_isCurrentUserSuperAdmin) {
      return true;
    }
    final project = projectById(projectId);
    if (project == null) {
      return true;
    }

    // Use impersonated user's email when active, otherwise real user's email
    final email = _impersonatedAssignee?.email.toLowerCase() ??
        _user?.email?.trim().toLowerCase() ??
        '';
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
    bool isConfidential = false,
    String? actualStartStatus,
    String? actualEndStatus,
    String? actualStartResetStatus,
    String? actualEndResetStatus,
    bool allowSampleData = true,
    List<int> workingDays = const [1, 2, 3, 4, 5],
    int workDayStartHour = 9,
    int workDayEndHour = 17,
    List<DateTime> publicHolidays = const [],
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
        isConfidential: _isCurrentUserSuperAdmin
            ? isConfidential
            : existing?.isConfidential ?? false,
        actualStartStatus: actualStartStatus,
        actualEndStatus: actualEndStatus,
        actualStartResetStatus: actualStartResetStatus,
        actualEndResetStatus: actualEndResetStatus,
        allowSampleData: allowSampleData,
        workingDays: workingDays,
        workDayStartHour: workDayStartHour,
        workDayEndHour: workDayEndHour,
        publicHolidays: publicHolidays,
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

  Future<void> saveProjectGrants({
    required String projectId,
    required Map<String, Set<String>> grantsByAssigneeId,
  }) {
    return _withBusy(() async {
      if (!canEditProject(projectId)) {
        throw Exception(
            'Only a Project Admin can manage permissions for this project.');
      }
      for (final assignee in _assignees) {
        final newGrants = grantsByAssigneeId[assignee.id] ?? {};
        final existing = {...(assignee.projectGrants[projectId] ?? [])};
        if (newGrants.difference(existing).isNotEmpty ||
            existing.difference(newGrants).isNotEmpty) {
          final updatedGrants = Map<String, List<String>>.from(
            assignee.projectGrants,
          );
          if (newGrants.isEmpty) {
            updatedGrants.remove(projectId);
          } else {
            updatedGrants[projectId] = newGrants.toList(growable: false);
          }
          await _assigneeRepository().saveAssignee(
            assignee.copyWith(
              projectGrants: updatedGrants,
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
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
      if (!canManageProjectRecords(projectId, type)) {
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
        updatedAt: now,
        updatedBy: currentUserName,
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
      await _writeRecordAddedNotifications(
        projectId: projectId,
        type: type,
        entryDescription: description.trim(),
      );
      _flashMessage = '${_recordTypeLabel(type)} added.';
    });
  }

  Future<void> updateProjectRecord({
    required String projectId,
    required ProjectRecordType type,
    required String entryId,
    String? assigneeId,
    bool clearAssigneeId = false,
    String? description,
    String? comments,
    String? status,
    RiskProbability? probability,
    bool clearProbability = false,
  }) {
    return _withBusy(() async {
      final project = projectById(projectId);
      if (project == null) {
        throw Exception('Project not found.');
      }
      if (!canManageProjectRecords(projectId, type)) {
        throw Exception('Only a Project Admin can edit log entries.');
      }
      final entries = List<ProjectRecordEntry>.from(
        projectRecords(type, projectId),
      );
      final idx = entries.indexWhere((e) => e.id == entryId);
      if (idx == -1) {
        throw Exception('Entry not found.');
      }
      final existing = entries[idx];
      final now = DateTime.now();
      entries[idx] = ProjectRecordEntry(
        id: existing.id,
        assigneeId:
            clearAssigneeId ? null : (assigneeId ?? existing.assigneeId),
        description: description ?? existing.description,
        comments: comments ?? existing.comments,
        status: status ?? existing.status,
        createdAt: existing.createdAt,
        updatedAt: now,
        updatedBy: currentUserName,
        probability:
            clearProbability ? null : (probability ?? existing.probability),
      );
      await _projectRepository().saveProject(
        _projectWithUpdatedRecords(project, type, entries),
      );
      _flashMessage = '${_recordTypeLabel(type)} updated.';
    });
  }

  Future<void> deleteProjectRecord({
    required String projectId,
    required ProjectRecordType type,
    required String entryId,
  }) {
    return _withBusy(() async {
      final project = projectById(projectId);
      if (project == null) {
        throw Exception('Project not found.');
      }
      if (!canManageProjectRecords(projectId, type)) {
        throw Exception('Only a Project Admin can delete log entries.');
      }
      final entries = List<ProjectRecordEntry>.from(
        projectRecords(type, projectId),
      )..removeWhere((e) => e.id == entryId);
      await _projectRepository().saveProject(
        _projectWithUpdatedRecords(project, type, entries),
      );
      _flashMessage = '${_recordTypeLabel(type)} deleted.';
    });
  }

  Future<void> saveTask({
    required String title,
    required String notes,
    required String projectId,
    required String status,
    required TaskPriority priority,
    required DateTime? startDate,
    required String duration,
    required DateTime? dueDate,
    required bool isMilestone,
    required List<String> predecessorTaskCodes,
    String? phaseId,
    String? assigneeId,
    String? taskId,
    String? changeSummary,
    DateTime? actualStartDate,
    DateTime? actualEndDate,
  }) {
    return _withBusy(() async {
      final project = projectById(projectId);
      if (project == null) {
        throw Exception('Select a valid project before saving a task.');
      }
      if (!canManageProjectWork(projectId)) {
        throw Exception(
            'You do not have permission to add or edit tasks on this project.');
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
        startDate: startDate,
        duration: duration.trim(),
        dueDate: dueDate,
        actualStartDate: actualStartDate,
        actualEndDate: actualEndDate,
        predecessorTaskCodes: normalizedPredecessors,
        assigneeId: assigneeId?.isEmpty ?? true ? null : assigneeId,
        phaseId: phaseId?.isEmpty ?? true ? null : phaseId,
        lastChangedAt: now,
        changeLog: changeLog,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _taskRepository().saveTask(task);
      await _writeTaskNotifications(task: task, existing: existing);
      _flashMessage = existing == null
          ? 'Task created with auto-generated ID $taskCode.'
          : 'Task updated.';
    });
  }

  Future<void> generateSampleData(String projectId) {
    return _withBusy(() async {
      if (!canEditProject(projectId)) {
        throw Exception('Only a Project Admin can generate sample data.');
      }
      final projectOrNull = projectById(projectId);
      if (projectOrNull == null) throw Exception('Project not found.');
      if (!projectOrNull.allowSampleData) {
        throw Exception('Sample data generation is disabled for this project.');
      }
      var project = projectOrNull;
      final now = DateTime.now();
      // ── Sample assignees ─────────────────────────────────────────────────
      final sampleAssignees = [
        ('Alex Johnson', 'alex.johnson@example.com'),
        ('Sam Rivera', 'sam.rivera@example.com'),
        ('Jordan Lee', 'jordan.lee@example.com'),
      ];
      for (final (name, email) in sampleAssignees) {
        final exists = _assignees.any(
          (a) => a.email.toLowerCase() == email.toLowerCase(),
        );
        if (!exists) {
          await _assigneeRepository().saveAssignee(
            AssigneeModel(
              id: '',
              name: name,
              email: email,
              role: AssigneeRole.projectUser,
              designation: 'Team Member',
              workHours: 'Mon–Fri, 9:00–17:00',
              projectIds: [projectId],
              createdAt: now,
              updatedAt: now,
            ),
          );
        } else {
          // Ensure they are assigned to this project.
          final existing =
              _assignees.firstWhereOrNull((a) => a.email.toLowerCase() == email);
          if (existing != null && !existing.projectIds.contains(projectId)) {
            await _assigneeRepository().saveAssignee(
              existing.copyWith(
                projectIds: [...existing.projectIds, projectId],
                updatedAt: now,
              ),
            );
          }
        }
      }
      // Reload assignees so task creation can reference their IDs.
      _assignees = await _assigneeRepository().watchAssignees().first;

      final assigneeIds = _assignees
          .where((a) => a.projectIds.contains(projectId))
          .map((a) => a.id)
          .toList(growable: false);
      String? _pick(int index) =>
          assigneeIds.isEmpty ? null : assigneeIds[index % assigneeIds.length];

      // ── Sample tasks ─────────────────────────────────────────────────────
      final statuses = project.taskStatuses;
      final sampleTasks = [
        (
          title: 'Define project requirements',
          status: statuses.contains('New') ? 'New' : statuses.first,
          priority: TaskPriority.high,
          startDate: now,
          duration: '3d',
          dueDate: now.add(const Duration(days: 7)),
          assignee: _pick(0),
        ),
        (
          title: 'Design system architecture',
          status: statuses.contains('In Progress') ? 'In Progress' : statuses.first,
          priority: TaskPriority.high,
          startDate: now.add(const Duration(days: 3)),
          duration: '1w',
          dueDate: now.add(const Duration(days: 14)),
          assignee: _pick(1),
        ),
        (
          title: 'Implement core features',
          status: statuses.contains('Backlog') ? 'Backlog' : statuses.first,
          priority: TaskPriority.medium,
          startDate: now.add(const Duration(days: 10)),
          duration: '2w',
          dueDate: now.add(const Duration(days: 30)),
          assignee: _pick(2),
        ),
        (
          title: 'Write unit tests',
          status: statuses.contains('New') ? 'New' : statuses.first,
          priority: TaskPriority.medium,
          startDate: now.add(const Duration(days: 14)),
          duration: '1w',
          dueDate: now.add(const Duration(days: 21)),
          assignee: _pick(0),
        ),
        (
          title: 'Deploy to production',
          status: statuses.contains('Backlog') ? 'Backlog' : statuses.first,
          priority: TaskPriority.low,
          startDate: now.add(const Duration(days: 30)),
          duration: '2d',
          dueDate: now.add(const Duration(days: 45)),
          assignee: _pick(1),
        ),
      ];
      for (final t in sampleTasks) {
        final taskCode = _generateNextTaskCode(projectId);
        final task = TaskModel(
          id: '',
          taskCode: taskCode,
          projectId: projectId,
          title: t.title,
          notes: '',
          status: t.status,
          priority: t.priority,
          isMilestone: false,
          startDate: t.startDate,
          duration: t.duration,
          dueDate: t.dueDate,
          predecessorTaskCodes: const [],
          assigneeId: t.assignee,
          phaseId: null,
          lastChangedAt: now,
          changeLog: [TaskChangeLogEntry(changedAt: now, description: 'Sample task created')],
          createdAt: now,
          updatedAt: now,
        );
        await _taskRepository().saveTask(task);
        // Reload tasks so next taskCode is correct.
        _tasks = await _taskRepository().watchTasks().first;
      }

      // ── Sample issues ─────────────────────────────────────────────────────
      final issueEntries = [
        ('Login page not rendering on Safari', 'Reproduced on Safari 17. Needs investigation.'),
        ('Data export fails for large datasets', 'Export times out when record count exceeds 10 000.'),
      ];
      for (final (desc, comments) in issueEntries) {
        final id = _generateNextProjectRecordId(project, ProjectRecordType.issue);
        final entry = ProjectRecordEntry(
          id: id,
          assigneeId: _pick(0),
          description: desc,
          comments: comments,
          status: defaultRecordStatuses.first,
          createdAt: now,
          updatedAt: now,
          updatedBy: currentUserName,
        );
        project = project.copyWith(
          issueLog: [...project.issueLog, entry],
          updatedAt: now,
        );
      }

      // ── Sample risks ──────────────────────────────────────────────────────
      final riskEntries = [
        ('Third-party API rate limits may affect performance', 'Evaluate caching strategies.', RiskProbability.medium),
        ('Key developer departure could delay timeline', 'Document knowledge and cross-train.', RiskProbability.high),
      ];
      for (final (desc, comments, prob) in riskEntries) {
        final id = _generateNextProjectRecordId(project, ProjectRecordType.risk);
        final entry = ProjectRecordEntry(
          id: id,
          assigneeId: _pick(1),
          description: desc,
          comments: comments,
          status: defaultRecordStatuses.first,
          createdAt: now,
          updatedAt: now,
          updatedBy: currentUserName,
          probability: prob,
        );
        project = project.copyWith(
          riskLog: [...project.riskLog, entry],
          updatedAt: now,
        );
      }

      // ── Sample actions ────────────────────────────────────────────────────
      final actionEntries = [
        ('Schedule weekly sync meetings', 'Set up recurring calendar invite for the team.'),
        ('Set up CI/CD pipeline', 'Automate build, test, and deployment steps.'),
      ];
      for (final (desc, comments) in actionEntries) {
        final id = _generateNextProjectRecordId(project, ProjectRecordType.action);
        final entry = ProjectRecordEntry(
          id: id,
          assigneeId: _pick(2),
          description: desc,
          comments: comments,
          status: defaultRecordStatuses.first,
          createdAt: now,
          updatedAt: now,
          updatedBy: currentUserName,
        );
        project = project.copyWith(
          actionLog: [...project.actionLog, entry],
          updatedAt: now,
        );
      }

      // ── Sample decisions ──────────────────────────────────────────────────
      final decisionEntries = [
        ('Use PostgreSQL as primary database', 'Chosen for ACID compliance and rich query support.'),
        ('Adopt Agile methodology', 'Two-week sprints with daily standups.'),
      ];
      for (final (desc, comments) in decisionEntries) {
        final id = _generateNextProjectRecordId(project, ProjectRecordType.decision);
        final entry = ProjectRecordEntry(
          id: id,
          assigneeId: _pick(0),
          description: desc,
          comments: comments,
          status: defaultRecordStatuses.first,
          createdAt: now,
          updatedAt: now,
          updatedBy: currentUserName,
        );
        project = project.copyWith(
          decisionLog: [...project.decisionLog, entry],
          updatedAt: now,
        );
      }

      await _projectRepository().saveProject(project);
      _flashMessage = 'Sample data generated for ${project.projectCode}.';
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
    List<OooRange> oooRanges = const [],
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
        oooRanges: oooRanges,
      );
      await _assigneeRepository().saveAssignee(assignee);
      _flashMessage = existing == null
          ? 'Assignee created.'
          : 'Assignee updated.';
    });
  }

  /// Allows any authenticated user to update their own OOO ranges without
  /// requiring the SuperAdmin role.
  Future<void> saveMyOoo(List<OooRange> oooRanges) {
    return _withBusy(() async {
      final id = _currentUserAssigneeId;
      final me = id == null
          ? null
          : _assignees.firstWhereOrNull((a) => a.id == id);
      if (me == null) {
        throw Exception('No profile found for the current user.');
      }
      final updated = me.copyWith(oooRanges: oooRanges);
      await _assigneeRepository().saveAssignee(updated);
      _flashMessage = 'Out-of-office dates saved.';
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
          'target_date',
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
          dueDate: _parseDate(row['target_date']),
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
    await _notificationSubscription?.cancel();

    if (user == null) {
      _projects = const [];
      _tasks = const [];
      _assignees = const [];
      _notifications = const [];
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
      _checkDueDateNotifications();
    }, onError: _handleAsyncError);
    _assigneeSubscription = _assigneeRepository().watchAssignees().listen((
      assignees,
    ) {
      _assignees = assignees;
      notifyListeners();
    }, onError: _handleAsyncError);
    _notificationSubscription =
        _notificationRepository().watchNotifications().listen((notifications) {
      _notifications = notifications;
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
    final email = _impersonatedAssignee?.email.toLowerCase() ??
        _user?.email?.trim().toLowerCase() ??
        '';
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
    final email = _impersonatedAssignee?.email.toLowerCase() ??
        _user?.email?.trim().toLowerCase() ??
        '';
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

  NotificationRepository _notificationRepository() {
    final firestore = _runtimeFirebaseService.firestore;
    final user = _user;
    if (firestore == null || user == null) {
      throw Exception('Not signed in.');
    }
    return NotificationRepository(firestore: firestore, userId: user.uid);
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
    // When impersonating, report the impersonated user's role
    if (_impersonatedAssignee != null) return _impersonatedAssignee!.role;
    final email = _user?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return null;
    return _assignees
        .firstWhereOrNull((assignee) => assignee.email.toLowerCase() == email)
        ?.role;
  }

  String? get _currentUserAssigneeId {
    final email = _impersonatedAssignee?.email.toLowerCase() ??
        _user?.email?.trim().toLowerCase() ??
        '';
    if (email.isEmpty) return null;
    return _assignees
        .firstWhereOrNull((a) => a.email.toLowerCase() == email)
        ?.id;
  }

  String? get _realUserAssigneeId {
    final email = _user?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return null;
    return _assignees
        .firstWhereOrNull((a) => a.email.toLowerCase() == email)
        ?.id;
  }

  bool get _isCurrentUserSuperAdmin =>
      _impersonatedAssignee == null &&
      _currentUserRole == AssigneeRole.superAdmin;

  bool _currentUserHasGrant(String projectId, String grant) {
    final email = _impersonatedAssignee?.email.toLowerCase() ??
        _user?.email?.trim().toLowerCase() ??
        '';
    if (email.isEmpty) return false;
    final assignee =
        _assignees.firstWhereOrNull((a) => a.email.toLowerCase() == email);
    if (assignee == null) return false;
    return assignee.projectGrants[projectId]?.contains(grant) ?? false;
  }

  /// Always reflects the real logged-in user, regardless of impersonation.
  bool get _isRealSuperAdmin {
    final email = _user?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) return false;
    return _assignees
            .firstWhereOrNull((a) => a.email.toLowerCase() == email)
            ?.role ==
        AssigneeRole.superAdmin;
  }

  bool get isSuperAdmin => _isCurrentUserSuperAdmin;

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

    final needsProjectId = !existing.projectIds.contains(project.id);
    final needsRoleUpgrade = existing.role != AssigneeRole.projectAdmin &&
        existing.role != AssigneeRole.superAdmin;

    if (needsProjectId || needsRoleUpgrade) {
      await _assigneeRepository().saveAssignee(
        existing.copyWith(
          // Only promote to projectAdmin — never demote a superAdmin
          role: existing.role == AssigneeRole.superAdmin
              ? AssigneeRole.superAdmin
              : AssigneeRole.projectAdmin,
          projectIds: {
            ...existing.projectIds,
            project.id,
          }.toList(growable: false),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  // ── Notification actions (no busy spinner — low-friction UX) ────────────

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _notificationRepository().markRead(notificationId);
    } catch (error) {
      _handleAsyncError(error);
    }
  }

  Future<void> markAllNotificationsRead() async {
    final assigneeId = _currentUserAssigneeId;
    if (assigneeId == null) return;
    try {
      await _notificationRepository().markAllRead(assigneeId);
    } catch (error) {
      _handleAsyncError(error);
    }
  }

  Future<void> dismissNotification(String notificationId) async {
    try {
      await _notificationRepository().deleteNotification(notificationId);
    } catch (error) {
      _handleAsyncError(error);
    }
  }

  // ── Notification helpers ─────────────────────────────────────────────────

  Future<void> _checkDueDateNotifications() async {
    if (_user == null) return;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (final task in _tasks) {
      if (task.assigneeId == null || task.assigneeId!.isEmpty) continue;
      if (task.isCompleted) continue;
      if (task.dueDate == null) continue;

      final taskDueDate = DateTime(
        task.dueDate!.year,
        task.dueDate!.month,
        task.dueDate!.day,
      );
      if (taskDueDate.isAfter(todayDate)) continue;

      final assigneeId = task.assigneeId!;
      try {
        final alreadyExists =
            await _notificationRepository().taskDueNotificationExists(
          taskId: task.id,
          recipientAssigneeId: assigneeId,
        );
        if (alreadyExists) continue;

        final project = projectById(task.projectId);
        final projectLabel = project?.projectCode ?? task.projectId;
        final isOverdue = taskDueDate.isBefore(todayDate);
        final dueDateLabel = DateFormat('yyyy-MM-dd').format(task.dueDate!);

        await _notificationRepository().addNotification(
          NotificationModel(
            id: '',
            recipientAssigneeId: assigneeId,
            type: NotificationType.taskDue,
            title: isOverdue
                ? 'Task overdue: ${task.title}'
                : 'Task due today: ${task.title}',
            body: '$projectLabel · Due $dueDateLabel',
            projectId: task.projectId,
            taskId: task.id,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {
        // Notification failure should not surface as a task error.
      }
    }
  }

  Future<void> _writeTaskNotifications({
    required TaskModel task,
    required TaskModel? existing,
  }) async {
    final assigneeId = task.assigneeId;
    if (assigneeId == null || assigneeId.isEmpty) return;

    final now = DateTime.now();
    final project = projectById(task.projectId);
    final projectLabel = project?.projectCode ?? task.projectId;
    final dueDateLabel = task.dueDate != null
        ? DateFormat('yyyy-MM-dd').format(task.dueDate!)
        : 'No due date';

    final assigneeChanged = existing?.assigneeId != task.assigneeId;
    if (assigneeChanged) {
      try {
        await _notificationRepository().addNotification(
          NotificationModel(
            id: '',
            recipientAssigneeId: assigneeId,
            type: NotificationType.taskAssigned,
            title: 'Task assigned: ${task.title}',
            body: '$projectLabel · Due $dueDateLabel',
            projectId: task.projectId,
            taskId: task.id.isEmpty ? null : task.id,
            isRead: false,
            createdAt: now,
          ),
        );
      } catch (_) {}
    }

    final statusChanged = existing != null &&
        existing.status != task.status &&
        !assigneeChanged;
    if (statusChanged) {
      try {
        await _notificationRepository().addNotification(
          NotificationModel(
            id: '',
            recipientAssigneeId: assigneeId,
            type: NotificationType.taskStatusChanged,
            title: 'Task status changed: ${task.title}',
            body: '$projectLabel · ${existing.status} → ${task.status}',
            projectId: task.projectId,
            taskId: task.id.isEmpty ? null : task.id,
            isRead: false,
            createdAt: now,
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _writeRecordAddedNotifications({
    required String projectId,
    required ProjectRecordType type,
    required String entryDescription,
  }) async {
    final members = _assignees
        .where((a) => a.projectIds.contains(projectId))
        .toList(growable: false);
    if (members.isEmpty) return;

    final now = DateTime.now();
    final project = projectById(projectId);
    final projectLabel = project?.projectCode ?? projectId;
    final typeLabel = _recordTypeLabel(type);
    final bodyText = entryDescription.length > 80
        ? '${entryDescription.substring(0, 80)}…'
        : entryDescription;

    for (final member in members) {
      try {
        await _notificationRepository().addNotification(
          NotificationModel(
            id: '',
            recipientAssigneeId: member.id,
            type: NotificationType.recordAdded,
            title: '$typeLabel added to $projectLabel',
            body: bodyText,
            projectId: projectId,
            taskId: null,
            isRead: false,
            createdAt: now,
          ),
        );
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _projectSubscription?.cancel();
    await _taskSubscription?.cancel();
    await _assigneeSubscription?.cancel();
    await _notificationSubscription?.cancel();
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
