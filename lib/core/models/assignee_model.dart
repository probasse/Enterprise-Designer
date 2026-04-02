import 'package:cloud_firestore/cloud_firestore.dart';

enum AssigneeRole { superAdmin, projectAdmin, projectUser, watcher }

class OooRange {
  const OooRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory OooRange.fromMap(Map<String, dynamic> map) {
    return OooRange(
      start: _readDate(map['start']),
      end: _readDate(map['end']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
    };
  }
}

class AssigneeModel {
  const AssigneeModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.designation,
    required this.workHours,
    required this.projectIds,
    required this.createdAt,
    required this.updatedAt,
    this.projectGrants = const {},
    this.oooRanges = const [],
  });

  final String id;
  final String name;
  final String email;
  final AssigneeRole role;
  final String designation;
  final String workHours;
  final List<String> projectIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Maps projectId → list of capability grants (e.g. ['tasks', 'records']).
  /// Only meaningful for ProjectUser role; other roles use role-based access.
  final Map<String, List<String>> projectGrants;

  /// Out-of-office date ranges (self-service, informational).
  final List<OooRange> oooRanges;

  factory AssigneeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AssigneeModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: _roleFromString(data['role'] as String?),
      designation: data['designation'] as String? ?? '',
      workHours: data['workHours'] as String? ?? '',
      projectIds: (data['projectIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      projectGrants: _readProjectGrants(data['projectGrants']),
      oooRanges: (data['oooRanges'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OooRange.fromMap)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'designation': designation,
      'workHours': workHours,
      'projectIds': projectIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'projectGrants': projectGrants.map(
        (projectId, grants) => MapEntry(projectId, grants),
      ),
      'oooRanges': oooRanges.map((r) => r.toMap()).toList(),
    };
  }

  AssigneeModel copyWith({
    String? id,
    String? name,
    String? email,
    AssigneeRole? role,
    String? designation,
    String? workHours,
    List<String>? projectIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, List<String>>? projectGrants,
    List<OooRange>? oooRanges,
  }) {
    return AssigneeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      workHours: workHours ?? this.workHours,
      projectIds: projectIds ?? this.projectIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectGrants: projectGrants ?? this.projectGrants,
      oooRanges: oooRanges ?? this.oooRanges,
    );
  }
}

AssigneeRole _roleFromString(String? value) {
  return AssigneeRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => AssigneeRole.projectUser,
  );
}

Map<String, List<String>> _readProjectGrants(Object? value) {
  if (value is! Map) return const {};
  return Map.fromEntries(
    value.entries.map((entry) {
      final grants = entry.value;
      final grantList = grants is List
          ? grants.map((g) => g.toString()).toList(growable: false)
          : <String>[];
      return MapEntry(entry.key.toString(), grantList);
    }),
  );
}

DateTime _readDate(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return DateTime.now();
}
