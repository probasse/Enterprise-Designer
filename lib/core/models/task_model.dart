import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high }

class TaskChangeLogEntry {
  const TaskChangeLogEntry({
    required this.changedAt,
    required this.description,
  });

  final DateTime changedAt;
  final String description;

  Map<String, dynamic> toFirestore() {
    return {
      'changedAt': Timestamp.fromDate(changedAt),
      'description': description,
    };
  }

  factory TaskChangeLogEntry.fromMap(Map<String, dynamic> map) {
    return TaskChangeLogEntry(
      changedAt: _readDate(map['changedAt']),
      description: map['description'] as String? ?? '',
    );
  }

  String toCsvToken() {
    return '${changedAt.toIso8601String()}::$description';
  }

  static TaskChangeLogEntry fromCsvToken(String token) {
    final separatorIndex = token.indexOf('::');
    if (separatorIndex == -1) {
      return TaskChangeLogEntry(
        changedAt: DateTime.now(),
        description: token.trim(),
      );
    }

    return TaskChangeLogEntry(
      changedAt:
          DateTime.tryParse(token.substring(0, separatorIndex)) ??
          DateTime.now(),
      description: token.substring(separatorIndex + 2),
    );
  }
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.taskCode,
    required this.projectId,
    required this.title,
    required this.notes,
    required this.status,
    required this.priority,
    required this.isMilestone,
    required this.lastChangedAt,
    required this.changeLog,
    required this.createdAt,
    required this.updatedAt,
    this.startDate,
    this.duration = '',
    this.dueDate,
    this.actualStartDate,
    this.actualEndDate,
    this.predecessorTaskCodes = const [],
    this.assigneeId,
    this.phaseId,
  });

  final String id;
  final String taskCode;
  final String projectId;
  final String title;
  final String notes;
  final String status;
  final TaskPriority priority;
  final bool isMilestone;
  final DateTime? startDate;
  final String duration;
  final DateTime? dueDate;
  final DateTime? actualStartDate;
  final DateTime? actualEndDate;
  final List<String> predecessorTaskCodes;
  final String? assigneeId;
  final String? phaseId;
  final DateTime lastChangedAt;
  final List<TaskChangeLogEntry> changeLog;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == 'Completed';

  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;

  /// Computed end date = startDate + duration. Null if either is absent.
  DateTime? get endDate {
    if (startDate == null || duration.trim().isEmpty) return null;
    return applyTaskDuration(startDate!, duration.trim());
  }

  factory TaskModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawChangeLog = data['changeLog'] as List<dynamic>? ?? const [];
    return TaskModel(
      id: doc.id,
      taskCode: data['taskCode'] as String? ?? doc.id,
      projectId: data['projectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      status: data['status'] as String? ?? 'New',
      priority: _priorityFromString(data['priority'] as String?),
      isMilestone: data['isMilestone'] as bool? ?? false,
      startDate: _readNullableDate(data['startDate']),
      duration: data['duration'] as String? ?? '',
      dueDate: _readNullableDate(data['dueDate']),
      actualStartDate: _readNullableDate(data['actualStartDate']),
      actualEndDate: _readNullableDate(data['actualEndDate']),
      predecessorTaskCodes:
          (data['predecessorTaskCodes'] as List<dynamic>? ??
                  (data['predecessorTaskCode'] == null
                      ? const []
                      : [data['predecessorTaskCode']]))
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false),
      assigneeId: data['assigneeId'] as String?,
      phaseId: data['phaseId'] as String?,
      lastChangedAt: _readDate(data['lastChangedAt']),
      changeLog: rawChangeLog
          .whereType<Map<String, dynamic>>()
          .map(TaskChangeLogEntry.fromMap)
          .toList(growable: false),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskCode': taskCode,
      'projectId': projectId,
      'title': title,
      'notes': notes,
      'status': status,
      'priority': priority.name,
      'isMilestone': isMilestone,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'duration': duration,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'actualStartDate': actualStartDate == null ? null : Timestamp.fromDate(actualStartDate!),
      'actualEndDate': actualEndDate == null ? null : Timestamp.fromDate(actualEndDate!),
      'predecessorTaskCodes': predecessorTaskCodes,
      'assigneeId': assigneeId,
      'phaseId': phaseId,
      'lastChangedAt': Timestamp.fromDate(lastChangedAt),
      'changeLog': changeLog.map((entry) => entry.toFirestore()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TaskModel copyWith({
    String? id,
    String? taskCode,
    String? projectId,
    String? title,
    String? notes,
    String? status,
    TaskPriority? priority,
    bool? isMilestone,
    DateTime? startDate,
    bool clearStartDate = false,
    String? duration,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? actualStartDate,
    bool clearActualStartDate = false,
    DateTime? actualEndDate,
    bool clearActualEndDate = false,
    List<String>? predecessorTaskCodes,
    String? assigneeId,
    bool clearAssigneeId = false,
    String? phaseId,
    bool clearPhaseId = false,
    DateTime? lastChangedAt,
    List<TaskChangeLogEntry>? changeLog,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      taskCode: taskCode ?? this.taskCode,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isMilestone: isMilestone ?? this.isMilestone,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      duration: duration ?? this.duration,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      actualStartDate: clearActualStartDate ? null : actualStartDate ?? this.actualStartDate,
      actualEndDate: clearActualEndDate ? null : actualEndDate ?? this.actualEndDate,
      predecessorTaskCodes: predecessorTaskCodes ?? this.predecessorTaskCodes,
      assigneeId: clearAssigneeId ? null : assigneeId ?? this.assigneeId,
      phaseId: clearPhaseId ? null : phaseId ?? this.phaseId,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
      changeLog: changeLog ?? this.changeLog,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static TaskPriority _priorityFromString(String? value) {
    return TaskPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => TaskPriority.medium,
    );
  }
}

DateTime _readDate(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return DateTime.now();
}

DateTime? _readNullableDate(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return null;
}

/// Returns true if [date] is a working day given the project calendar.
bool _isWorkingDay(
  DateTime date,
  List<int> workingDays,
  List<DateTime> holidays,
) {
  if (!workingDays.contains(date.weekday)) return false;
  return !holidays.any(
    (h) => h.year == date.year && h.month == date.month && h.day == date.day,
  );
}

/// Returns the next working day on or after [date] (time preserved).
DateTime _nextWorkingDay(
  DateTime date,
  List<int> workingDays,
  List<DateTime> holidays,
) {
  var d = date;
  while (!_isWorkingDay(d, workingDays, holidays)) {
    d = DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
  }
  return d;
}

/// Applies a duration string to [start] and returns the resulting [DateTime].
///
/// Format:
///   `5`   → 5 working hours
///   `5d`  → 5 working days  (lands at workDayStartHour on day 5)
///   `2w`  → 2 working weeks (14 working days)
///   `1mo` → 1 calendar month → snapped to next working day at workDayStartHour
///
/// When [workingDays] / [publicHolidays] are supplied the calculation skips
/// non-working days and holidays.  Defaults fall back to Mon–Fri, 09:00–17:00.
DateTime applyTaskDuration(
  DateTime start,
  String raw, {
  List<int> workingDays = const [1, 2, 3, 4, 5],
  int workDayStartHour = 9,
  int workDayEndHour = 17,
  List<DateTime> publicHolidays = const [],
}) {
  final s = raw.toLowerCase().trim();

  if (s.endsWith('mo')) {
    // Calendar months, then snap to next working day at start-of-day hour.
    final n = int.tryParse(s.replaceAll('mo', '')) ?? 0;
    final raw = DateTime(
        start.year, start.month + n, start.day, workDayStartHour, 0);
    return _nextWorkingDay(raw, workingDays, publicHolidays);
  }

  int totalWorkingDays;
  if (s.endsWith('w')) {
    totalWorkingDays = (int.tryParse(s.replaceAll('w', '')) ?? 0) * 5;
  } else if (s.endsWith('d')) {
    totalWorkingDays = int.tryParse(s.replaceAll('d', '')) ?? 0;
  } else {
    // Hours — count working hours forward.
    final totalHours = int.tryParse(s) ?? 0;
    if (totalHours <= 0) return start;
    final hoursPerDay = (workDayEndHour - workDayStartHour).clamp(1, 24);
    var current = start;
    int hoursLeft = totalHours;
    while (hoursLeft > 0) {
      // Advance to a working day if needed.
      current = _nextWorkingDay(current, workingDays, publicHolidays);
      // Clamp current time to within working hours.
      if (current.hour < workDayStartHour) {
        current = DateTime(current.year, current.month, current.day,
            workDayStartHour, 0);
      } else if (current.hour >= workDayEndHour) {
        // Past end of day — move to next calendar day start.
        current = _nextWorkingDay(
          DateTime(current.year, current.month, current.day + 1,
              workDayStartHour, 0),
          workingDays,
          publicHolidays,
        );
      }
      final hoursRemainingToday = workDayEndHour - current.hour;
      if (hoursLeft <= hoursRemainingToday) {
        return DateTime(current.year, current.month, current.day,
            current.hour + hoursLeft, current.minute);
      }
      hoursLeft -= hoursRemainingToday;
      // Move to start of next calendar day.
      current = DateTime(current.year, current.month, current.day + 1,
          workDayStartHour, 0);
    }
    return current;
  }

  // Days / weeks: count N working days forward, land at workDayStartHour.
  if (totalWorkingDays <= 0) return start;
  var current = DateTime(start.year, start.month, start.day + 1,
      workDayStartHour, 0);
  int daysLeft = totalWorkingDays;
  while (true) {
    if (_isWorkingDay(current, workingDays, publicHolidays)) {
      daysLeft--;
      if (daysLeft == 0) return current;
    }
    current = DateTime(
        current.year, current.month, current.day + 1, workDayStartHour, 0);
  }
}

/// Computes a task's end date using the project's work calendar.
/// Use this instead of [TaskModel.endDate] when a [ProjectModel] is in scope.
DateTime? computeTaskEndDate(TaskModel task, dynamic project) {
  if (task.startDate == null || task.duration.trim().isEmpty) return null;
  // Accept dynamic so task_model.dart doesn't import project_model.dart.
  // Callers pass a ProjectModel; we duck-type the fields we need.
  try {
    return applyTaskDuration(
      task.startDate!,
      task.duration.trim(),
      workingDays: (project.workingDays as List).cast<int>(),
      workDayStartHour: project.workDayStartHour as int,
      workDayEndHour: project.workDayEndHour as int,
      publicHolidays: (project.publicHolidays as List).cast<DateTime>(),
    );
  } catch (_) {
    return task.endDate;
  }
}
