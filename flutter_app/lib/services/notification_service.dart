import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static Future<void> send({
    required String userId,
    required String type,
    required String message,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'type': type,
      'message': message,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}