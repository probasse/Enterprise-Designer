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
    this.dueDate,
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
  final DateTime? dueDate;
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
      dueDate: _readNullableDate(data['dueDate']),
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
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
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
    DateTime? dueDate,
    bool clearDueDate = false,
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
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
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
