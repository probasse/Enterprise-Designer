import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({
    required FirebaseFirestore firestore,
    required String userId,
  })  : _firestore = firestore,
        _userId = userId;

  final FirebaseFirestore _firestore;
  final String _userId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_userId).collection('notifications');

  Stream<List<NotificationModel>> watchNotifications() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(NotificationModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> addNotification(NotificationModel notification) async {
    await _collection.add(notification.toFirestore());
  }

  Future<void> markRead(String notificationId) {
    return _collection.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllRead(String recipientAssigneeId) async {
    final snapshot = await _collection
        .where('recipientAssigneeId', isEqualTo: recipientAssigneeId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;

    const batchSize = 500;
    for (var i = 0; i < snapshot.docs.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = snapshot.docs.skip(i).take(batchSize);
      for (final doc in chunk) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> deleteNotification(String notificationId) {
    return _collection.doc(notificationId).delete();
  }

  Future<bool> taskDueNotificationExists({
    required String taskId,
    required String recipientAssigneeId,
  }) async {
    final snapshot = await _collection
        .where('taskId', isEqualTo: taskId)
        .where('type', isEqualTo: NotificationType.taskDue.name)
        .where('recipientAssigneeId', isEqualTo: recipientAssigneeId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
