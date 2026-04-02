import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { taskAssigned, taskStatusChanged, taskDue, recordAdded }

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.recipientAssigneeId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.projectId,
    this.taskId,
  });

  final String id;
  final String recipientAssigneeId;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? projectId;
  final String? taskId;

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return NotificationModel(
      id: doc.id,
      recipientAssigneeId: data['recipientAssigneeId'] as String? ?? '',
      type: _typeFromString(data['type'] as String?),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: _readDate(data['createdAt']),
      projectId: data['projectId'] as String?,
      taskId: data['taskId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recipientAssigneeId': recipientAssigneeId,
      'type': type.name,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'projectId': projectId,
      'taskId': taskId,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? recipientAssigneeId,
    NotificationType? type,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    String? projectId,
    bool clearProjectId = false,
    String? taskId,
    bool clearTaskId = false,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      recipientAssigneeId: recipientAssigneeId ?? this.recipientAssigneeId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      projectId: clearProjectId ? null : projectId ?? this.projectId,
      taskId: clearTaskId ? null : taskId ?? this.taskId,
    );
  }

  static NotificationType _typeFromString(String? value) {
    return NotificationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationType.taskAssigned,
    );
  }
}

DateTime _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  return DateTime.now();
}
