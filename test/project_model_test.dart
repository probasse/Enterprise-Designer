import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_planner/core/models/project_model.dart';

void main() {
  test('project record entries serialize risk probability', () {
    final entry = ProjectRecordEntry(
      id: 'PRJ-001-RSK-001',
      assigneeId: 'assignee-1',
      description: 'Potential API delay',
      comments: 'Vendor has not confirmed dates yet',
      status: 'Blocked',
      probability: RiskProbability.high,
      createdAt: DateTime(2026, 4, 1, 10),
    );

    final json = entry.toMap();

    expect(json['id'], 'PRJ-001-RSK-001');
    expect(json['probability'], 'high');
    expect(json['createdAt'], isA<Timestamp>());
  });
}
