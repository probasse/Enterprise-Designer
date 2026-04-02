import 'package:cloud_firestore/cloud_firestore.dart';

enum AssigneeRole { superAdmin, projectAdmin, projectUser, watcher }

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
    );
  }
}

AssigneeRole _roleFromString(String? value) {
  return AssigneeRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => AssigneeRole.projectUser,
  );
}

DateTime _readDate(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return DateTime.now();
}
