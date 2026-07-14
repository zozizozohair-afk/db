import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'deed_upload_utils.dart';

class UpdateDeedPageEnhanced extends StatefulWidget {
  const UpdateDeedPageEnhanced({super.key});

  @override
  _UpdateDeedPageEnhancedState createState() => _UpdateDeedPageEnhancedState();
}

class _UpdateDeedPageEnhancedState extends State<UpdateDeedPageEnhanced> {
  final TextEditingController projectNumberController = TextEditingController();
  Map<String, Map<String, dynamic>> apartmentsData = {};
  bool loading = false;
  Map<String, bool> uploadingStates = {};
  Map<String, double> uploadProgress = {};
  Map<String, StreamSubscription?> progressSubscriptions = {};
  Map<String, PlatformFile> selectedFiles = {};

  @override
  void dispose() {
    // إلغاء جميع الاشتراكات
    for (var subscription in progressSubscriptions.values) {
      subscription?.cancel();
    }
    super.dispose();
  }

  Future<void> _fetchApartments() async {
    final projectNumber = projectNumberController.text.trim();
    if (projectNumber.isEmpty) return;

    setState(() => loading = true);

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .get();

      if (snapshot.docs.isEmpty) {
        _showMessage('لم يتم العثور على شقق بهذا الرقم', isError: true);
        setState(() {
          apartmentsData = {};
        });
        return;
      }

      Map<String, Map<String, dynamic>> tempData = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final numberValue = data['number'];

        // تهيئة TextEditingController للحقول
        tempData[doc.id] = {
          'number': numberValue ?? '',
          'numberInt': int.tryParse(numberValue.toString()) ?? 0,
          'direction': data['direction'] ?? '',
          'deedNumber': TextEditingController(
            text: data['deedNumber']?.toString() ?? '',
          ),
          'deedDate': TextEditingController(
            text: data['deedDate']?.toString() ?? '',
          ),
          'code': TextEditingController(
            text: data['code']?.toString() ?? '',
          ),
          'hasExistingDeed': false,
          'existingDeedName': null,
        };

        // فحص وجود صك مرفوع مسبقاً في Supabase
        try {
          final existingDeeds = await Supabase.instance.client
              .from('deed_files')
              .select('file_name')
              .eq('apartment_id', numberValue.toString())
              .eq('project_number', projectNumber);

          if (existingDeeds.isNotEmpty) {
            tempData[doc.id]!['hasExistingDeed'] = true;
            tempData[doc.id]!['existingDeedName'] =
                existingDeeds.first['file_name'];
          }
        } catch (e) {
          print('خطأ في فحص الصكوك الموجودة: $e');
        }
      }

      // ترتيب حسب رقم الشقة
      final sortedEntries = tempData.entries.toList()
        ..sort(
          (a, b) => a.value['numberInt'].compareTo(b.value['numberInt']),
        );

      setState(() {
        apartmentsData = Map.fromEntries(sortedEntries);
      });
    } catch (e) {
      print('خطأ أثناء جلب البيانات: $e');
      _showMessage('حدث خطأ أثناء جلب البيانات', isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _saveChanges(String docId) async {
    final data = apartmentsData[docId];
    if (data == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('apartments')
          .doc(docId)
          .update({
            'deedNumber': data['deedNumber'].text,
            'deedDate': data['deedDate'].text,
            'code': data['code'].text,
          });

      _showMessage('تم حفظ التعديلات للشقة رقم ${data['number']}');
    } catch (e) {
      _showMessage('فشل في حفظ التعديلات: $e', isError: true);
    }
  }

  // اختيار ملف PDF للشقة
  Future<void> _selectFile(String docId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        // التحقق من حجم الملف (أقل من 10 ميجابايت)
        final fileSize = kIsWeb ? file.bytes?.length ?? 0 : file.size;
        if (fileSize > 10 * 1024 * 1024) {
          _showMessage(
            'حجم الملف كبير جداً. يجب أن يكون أقل من 10 ميجابايت',
            isError: true,
          );
          return;
        }

        setState(() {
          selectedFiles[docId] = file;
        });

        _showMessage('تم اختيار الملف: ${file.name}');
      }
    } catch (e) {
      _showMessage('خطأ في اختيار الملف: ${e.toString()}', isError: true);
    }
  }

  // رفع الملف مع إعادة المحاولة
  Future<void> _uploadDeedPDFWithRetry(String docId) async {
    // التحقق من وجود ملف محدد
    if (!selectedFiles.containsKey(docId)) {
      _showMessage('يرجى اختيار ملف PDF أولاً', isError: true);
      return;
    }

    try {
      final apartmentData = apartmentsData[docId]!;
      final apartmentNumber = apartmentData['number'];

      setState(() {
        uploadingStates[docId] = true;
        uploadProgress[docId] = 0.0;
      });

      // استخدام DeedUploadUtils للرفع مع إعادة المحاولة
      await DeedUploadUtils.uploadWithRetry(
        docId: docId,
        apartmentNumber: apartmentNumber,
        fileName: selectedFiles[docId]!.name,
        fileSize: selectedFiles[docId]!.size,
        projectNumber: projectNumberController.text.trim(),
        bytes: selectedFiles[docId]!.bytes,
        filePath: selectedFiles[docId]!.path,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              uploadProgress[docId] = progress;
            });
          }
        },
        onStatusUpdate: (status) {
          if (mounted) {
            _showMessage(status, isError: false);
          }
        },
      );

      // حفظ بيانات الصك في Firebase بعد رفع الملف بنجاح
      if (mounted) {
        _showMessage('جاري حفظ بيانات الصك في Firebase...', isError: false);
        
        final apartmentData = apartmentsData[docId]!;
        await FirebaseFirestore.instance
            .collection('apartments')
            .doc(docId)
            .update({
              'deedNumber': apartmentData['deedNumber'].text,
              'deedDate': apartmentData['deedDate'].text,
              'code': apartmentData['code'].text,
              'deedPdfUploaded': true,
              'deedUploadDate': FieldValue.serverTimestamp(),
            });
      }

      // تحديث البيانات المحلية
      if (mounted) {
        setState(() {
          apartmentsData[docId]!['hasExistingDeed'] = true;
        });
        _showMessage(
          'تم رفع الصك وحفظ البيانات بنجاح للشقة رقم $apartmentNumber',
          duration: Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          'فشل في رفع الصك: ${e.toString()}',
          isError: true,
          duration: Duration(seconds: 8),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingStates[docId] = false;
          uploadProgress[docId] = 0.0;
        });
      }
    }
  }

  // إلغاء عملية الرفع
  void _cancelUpload(String docId) {
    progressSubscriptions[docId]?.cancel();
    setState(() {
      uploadingStates[docId] = false;
      uploadProgress[docId] = 0.0;
    });
    _showMessage('تم إلغاء عملية الرفع');
  }

  // عرض الرسائل
  void _showMessage(
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: duration ?? Duration(seconds: 3),
          action: SnackBarAction(
            label: 'إغلاق',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void _showProjectSearchDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('ابحث عن مشروع'),
            content: TextField(
              controller: projectNumberController,
              decoration: InputDecoration(
                labelText: 'رقم المشروع',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) {
                Navigator.of(context).pop();
                _fetchApartments();
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _fetchApartments();
                },
                child: Text('بحث'),
              ),
            ],
          ),
    );
  }

  // بناء مؤشر التقدم
  Widget _buildProgressIndicator(String docId) {
    final progress = uploadProgress[docId] ?? 0.0;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تحديث بيانات الصكوك - محسن"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'نظام رفع الصكوك المحسن',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showProjectSearchDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: Icon(Icons.search),
                      label: const Text(
                        'البحث عن مشروع',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (loading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري تحميل البيانات...'),
                  ],
                ),
              ),
            ),
          if (!loading && apartmentsData.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apartmentsData.length,
                itemBuilder: (context, index) {
                  final docId = apartmentsData.keys.elementAt(index);
                  final data = apartmentsData[docId]!;
                  final isUploading = uploadingStates[docId] == true;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // معلومات الشقة
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "شقة رقم: ${data['number']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text("الاتجاه: ${data['direction']}"),
                              ),
                              if (data['hasExistingDeed'])
                                Chip(
                                  label: Text('يوجد صك'),
                                  backgroundColor: Colors.green[100],
                                  avatar: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),

                          if (data['hasExistingDeed'] &&
                              data['existingDeedName'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Text(
                                'الصك الحالي: ${data['existingDeedName']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // حقول الإدخال
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: data['deedNumber'],
                                  decoration: InputDecoration(
                                    labelText: "رقم الصك",
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.numbers),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: data['deedDate'],
                                  decoration: InputDecoration(
                                    labelText: "تاريخ الصك",
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.date_range),
                                    hintText: 'YYYY-MM-DD',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: data['code'],
                                  decoration: InputDecoration(
                                    labelText: "الترقيم",
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.code),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // مؤشر التقدم
                          if (isUploading) ...[
                            _buildProgressIndicator(docId),
                            const SizedBox(height: 16),
                          ],

                          // الأزرار
                          Column(
                            children: [
                              // زر اختيار الملف
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      isUploading
                                          ? null
                                          : () => _selectFile(docId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        selectedFiles.containsKey(docId)
                                            ? Colors.green[700]
                                            : Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: Icon(
                                    selectedFiles.containsKey(docId)
                                        ? Icons.check_circle
                                        : Icons.attach_file,
                                  ),
                                  label: Text(
                                    selectedFiles.containsKey(docId)
                                        ? 'تم اختيار: ${selectedFiles[docId]!.name}'
                                        : 'اختيار ملف PDF',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // زر رفع الصك
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          (isUploading ||
                                                  !selectedFiles.containsKey(
                                                    docId,
                                                  ))
                                              ? null
                                              : () => _uploadDeedPDFWithRetry(
                                                docId,
                                              ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[800],
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      icon:
                                          isUploading
                                              ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                              : Icon(Icons.upload_file),
                                      label: Text(
                                        isUploading
                                            ? 'جاري الرفع...'
                                            : 'رفع الصك',
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // زر الإلغاء (يظهر أثناء الرفع)
                                  if (isUploading)
                                    ElevatedButton.icon(
                                      onPressed: () => _cancelUpload(docId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[800],
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: Icon(Icons.cancel),
                                      label: Text('إلغاء'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // زر حفظ التعديلات
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _saveChanges(docId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[800],
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: Icon(Icons.save),
                                  label: const Text('حفظ التعديلات'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (!loading &&
              apartmentsData.isEmpty &&
              projectNumberController.text.isNotEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'لم يتم العثور على شقق',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'تأكد من رقم المشروع وحاول مرة أخرى',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
