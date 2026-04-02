import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/assignee_model.dart';

class AssigneeRepository {
  AssigneeRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('assignees');

  Stream<List<AssigneeModel>> watchAssignees() {
    return _collection
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AssigneeModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> saveAssignee(AssigneeModel assignee) async {
    if (assignee.id.isEmpty) {
      await _collection.add(assignee.toFirestore());
      return;
    }

    await _collection.doc(assignee.id).set(assignee.toFirestore());
  }

  Future<void> deleteAssignee(String assigneeId) {
    return _collection.doc(assigneeId).delete();
  }
}
