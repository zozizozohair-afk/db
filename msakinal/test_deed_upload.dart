import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/brozinshin/admin/deed_upload_utils.dart';

class TestDeedUploadPage extends StatefulWidget {
  const TestDeedUploadPage({Key? key}) : super(key: key);

  @override
  _TestDeedUploadPageState createState() => _TestDeedUploadPageState();
}

class _TestDeedUploadPageState extends State<TestDeedUploadPage> {
  Map<String, bool> testResults = {};
  String currentTest = '';
  bool isRunning = false;
  int passedTests = 0;
  int failedTests = 0;
  int totalTests = 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('اختبار نظام رفع الصكوك - Supabase'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // إحصائيات الاختبارات
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'إحصائيات الاختبارات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$totalTests',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('إجمالي الاختبارات'),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '$passedTests',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text('نجح'),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '$failedTests',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text('فشل'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // الاختبار الحالي
            if (currentTest.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (isRunning) CircularProgressIndicator(),
                      SizedBox(width: 10),
                      Text('الاختبار الحالي: $currentTest'),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 20),

            // أزرار التحكم
            Row(
              children: [
                ElevatedButton(
                  onPressed: isRunning ? null : _runAllTests,
                  child: Text('تشغيل جميع الاختبارات'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _clearResults,
                  child: Text('مسح النتائج'),
                ),
              ],
            ),
            SizedBox(height: 20),

            // نتائج الاختبارات
            Expanded(
              child: ListView(
                children:
                    testResults.entries.map((entry) {
                      return ListTile(
                        leading: Icon(
                          entry.value ? Icons.check_circle : Icons.error,
                          color: entry.value ? Colors.green : Colors.red,
                        ),
                        title: Text(entry.key),
                        subtitle: Text(entry.value ? 'نجح' : 'فشل'),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      isRunning = true;
      testResults.clear();
      passedTests = 0;
      failedTests = 0;
    });

    await _testSupabaseConnection();
    await _testUserPermissions();
    await _testFileValidation();
    await _testStorageOperations();
    await _testDatabaseOperations();
    await _testUtilityFunctions();

    setState(() {
      isRunning = false;
      currentTest = 'اكتملت جميع الاختبارات';
    });
  }

  void _clearResults() {
    setState(() {
      testResults.clear();
      passedTests = 0;
      failedTests = 0;
      currentTest = '';
    });
  }

  void _updateTestResult(String testName, bool passed) {
    setState(() {
      testResults[testName] = passed;
      if (passed) {
        passedTests++;
      } else {
        failedTests++;
      }
    });
  }

  Future<void> _testSupabaseConnection() async {
    setState(() {
      currentTest = 'اختبار الاتصال بـ Supabase';
    });

    try {
      final supabase = Supabase.instance.client;

      // اختبار وجود bucket
      final buckets = await supabase.storage.listBuckets();
      final hasDeedsBucket = buckets.any((bucket) => bucket.name == 'deeds');

      _updateTestResult('الاتصال بـ Supabase', true);
      _updateTestResult('وجود bucket الصكوك', hasDeedsBucket);
    } catch (e) {
      _updateTestResult('الاتصال بـ Supabase', false);
      _updateTestResult('وجود bucket الصكوك', false);
    }
  }

  Future<void> _testUserPermissions() async {
    setState(() {
      currentTest = 'اختبار صلاحيات المستخدم';
    });

    try {
      final hasPermission = await DeedUploadUtils.checkUserPermissions();
      _updateTestResult('صلاحيات المستخدم', hasPermission);
    } catch (e) {
      _updateTestResult('صلاحيات المستخدم', false);
    }
  }

  Future<void> _testFileValidation() async {
    setState(() {
      currentTest = 'اختبار التحقق من الملفات';
    });

    try {
      // اختبار ملف صحيح
      final validationResult1 = DeedUploadUtils.validateFile(
        fileName: 'test.pdf',
        fileSize: 1024 * 1024, // 1 MB
      );

      // اختبار ملف كبير
      final validationResult2 = DeedUploadUtils.validateFile(
        fileName: 'large.pdf',
        fileSize: 15 * 1024 * 1024, // 15 MB
      );

      // اختبار ملف بصيغة خاطئة
      final validationResult3 = DeedUploadUtils.validateFile(
        fileName: 'test.txt',
        fileSize: 1024,
      );

      _updateTestResult('التحقق من ملف صحيح', validationResult1 == null);
      _updateTestResult('رفض ملف كبير', validationResult2 != null);
      _updateTestResult('رفض صيغة خاطئة', validationResult3 != null);
    } catch (e) {
      _updateTestResult('التحقق من الملفات', false);
    }
  }

  Future<void> _testStorageOperations() async {
    setState(() {
      currentTest = 'اختبار عمليات التخزين';
    });

    try {
      // اختبار إنشاء مسار تخزين
      final storagePath = DeedUploadUtils.createStoragePath(
        apartmentNumber: 'test_apartment',
        fileName: 'test.pdf',
      );

      _updateTestResult('إنشاء مسار التخزين', storagePath.isNotEmpty);
    } catch (e) {
      _updateTestResult('عمليات التخزين', false);
    }
  }

  Future<void> _testDatabaseOperations() async {
    setState(() {
      currentTest = 'اختبار عمليات قاعدة البيانات';
    });

    try {
      // اختبار الاتصال بـ Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('test').limit(1).get();

      _updateTestResult('الاتصال بـ Firestore', true);
    } catch (e) {
      _updateTestResult('الاتصال بـ Firestore', false);
    }
  }

  Future<void> _testUtilityFunctions() async {
    setState(() {
      currentTest = 'اختبار الدوال المساعدة';
    });

    try {
      // اختبار إنشاء metadata
      final metadata = DeedUploadUtils.createFileMetadata(
        apartmentNumber: 'test_apartment',
        fileName: 'test.pdf',
        fileSize: 1024 * 1024,
      );

      // اختبار إحصائيات الرفع
      final stats = DeedUploadUtils.getUploadStats(
        startTime: DateTime.now().subtract(Duration(seconds: 5)),
        endTime: DateTime.now(),
        fileSize: 1024 * 1024,
      );

      _updateTestResult('إنشاء metadata', metadata.isNotEmpty);
      _updateTestResult('حساب إحصائيات الرفع', stats.isNotEmpty);
    } catch (e) {
      _updateTestResult('الدوال المساعدة', false);
    }
  }
}
