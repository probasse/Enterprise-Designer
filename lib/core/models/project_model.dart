import 'package:cloud_firestore/cloud_firestore.dart';

const defaultProjectStatuses = <String>[
  'New',
  'Backlog',
  'In Progress',
  'Test',
  'Completed',
  'Blocked',
  'On Hold',
];

const defaultRecordStatuses = <String>[
  'New',
  'In Progress',
  'On Hold',
  'Blocked',
  'Completed',
];

enum RiskProbability { low, medium, high }

enum ProjectRecordType { issue, risk, action, decision }

class ProjectPhase {
  const ProjectPhase({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;

  factory ProjectPhase.fromMap(Map<String, dynamic> map) {
    return ProjectPhase(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      startDate: _readNullableDate(map['startDate']),
      endDate: _readNullableDate(map['endDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
    };
  }
}

class ProjectRecordEntry {
  const ProjectRecordEntry({
    required this.id,
    required this.assigneeId,
    required this.description,
    required this.comments,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy = '',
    this.probability,
  });

  final String id;
  final String? assigneeId;
  final String description;
  final String comments;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String updatedBy;
  final RiskProbability? probability;

  factory ProjectRecordEntry.fromMap(Map<String, dynamic> map) {
    return ProjectRecordEntry(
      id: map['id'] as String? ?? '',
      assigneeId: map['assigneeId'] as String?,
      description:
          map['description'] as String? ?? map['title'] as String? ?? '',
      comments: map['comments'] as String? ?? map['details'] as String? ?? '',
      status: map['status'] as String? ?? defaultRecordStatuses.first,
      createdAt: _readDate(map['createdAt'] ?? map['changedAt']),
      updatedAt: _readNullableDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String? ?? '',
      probability: _probabilityFromString(map['probability'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assigneeId': assigneeId,
      'description': description,
      'comments': comments,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedBy': updatedBy,
      'probability': probability?.name,
    };
  }
}

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.projectCode,
    required this.title,
    required this.description,
    required this.timezone,
    required this.startDate,
    required this.endDate,
    required this.phases,
    required this.taskStatuses,
    required this.issueLog,
    required this.riskLog,
    required this.actionLog,
    required this.decisionLog,
    required this.ownerEmail,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.isConfidential = false,
    this.actualStartStatus,
    this.actualEndStatus,
    this.actualStartResetStatus,
    this.actualEndResetStatus,
    this.allowSampleData = true,
    this.workingDays = const [1, 2, 3, 4, 5],
    this.workDayStartHour = 9,
    this.workDayEndHour = 17,
    this.publicHolidays = const [],
  });

  final String id;
  final String projectCode;
  final String title;
  final String description;
  final String timezone;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ProjectPhase> phases;
  final List<String> taskStatuses;
  final List<ProjectRecordEntry> issueLog;
  final List<ProjectRecordEntry> riskLog;
  final List<ProjectRecordEntry> actionLog;
  final List<ProjectRecordEntry> decisionLog;
  final String ownerEmail;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isConfidential;
  final String? actualStartStatus;
  final String? actualEndStatus;
  final String? actualStartResetStatus;  // status that clears actualStartDate
  final String? actualEndResetStatus;    // status that clears actualEndDate
  final bool allowSampleData;
  final List<int> workingDays;      // ISO weekday: 1=Mon … 7=Sun
  final int workDayStartHour;       // 0–23
  final int workDayEndHour;         // 0–23
  final List<DateTime> publicHolidays;

  factory ProjectModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ProjectModel(
      id: doc.id,
      projectCode: data['projectCode'] as String? ?? doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      timezone: data['timezone'] as String? ?? 'Local',
      startDate: _readNullableDate(data['startDate']),
      endDate: _readNullableDate(data['endDate']),
      phases: _readPhaseList(data['phases']),
      taskStatuses:
          (data['taskStatuses'] as List<dynamic>? ?? defaultProjectStatuses)
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toSet()
              .toList(growable: false),
      issueLog: _readRecordList(data['issueLog']),
      riskLog: _readRecordList(data['riskLog']),
      actionLog: _readRecordList(data['actionLog']),
      decisionLog: _readRecordList(data['decisionLog']),
      ownerEmail: data['ownerEmail'] as String? ?? '',
      colorValue: data['colorValue'] as int? ?? 0xFF255F4A,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      isConfidential: data['isConfidential'] as bool? ?? false,
      actualStartStatus: data['actualStartStatus'] as String?,
      actualEndStatus: data['actualEndStatus'] as String?,
      actualStartResetStatus: data['actualStartResetStatus'] as String?,
      actualEndResetStatus: data['actualEndResetStatus'] as String?,
      allowSampleData: data['allowSampleData'] as bool? ?? true,
      workingDays: (data['workingDays'] as List<dynamic>? ?? const [1, 2, 3, 4, 5])
          .map((v) => (v as num).toInt())
          .toList(growable: false),
      workDayStartHour: data['workDayStartHour'] as int? ?? 9,
      workDayEndHour: data['workDayEndHour'] as int? ?? 17,
      publicHolidays: (data['publicHolidays'] as List<dynamic>? ?? const [])
          .whereType<Timestamp>()
          .map((ts) => ts.toDate())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectCode': projectCode,
      'title': title,
      'description': description,
      'timezone': timezone,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'phases': phases.map((phase) => phase.toMap()).toList(),
      'taskStatuses': taskStatuses,
      'issueLog': issueLog.map((entry) => entry.toMap()).toList(),
      'riskLog': riskLog.map((entry) => entry.toMap()).toList(),
      'actionLog': actionLog.map((entry) => entry.toMap()).toList(),
      'decisionLog': decisionLog.map((entry) => entry.toMap()).toList(),
      'ownerEmail': ownerEmail,
      'colorValue': colorValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isConfidential': isConfidential,
      'actualStartStatus': actualStartStatus,
      'actualEndStatus': actualEndStatus,
      'actualStartResetStatus': actualStartResetStatus,
      'actualEndResetStatus': actualEndResetStatus,
      'allowSampleData': allowSampleData,
      'workingDays': workingDays,
      'workDayStartHour': workDayStartHour,
      'workDayEndHour': workDayEndHour,
      'publicHolidays': publicHolidays.map((d) => Timestamp.fromDate(d)).toList(),
    };
  }

  ProjectModel copyWith({
    String? id,
    String? projectCode,
    String? title,
    String? description,
    String? timezone,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    List<ProjectPhase>? phases,
    List<String>? taskStatuses,
    List<ProjectRecordEntry>? issueLog,
    List<ProjectRecordEntry>? riskLog,
    List<ProjectRecordEntry>? actionLog,
    List<ProjectRecordEntry>? decisionLog,
    String? ownerEmail,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isConfidential,
    String? actualStartStatus,
    bool clearActualStartStatus = false,
    String? actualEndStatus,
    bool clearActualEndStatus = false,
    String? actualStartResetStatus,
    bool clearActualStartResetStatus = false,
    String? actualEndResetStatus,
    bool clearActualEndResetStatus = false,
    bool? allowSampleData,
    List<int>? workingDays,
    int? workDayStartHour,
    int? workDayEndHour,
    List<DateTime>? publicHolidays,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      projectCode: projectCode ?? this.projectCode,
      title: title ?? this.title,
      description: description ?? this.description,
      timezone: timezone ?? this.timezone,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      phases: phases ?? this.phases,
      taskStatuses: taskStatuses ?? this.taskStatuses,
      issueLog: issueLog ?? this.issueLog,
      riskLog: riskLog ?? this.riskLog,
      actionLog: actionLog ?? this.actionLog,
      decisionLog: decisionLog ?? this.decisionLog,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isConfidential: isConfidential ?? this.isConfidential,
      actualStartStatus: clearActualStartStatus ? null : actualStartStatus ?? this.actualStartStatus,
      actualEndStatus: clearActualEndStatus ? null : actualEndStatus ?? this.actualEndStatus,
      actualStartResetStatus: clearActualStartResetStatus ? null : actualStartResetStatus ?? this.actualStartResetStatus,
      actualEndResetStatus: clearActualEndResetStatus ? null : actualEndResetStatus ?? this.actualEndResetStatus,
      allowSampleData: allowSampleData ?? this.allowSampleData,
      workingDays: workingDays ?? this.workingDays,
      workDayStartHour: workDayStartHour ?? this.workDayStartHour,
      workDayEndHour: workDayEndHour ?? this.workDayEndHour,
      publicHolidays: publicHolidays ?? this.publicHolidays,
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

List<ProjectRecordEntry> _readRecordList(Object? value) {
  final list = value as List<dynamic>? ?? const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(ProjectRecordEntry.fromMap)
      .toList(growable: false);
}

RiskProbability? _probabilityFromString(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return RiskProbability.values.firstWhere(
    (probability) => probability.name == value,
    orElse: () => RiskProbability.medium,
  );
}

List<ProjectPhase> _readPhaseList(Object? value) {
  final list = value as List<dynamic>? ?? const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(ProjectPhase.fromMap)
      .toList(growable: false);
}
