import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> logAction({
  required String category,
  required String action,
  required String itemId,
  required String userId,
  Map<String, dynamic>? oldData,
  Map<String, dynamic>? newData,
  String? customTimestamp, // اختياري: إذا كنت تريد تحديد تاريخ مخصص
}) async {
  final logData = {
    'category': category,
    'action': action,
    'itemId': itemId,
    'user': userId,
    'timestamp': customTimestamp ?? FieldValue.serverTimestamp(),
    'oldData': oldData,
    'newData': newData,
    'lastUpdated': FieldValue.serverTimestamp(), // سيتم تحديثه تلقائيًا
  };

  await FirebaseFirestore.instance.collection('logs').add(logData);
}
