import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FreeNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // مفتاح الخادم من Firebase Console > Project Settings > Cloud Messaging > Server key
  static const String _serverKey =
      'BBduiuKBkLJT3b3c9TY-5DyOIU1KkOzYhlnZbcm7BDGHRrUvLU-i_fBWgnLYCjarb8X1S0230SvlCaPI4mA1RNg'; // استبدل بمفتاح الخادم الخاص بك

  // تهيئة خدمة الإشعارات المجانية
  static Future<void> initialize() async {
    try {
      // طلب الإذن للإشعارات
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('تم منح إذن الإشعارات');

        // الحصول على FCM Token
        String? token = await _firebaseMessaging.getToken(
          vapidKey:
              kIsWeb
                  ? 'BBduiuKBkLJT3b3c9TY-5DyOIU1KkOzYhlnZbcm7BDGHRrUvLU-i_fBWgnLYCjarb8X1S0230SvlCaPI4mA1RNg'
                  : null,
        );

        if (token != null) {
          print('FCM Token: $token');
          await _saveTokenToDatabase(token);

          // الاشتراك في موضوع عام لجميع المستخدمين
          await _firebaseMessaging.subscribeToTopic('all_users');
        }

        // الاستماع للرسائل في المقدمة
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // الاستماع لفتح الإشعارات
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // التحقق من الرسائل عند فتح التطبيق
        RemoteMessage? initialMessage =
            await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      } else {
        print('تم رفض إذن الإشعارات');
      }
    } catch (e) {
      print('خطأ في تهيئة خدمة الإشعارات: $e');
    }
  }

  // حفظ الـ Token في قاعدة البيانات
  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      await _firestore.collection('user_tokens').doc(token).set({
        'token': token,
        'platform': kIsWeb ? 'web' : 'mobile',
        'timestamp': FieldValue.serverTimestamp(),
        'active': true,
        'topics': ['all_users'], // المواضيع المشترك فيها
      });
      print('تم حفظ FCM Token في قاعدة البيانات');
    } catch (e) {
      print('خطأ في حفظ FCM Token: $e');
    }
  }

  // التعامل مع الرسائل في المقدمة
  static void _handleForegroundMessage(RemoteMessage message) {
    print('تم استقبال رسالة في المقدمة: ${message.notification?.title}');

    if (message.notification != null) {
      _showInAppNotification(
        message.notification!.title ?? 'إشعار جديد',
        message.notification!.body ?? 'لديك تحديث جديد',
      );
    }
  }

  // التعامل مع فتح الإشعارات
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('تم فتح الإشعار: ${message.notification?.title}');

    if (message.data.containsKey('page')) {
      String page = message.data['page'];
      _navigateToPage(page);
    }
  }

  // عرض إشعار داخل التطبيق
  static void _showInAppNotification(String title, String body) {
    print('إشعار داخل التطبيق: $title - $body');
  }

  // التنقل إلى صفحة معينة
  static void _navigateToPage(String page) {
    print('التنقل إلى صفحة: $page');
  }

  // إرسال إشعار لجميع المستخدمين (مجاني 100%)
  static Future<void> sendNotificationToAll({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // إرسال إلى موضوع all_users
      await _sendToTopic(
        topic: 'all_users',
        title: title,
        body: body,
        data: data,
      );

      // حفظ الإشعار في قاعدة البيانات للتاريخ
      await _saveNotificationHistory(
        title: title,
        body: body,
        target: 'all_users',
        data: data,
      );

      print('تم إرسال الإشعار لجميع المستخدمين');
    } catch (e) {
      print('خطأ في إرسال الإشعار: $e');
    }
  }

  // إرسال إشعار لمستخدم محدد (مجاني 100%)
  static Future<void> sendNotificationToUser({
    required String userToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _sendToToken(
        token: userToken,
        title: title,
        body: body,
        data: data,
      );

      // حفظ الإشعار في قاعدة البيانات للتاريخ
      await _saveNotificationHistory(
        title: title,
        body: body,
        target: userToken,
        data: data,
      );

      print('تم إرسال الإشعار للمستخدم');
    } catch (e) {
      print('خطأ في إرسال الإشعار للمستخدم: $e');
    }
  }

  // إرسال إشعار لموضوع محدد (مجاني 100%)
  static Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await _sendToTopic(topic: topic, title: title, body: body, data: data);

      // حفظ الإشعار في قاعدة البيانات للتاريخ
      await _saveNotificationHistory(
        title: title,
        body: body,
        target: 'topic:$topic',
        data: data,
      );

      print('تم إرسال الإشعار للموضوع: $topic');
    } catch (e) {
      print('خطأ في إرسال الإشعار للموضوع: $e');
    }
  }

  // إرسال إلى موضوع معين
  static Future<void> _sendToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: json.encode({
          'to': '/topics/$topic',
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data': data ?? {},
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('تم إرسال الإشعار بنجاح إلى الموضوع: $topic');
      } else {
        print('فشل في إرسال الإشعار: ${response.body}');
      }
    } catch (e) {
      print('خطأ في إرسال الإشعار إلى الموضوع: $e');
    }
  }

  // إرسال إلى رمز مميز محدد
  static Future<void> _sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: json.encode({
          'to': token,
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data': data ?? {},
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        print('تم إرسال الإشعار بنجاح إلى الرمز المميز');
      } else {
        print('فشل في إرسال الإشعار: ${response.body}');
      }
    } catch (e) {
      print('خطأ في إرسال الإشعار إلى الرمز المميز: $e');
    }
  }

  // حفظ تاريخ الإشعارات
  static Future<void> _saveNotificationHistory({
    required String title,
    required String body,
    required String target,
    Map<String, String>? data,
  }) async {
    try {
      await _firestore.collection('notification_history').add({
        'title': title,
        'body': body,
        'target': target,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'sent_by': 'system', // يمكن تغييره لمعرف المستخدم
      });
    } catch (e) {
      print('خطأ في حفظ تاريخ الإشعار: $e');
    }
  }

  // الحصول على جميع الرموز المميزة النشطة
  static Future<List<String>> getActiveTokens() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('user_tokens')
              .where('active', isEqualTo: true)
              .get();

      return snapshot.docs.map((doc) => doc['token'] as String).toList();
    } catch (e) {
      print('خطأ في الحصول على الرموز المميزة: $e');
      return [];
    }
  }

  // الاشتراك في موضوع جديد
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('تم الاشتراك في الموضوع: $topic');

      // تحديث قاعدة البيانات
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('user_tokens').doc(token).update({
          'topics': FieldValue.arrayUnion([topic]),
        });
      }
    } catch (e) {
      print('خطأ في الاشتراك: $e');
    }
  }

  // إلغاء الاشتراك من موضوع
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('تم إلغاء الاشتراك من الموضوع: $topic');

      // تحديث قاعدة البيانات
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('user_tokens').doc(token).update({
          'topics': FieldValue.arrayRemove([topic]),
        });
      }
    } catch (e) {
      print('خطأ في إلغاء الاشتراك: $e');
    }
  }

  // الحصول على FCM Token الحالي
  static Future<String?> getCurrentToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('خطأ في الحصول على FCM Token: $e');
      return null;
    }
  }
}

// دالة للتعامل مع الرسائل في الخلفية (يجب أن تكون خارج الكلاس)
@pragma('vm:entry-point')
Future<void> freeFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  print('تم استقبال رسالة في الخلفية: ${message.notification?.title}');
}
