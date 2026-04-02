import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';

class TaskRepository {
  TaskRepository({required FirebaseFirestore firestore, required String userId})
    : _firestore = firestore,
      _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('tasks');

  Stream<List<TaskModel>> watchTasks() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(TaskModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> saveTask(TaskModel task) async {
    if (task.id.isEmpty) {
      await _collection.add(task.toFirestore());
      return;
    }

    await _collection.doc(task.id).set(task.toFirestore());
  }

  Future<void> deleteTask(String taskId) {
    return _collection.doc(taskId).delete();
  }
}
