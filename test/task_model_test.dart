import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_planner/core/models/task_model.dart';

void main() {
  test('task toFirestore serializes enum names and due date', () {
    final task = TaskModel(
      id: 'task-1',
      taskCode: 'TASK-1',
      projectId: 'project-1',
      title: 'Ship project planner',
      notes: 'Verify web layout',
      status: 'In Progress',
      priority: TaskPriority.high,
      isMilestone: true,
      dueDate: DateTime(2026, 4, 2),
      predecessorTaskCodes: const ['TASK-0', 'TASK-0B'],
      assigneeId: 'assignee-1',
      phaseId: 'PH-001',
      lastChangedAt: DateTime(2026, 4, 1, 13),
      changeLog: [
        TaskChangeLogEntry(
          changedAt: DateTime(2026, 4, 1, 13),
          description: 'Task created',
        ),
      ],
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1, 12),
    );

    final json = task.toFirestore();

    expect(json['taskCode'], 'TASK-1');
    expect(json['status'], 'In Progress');
    expect(json['priority'], 'high');
    expect(json['isMilestone'], isTrue);
    expect(json['predecessorTaskCodes'], ['TASK-0', 'TASK-0B']);
    expect(json['phaseId'], 'PH-001');
    expect(json['changeLog'], isA<List<dynamic>>());
    expect(json['dueDate'], isA<Timestamp>());
  });

  test('copyWith can clear due date', () {
    final task = TaskModel(
      id: 'task-1',
      taskCode: 'TASK-1',
      projectId: 'project-1',
      title: 'Ship project planner',
      notes: 'Verify web layout',
      status: 'In Progress',
      priority: TaskPriority.high,
      isMilestone: false,
      dueDate: DateTime(2026, 4, 2),
      predecessorTaskCodes: const ['TASK-0'],
      assigneeId: 'assignee-1',
      phaseId: 'PH-001',
      lastChangedAt: DateTime(2026, 4, 1, 13),
      changeLog: const [],
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1, 12),
    );

    final updated = task.copyWith(clearDueDate: true);

    expect(updated.dueDate, isNull);
  });
}
