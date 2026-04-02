import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/project_model.dart';

class ProjectRepository {
  ProjectRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('projects');

  Stream<List<ProjectModel>> watchProjects() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ProjectModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<String> saveProject(ProjectModel project) async {
    if (project.id.isEmpty) {
      final doc = await _collection.add(project.toFirestore());
      return doc.id;
    }

    await _collection.doc(project.id).set(project.toFirestore());
    return project.id;
  }

  Future<void> deleteProject(String projectId) {
    return _collection.doc(projectId).delete();
  }
}
