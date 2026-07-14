import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/free_notification_service.dart';

class FreeNotificationsAdminPage extends StatefulWidget {
  const FreeNotificationsAdminPage({Key? key}) : super(key: key);

  @override
  State<FreeNotificationsAdminPage> createState() => _FreeNotificationsAdminPageState();
}

class _FreeNotificationsAdminPageState extends State<FreeNotificationsAdminPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _userTokenController = TextEditingController();
  final _topicController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedTarget = 'all'; // all, user, topic
  
  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _userTokenController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الإشعارات المجانية'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSendNotificationCard(),
            const SizedBox(height: 20),
            _buildActiveTokensCard(),
            const SizedBox(height: 20),
            _buildNotificationHistoryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendNotificationCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إرسال إشعار جديد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // اختيار الهدف
            const Text('الهدف:', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('جميع المستخدمين'),
                    value: 'all',
                    groupValue: _selectedTarget,
                    onChanged: (value) {
                      setState(() {
                        _selectedTarget = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('مستخدم محدد'),
                    value: 'user',
                    groupValue: _selectedTarget,
                    onChanged: (value) {
                      setState(() {
                        _selectedTarget = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('موضوع محدد'),
                    value: 'topic',
                    groupValue: _selectedTarget,
                    onChanged: (value) {
                      setState(() {
                        _selectedTarget = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // حقل الرمز المميز أو الموضوع
            if (_selectedTarget == 'user')
              TextField(
                controller: _userTokenController,
                decoration: const InputDecoration(
                  labelText: 'رمز المستخدم المميز (FCM Token)',
                  border: OutlineInputBorder(),
                  hintText: 'أدخل FCM Token للمستخدم',
                ),
                maxLines: 2,
              ),
            
            if (_selectedTarget == 'topic')
              TextField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: 'اسم الموضوع',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: vip_users, news_updates',
                ),
              ),
            
            if (_selectedTarget != 'all') const SizedBox(height: 16),
            
            // عنوان الإشعار
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان الإشعار',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // محتوى الإشعار
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'محتوى الإشعار',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            
            // زر الإرسال
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال الإشعار', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTokensCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرموز المميزة النشطة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_tokens')
                  .where('active', isEqualTo: true)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('خطأ: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tokens = snapshot.data?.docs ?? [];

                if (tokens.isEmpty) {
                  return const Text('لا توجد رموز مميزة نشطة');
                }

                return Column(
                  children: [
                    Text(
                      'إجمالي المستخدمين النشطين: ${tokens.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: tokens.length,
                        itemBuilder: (context, index) {
                          final tokenData = tokens[index].data() as Map<String, dynamic>;
                          final token = tokenData['token'] as String;
                          final platform = tokenData['platform'] as String? ?? 'unknown';
                          final timestamp = tokenData['timestamp'] as Timestamp?;
                          final topics = tokenData['topics'] as List<dynamic>? ?? [];

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                platform == 'web' ? Icons.web : Icons.phone_android,
                                color: platform == 'web' ? Colors.blue : Colors.green,
                              ),
                              title: Text(
                                '${token.substring(0, 20)}...',
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('المنصة: $platform'),
                                  if (timestamp != null)
                                    Text('التاريخ: ${timestamp.toDate().toString().substring(0, 16)}'),
                                  if (topics.isNotEmpty)
                                    Text('المواضيع: ${topics.join(', ')}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () {
                                  _userTokenController.text = token;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ الرمز المميز')),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationHistoryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تاريخ الإشعارات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notification_history')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('خطأ: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data?.docs ?? [];

                if (notifications.isEmpty) {
                  return const Text('لا يوجد تاريخ للإشعارات');
                }

                return SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notificationData = notifications[index].data() as Map<String, dynamic>;
                      final title = notificationData['title'] as String;
                      final body = notificationData['body'] as String;
                      final target = notificationData['target'] as String;
                      final timestamp = notificationData['timestamp'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.notifications, color: Colors.orange),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(body),
                              Text(
                                'الهدف: ${target == "all_users" ? "جميع المستخدمين" : target}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (timestamp != null)
                                Text(
                                  timestamp.toDate().toString().substring(0, 16),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    if (_selectedTarget == 'user' && _userTokenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رمز المستخدم المميز')),
      );
      return;
    }

    if (_selectedTarget == 'topic' && _topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم الموضوع')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();

      if (_selectedTarget == 'all') {
        await FreeNotificationService.sendNotificationToAll(
          title: title,
          body: body,
        );
      } else if (_selectedTarget == 'user') {
        await FreeNotificationService.sendNotificationToUser(
          userToken: _userTokenController.text.trim(),
          title: title,
          body: body,
        );
      } else if (_selectedTarget == 'topic') {
        // إرسال إلى موضوع محدد
        await FreeNotificationService.sendNotificationToTopic(
          topic: _topicController.text.trim(),
          title: title,
          body: body,
        );
      }

      // مسح الحقول
      _titleController.clear();
      _bodyController.clear();
      _userTokenController.clear();
      _topicController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الإشعار بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إرسال الإشعار: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}