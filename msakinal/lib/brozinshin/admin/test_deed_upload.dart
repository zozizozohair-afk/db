import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'deed_upload_utils.dart';

/// صفحة اختبار نظام رفع الصكوك
class TestDeedUploadPage extends StatefulWidget {
  const TestDeedUploadPage({super.key});

  @override
  _TestDeedUploadPageState createState() => _TestDeedUploadPageState();
}

class _TestDeedUploadPageState extends State<TestDeedUploadPage> {
  final List<Map<String, dynamic>> _testResults = [];
  bool _isRunningTests = false;
  int _currentTestIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// إضافة نتيجة اختبار
  void _addTestResult({
    required String testName,
    required bool passed,
    String? message,
    Duration? duration,
    Map<String, dynamic>? details,
  }) {
    setState(() {
      _testResults.add({
        'testName': testName,
        'passed': passed,
        'message': message,
        'duration': duration,
        'details': details,
        'timestamp': DateTime.now(),
      });
    });

    // التمرير إلى أسفل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// تشغيل جميع الاختبارات
  Future<void> _runAllTests() async {
    setState(() {
      _isRunningTests = true;
      _currentTestIndex = 0;
      _testResults.clear();
    });

    try {
      await _testUserPermissions();
      await _testConnectivity();
      await _testFileValidation();
      await _testStorageReference();
      await _testMetadataCreation();
      await _testErrorMessages();
      await _testUploadStats();
      await _testDatabaseOperations();

      _addTestResult(
        testName: 'جميع الاختبارات',
        passed: true,
        message: 'تم إكمال جميع الاختبارات بنجاح',
      );
    } catch (e) {
      _addTestResult(
        testName: 'خطأ عام',
        passed: false,
        message: 'حدث خطأ أثناء تشغيل الاختبارات: $e',
      );
    } finally {
      setState(() {
        _isRunningTests = false;
      });
    }
  }

  /// اختبار صلاحيات المستخدم
  Future<void> _testUserPermissions() async {
    setState(() => _currentTestIndex = 1);
    final stopwatch = Stopwatch()..start();

    try {
      final hasPermissions = await DeedUploadUtils.checkUserPermissions();
      final user = Supabase.instance.client.auth.currentUser;

      _addTestResult(
        testName: 'فحص صلاحيات المستخدم',
        passed: hasPermissions,
        message:
            hasPermissions
                ? 'المستخدم مسجل الدخول: ${user?.email ?? "غير محدد"}'
                : 'المستخدم غير مسجل الدخول',
        duration: stopwatch.elapsed,
        details: {
          'userId': user?.id,
          'email': user?.email,
          'isAnonymous': user?.isAnonymous ?? false,
        },
      );
    } catch (e) {
      _addTestResult(
        testName: 'فحص صلاحيات المستخدم',
        passed: false,
        message: 'خطأ في فحص الصلاحيات: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// اختبار الاتصال
  Future<void> _testConnectivity() async {
    setState(() => _currentTestIndex = 2);
    final stopwatch = Stopwatch()..start();

    try {
      final isConnected = await DeedUploadUtils.checkConnectivity();

      _addTestResult(
        testName: 'فحص الاتصال بقاعدة البيانات',
        passed: isConnected,
        message: isConnected ? 'الاتصال متاح' : 'لا يوجد اتصال بقاعدة البيانات',
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      _addTestResult(
        testName: 'فحص الاتصال بقاعدة البيانات',
        passed: false,
        message: 'خطأ في فحص الاتصال: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// اختبار التحقق من صحة الملفات
  Future<void> _testFileValidation() async {
    setState(() => _currentTestIndex = 3);
    final stopwatch = Stopwatch()..start();

    try {
      final testCases = [
        {
          'name': 'ملف PDF صحيح',
          'fileName': 'test.pdf',
          'fileSize': 1024 * 1024, // 1MB
          'shouldPass': true,
        },
        {
          'name': 'ملف كبير جداً',
          'fileName': 'large.pdf',
          'fileSize': 30 * 1024 * 1024, // 30MB
          'shouldPass': false,
        },
        {
          'name': 'ملف فارغ',
          'fileName': 'empty.pdf',
          'fileSize': 0,
          'shouldPass': false,
        },
        {
          'name': 'ملف غير PDF',
          'fileName': 'document.docx',
          'fileSize': 1024,
          'shouldPass': false,
        },
      ];

      int passedTests = 0;
      for (final testCase in testCases) {
        final error = DeedUploadUtils.validateFile(
          fileName: testCase['fileName'] as String,
          fileSize: testCase['fileSize'] as int,
          bytes:
              testCase['fileSize'] as int <= 0
                  ? null
                  : Uint8List.fromList(List<int>.filled(3, 0)),
        );

        final shouldPass = testCase['shouldPass'] as bool;
        final actuallyPassed = (error == null) == shouldPass;

        if (actuallyPassed) passedTests++;
      }

      _addTestResult(
        testName: 'التحقق من صحة الملفات',
        passed: passedTests == testCases.length,
        message: 'نجح $passedTests من ${testCases.length} اختبارات',
        duration: stopwatch.elapsed,
        details: {
          'totalTests': testCases.length,
          'passedTests': passedTests,
          'testCases': testCases,
        },
      );
    } catch (e) {
      _addTestResult(
        testName: 'التحقق من صحة الملفات',
        passed: false,
        message: 'خطأ في اختبار التحقق: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// اختبار إنشاء مرجع التخزين
  Future<void> _testStorageReference() async {
    setState(() => _currentTestIndex = 4);
    final stopwatch = Stopwatch()..start();

    try {
      final ref = DeedUploadUtils.getStorageReference(
        apartmentNumber: '123',
        fileName: 'test_deed.pdf',
      );

      final path = ref.fullPath;
      final isValidPath =
          path.startsWith('deeds/apartment_123_') &&
          path.endsWith('_test_deed.pdf');

      _addTestResult(
        testName: 'إنشاء مرجع التخزين',
        passed: isValidPath,
        message: isValidPath ? 'تم إنشاء مرجع صحيح' : 'مرجع التخزين غير صحيح',
        duration: stopwatch.elapsed,
        details: {'path': path, 'path': path},
      );
    } catch (e) {
      _addTestResult(
        testName: 'إنشاء مرجع التخزين',
        passed: false,
        message: 'خطأ في إنشاء مرجع التخزين: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// اختبار إنشاء metadata
  Future<void> _testMetadataCreation() async {
    setState(() => _currentTestIndex = 5);
    final stopwatch = Stopwatch()..start();

    try {
      final metadata = DeedUploadUtils.createFileMetadata(
        apartmentNumber: '456',
        fileName: 'deed_test.pdf',
        fileSize: 2048,
      );

      final hasRequiredFields =
          metadata['contentType'] == 'application/pdf' &&
          metadata['apartmentNumber'] == '456' &&
          metadata['originalName'] == 'deed_test.pdf' &&
          metadata['fileSize'] == '2048';

      _addTestResult(
        testName: 'إنشاء metadata للملف',
        passed: hasRequiredFields,
        message:
            hasRequiredFields ? 'تم إنشاء metadata صحيح' : 'metadata غير مكتمل',
        duration: stopwatch.elapsed,
        details: {
          'contentType': metadata['contentType'],
          'customMetadata': metadata['customMetadata'],
        },
      );
    } catch (e) {
      _addTestResult(
        testName: 'إنشاء metadata للملف',
        passed: false,
        message: 'خطأ في إنشاء metadata: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// اختبار رسائل الخطأ
  Future<void> _testErrorMessages() async {
    setState(() => _currentTestIndex = 6);
    final stopwatch = Stopwatch()..start();

    try {
      final errorTests = [
        {'error': 'permission denied', 'expectedKeyword': 'صلاحيات'},
        {'error': 'network error', 'expectedKeyword': 'شبكة'},
        {'error': 'storage quota exceeded', 'expectedKeyword': 'تخزين'},
        {'error': 'firestore error', 'expectedKeyword': 'قاعدة البيانات'},
        {'error': 'timeout', 'expectedKeyword': 'مهلة'},
        {'error': 'cancelled', 'expectedKeyword': 'إلغاء'},
      ];

      int correctMessages = 0;
      for (final test in errorTests) {
        final message = DeedUploadUtils.getDetailedErrorMessage(test['error']);
        if (message.contains(test['expectedKeyword'] as String)) {
          correctMessages++;
        }
      }

      _addTestResult(
        testName: 'رسائل الخطأ المفصلة',
        passed: correctMessages == errorTests.length,
        message: 'رسائل صحيحة: $correctMessages من ${errorTests.length}',
        duration: stopwatch.elapsed,
        details: {
          'totalTests': errorTests.length,
          'correctMessages': correctMessages,
        },
      );
    } catch (e) {
      _addTestResult(
        testName: 'رسائل الخطأ المفصلة',
        passed: false,
        message: 'خطأ في اختبار رسائل الخطأ: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// اختبار إحصائيات الرفع
  Future<void> _testUploadStats() async {
    setState(() => _currentTestIndex = 7);
    final stopwatch = Stopwatch()..start();

    try {
      final startTime = DateTime.now().subtract(Duration(seconds: 10));
      final endTime = DateTime.now();
      final fileSize = 5 * 1024 * 1024; // 5MB

      final stats = DeedUploadUtils.getUploadStats(
        fileSize: fileSize,
        startTime: startTime,
        endTime: endTime,
      );

      final hasRequiredStats =
          stats.containsKey('fileSize') &&
          stats.containsKey('fileSizeMB') &&
          stats.containsKey('duration') &&
          stats.containsKey('speedMBPerSecond');

      _addTestResult(
        testName: 'إحصائيات الرفع',
        passed: hasRequiredStats,
        message:
            hasRequiredStats
                ? 'تم حساب الإحصائيات بنجاح'
                : 'إحصائيات غير مكتملة',
        duration: stopwatch.elapsed,
        details: stats,
      );
    } catch (e) {
      _addTestResult(
        testName: 'إحصائيات الرفع',
        passed: false,
        message: 'خطأ في حساب الإحصائيات: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// اختبار عمليات قاعدة البيانات
  Future<void> _testDatabaseOperations() async {
    setState(() => _currentTestIndex = 8);
    final stopwatch = Stopwatch()..start();

    try {
      // اختبار الاتصال بقاعدة البيانات
      final testQuery = await Supabase.instance.client
          .from('deed_files')
          .select('*')
          .limit(1)
          .timeout(Duration(seconds: 10));

      _addTestResult(
        testName: 'عمليات قاعدة البيانات',
        passed: true,
        message: 'تم الاتصال بقاعدة البيانات بنجاح',
        duration: stopwatch.elapsed,
        details: {
          'documentsFound': testQuery.length,
          'queryTime': stopwatch.elapsed.inMilliseconds,
        },
      );
    } catch (e) {
      _addTestResult(
        testName: 'عمليات قاعدة البيانات',
        passed: false,
        message: 'خطأ في الاتصال بقاعدة البيانات: $e',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// مسح النتائج
  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }

  /// بناء عنصر نتيجة الاختبار
  Widget _buildTestResult(Map<String, dynamic> result) {
    final passed = result['passed'] as bool;
    final testName = result['testName'] as String;
    final message = result['message'] as String?;
    final duration = result['duration'] as Duration?;
    final details = result['details'] as Map<String, dynamic>?;
    final timestamp = result['timestamp'] as DateTime;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        leading: Icon(
          passed ? Icons.check_circle : Icons.error,
          color: passed ? Colors.green : Colors.red,
        ),
        title: Text(
          testName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: passed ? Colors.green[800] : Colors.red[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) Text(message),
            if (duration != null)
              Text(
                'المدة: ${duration.inMilliseconds}ms',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            Text(
              'الوقت: ${timestamp.hour}:${timestamp.minute}:${timestamp.second}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        children: [
          if (details != null)
            Padding(
              padding: EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'التفاصيل:\n${_formatDetails(details)}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// تنسيق التفاصيل
  String _formatDetails(Map<String, dynamic> details) {
    return details.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final passedTests = _testResults.where((r) => r['passed'] == true).length;
    final totalTests = _testResults.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('اختبار نظام رفع الصكوك'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          if (!_isRunningTests)
            IconButton(
              onPressed: _clearResults,
              icon: Icon(Icons.clear_all),
              tooltip: 'مسح النتائج',
            ),
        ],
      ),
      body: Column(
        children: [
          // شريط التقدم والإحصائيات
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                if (_isRunningTests) ...[
                  Text('جاري تشغيل الاختبار $_currentTestIndex من 8'),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _currentTestIndex / 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ] else if (totalTests > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'المجموع',
                        totalTests.toString(),
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'نجح',
                        passedTests.toString(),
                        Colors.green,
                      ),
                      _buildStatCard(
                        'فشل',
                        (totalTests - passedTests).toString(),
                        Colors.red,
                      ),
                      _buildStatCard(
                        'النسبة',
                        totalTests > 0
                            ? '${((passedTests / totalTests) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        passedTests == totalTests
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // الأزرار
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunningTests ? null : _runAllTests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon:
                        _isRunningTests
                            ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Icon(Icons.play_arrow),
                    label: Text(
                      _isRunningTests
                          ? 'جاري التشغيل...'
                          : 'تشغيل جميع الاختبارات',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // النتائج
          Expanded(
            child:
                _testResults.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد نتائج اختبار',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'اضغط على "تشغيل جميع الاختبارات" للبدء',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: _testResults.length,
                      itemBuilder: (context, index) {
                        return _buildTestResult(_testResults[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة إحصائية
  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
