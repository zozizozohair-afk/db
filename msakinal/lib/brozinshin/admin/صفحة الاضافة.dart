import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';

class UpdateDeedPage extends StatefulWidget {
  const UpdateDeedPage({super.key});

  @override
  _UpdateDeedPageState createState() => _UpdateDeedPageState();
}

class _UpdateDeedPageState extends State<UpdateDeedPage> {
  final TextEditingController projectNumberController = TextEditingController();
  Map<String, Map<String, dynamic>> apartmentsData = {};
  bool loading = false;
  Map<String, bool> uploadingStates = {};

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم يتم العثور على شقق بهذا الرقم')),
        );
      }

      Map<String, Map<String, dynamic>> tempData = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final numberValue = data['number'];

        tempData[doc.id] = {
          'number': numberValue ?? '',
          'numberInt': int.tryParse(numberValue.toString()) ?? 0, // للتصنيف
          'direction': data['direction'] ?? '',
          'deedNumber': TextEditingController(
            text: data['deedNumber']?.toString() ?? '',
          ),
          'deedDate': TextEditingController(
            text: data['deedDate']?.toString() ?? '',
          ),
          'code': TextEditingController(text: data['code']?.toString() ?? ''),
        };
      }

      // ترتيب حسب رقم الشقة الصحيح (كـ رقم)
      final sortedEntries =
          tempData.entries.toList()..sort(
            (a, b) => a.value['numberInt'].compareTo(b.value['numberInt']),
          );

      setState(() {
        apartmentsData = Map.fromEntries(sortedEntries);
      });
    } catch (e) {
      print('خطأ أثناء جلب البيانات: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء جلب البيانات')));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _saveChanges(String docId) async {
    final data = apartmentsData[docId];
    if (data == null) return;

    await FirebaseFirestore.instance
        .collection('apartments')
        .doc(docId)
        .update({
          'deedNumber': data['deedNumber'].text,
          'deedDate': data['deedDate'].text,
          'code': data['code'].text,
        });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ التعديلات للشقة رقم ${data['number']}')),
    );
  }

  Future<void> _uploadDeedPDF(String docId) async {
    try {
      setState(() {
        uploadingStates[docId] = true;
      });

      print('بدء عملية اختيار الملف...');

      // اختيار ملف PDF
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        print('تم اختيار الملف: ${result.files.single.name}');

        final fileName = result.files.single.name;
        final apartmentData = apartmentsData[docId]!;
        final apartmentNumber = apartmentData['number'];

        print('بدء رفع الملف للشقة رقم: $apartmentNumber');

        // التحقق من حجم الملف (أقل من 10 ميجابايت)
        final fileSize =
            kIsWeb
                ? result.files.single.bytes?.length ?? 0
                : result.files.single.size;
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception(
            'حجم الملف كبير جداً. يجب أن يكون أقل من 10 ميجابايت',
          );
        }

        // إنشاء مرجع للملف في Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('deeds')
            .child(
              'apartment_${apartmentNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf',
            );

        print('تم إنشاء مرجع التخزين');

        // رفع الملف - التعامل مع الويب والموبايل
        UploadTask uploadTask;
        if (kIsWeb) {
          print('رفع الملف للويب...');
          // للويب - استخدام bytes
          final bytes = result.files.single.bytes;
          if (bytes != null && bytes.isNotEmpty) {
            print('حجم الملف: ${bytes.length} بايت');
            uploadTask = storageRef.putData(
              bytes,
              SettableMetadata(
                contentType: 'application/pdf',
                customMetadata: {
                  'apartmentNumber': apartmentNumber.toString(),
                  'uploadedBy': 'admin',
                  'originalName': fileName,
                },
              ),
            );
          } else {
            throw Exception('لا يمكن قراءة الملف - البيانات فارغة');
          }
        } else {
          print('رفع الملف للموبايل...');
          // للموبايل - استخدام File
          if (result.files.single.path != null) {
            final file = File(result.files.single.path!);
            print('مسار الملف: ${file.path}');
            uploadTask = storageRef.putFile(
              file,
              SettableMetadata(
                contentType: 'application/pdf',
                customMetadata: {
                  'apartmentNumber': apartmentNumber.toString(),
                  'uploadedBy': 'admin',
                  'originalName': fileName,
                },
              ),
            );
          } else {
            throw Exception('لا يمكن الوصول للملف - المسار فارغ');
          }
        }

        print('بدء رفع الملف إلى Firebase Storage...');

        // مراقبة تقدم الرفع مع timeout
        late StreamSubscription progressSubscription;
        bool uploadCompleted = false;

        progressSubscription = uploadTask.snapshotEvents.listen((
          TaskSnapshot snapshot,
        ) {
          if (snapshot.state == TaskState.running) {
            double progress = snapshot.bytesTransferred / snapshot.totalBytes;
            print('تقدم الرفع: ${(progress * 100).toStringAsFixed(1)}%');
          } else if (snapshot.state == TaskState.success) {
            uploadCompleted = true;
            print('تم اكتمال الرفع بنجاح');
          } else if (snapshot.state == TaskState.error) {
            print('خطأ في الرفع: ${snapshot.metadata}');
          }
        });

        // انتظار اكتمال الرفع مع timeout
        final snapshot = await uploadTask.timeout(
          Duration(minutes: 5),
          onTimeout: () {
            progressSubscription.cancel();
            uploadTask.cancel();
            throw Exception('انتهت مهلة رفع الملف. يرجى المحاولة مرة أخرى');
          },
        );

        progressSubscription.cancel();
        print('تم رفع الملف بنجاح، الحصول على رابط التحميل...');

        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('رابط التحميل: $downloadUrl');

        // إنشاء رقم PN فريد
        final pnNumber = 'PN${DateTime.now().millisecondsSinceEpoch}';
        print('رقم PN المُنشأ: $pnNumber');

        // حفظ معلومات الملف في قاعدة البيانات
        print('حفظ البيانات في Firestore...');
        await FirebaseFirestore.instance
            .collection('apartments')
            .doc(docId)
            .update({
              'deedPdfUrl': downloadUrl,
              'deedPdfName': fileName,
              'pn': pnNumber,
              'deedUploadDate': FieldValue.serverTimestamp(),
              'fileSize': fileSize,
            })
            .timeout(
              Duration(seconds: 30),
              onTimeout: () {
                throw Exception('انتهت مهلة حفظ البيانات في قاعدة البيانات');
              },
            );

        print('تم حفظ البيانات بنجاح');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم رفع الصك بنجاح للشقة رقم $apartmentNumber\nرقم PN: $pnNumber',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        print('لم يتم اختيار أي ملف');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم اختيار أي ملف'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('خطأ تفصيلي في رفع الملف: $e');
      print('نوع الخطأ: ${e.runtimeType}');

      String errorMessage = 'حدث خطأ أثناء رفع الملف';

      if (e.toString().contains('permission') ||
          e.toString().contains('Permission')) {
        errorMessage =
            'خطأ في الصلاحيات - تأكد من إعدادات Firebase Storage Rules';
      } else if (e.toString().contains('network') ||
          e.toString().contains('Network')) {
        errorMessage = 'خطأ في الشبكة - تأكد من الاتصال بالإنترنت';
      } else if (e.toString().contains('storage') ||
          e.toString().contains('Storage')) {
        errorMessage = 'خطأ في التخزين - تأكد من إعدادات Firebase Storage';
      } else if (e.toString().contains('firestore') ||
          e.toString().contains('Firestore')) {
        errorMessage = 'خطأ في قاعدة البيانات - تأكد من إعدادات Firestore';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('انتهت مهلة')) {
        errorMessage = 'انتهت مهلة العملية - يرجى المحاولة مرة أخرى';
      } else if (e.toString().contains('حجم الملف')) {
        errorMessage = e.toString();
      } else if (e.toString().contains('cancelled') ||
          e.toString().contains('canceled')) {
        errorMessage = 'تم إلغاء عملية الرفع';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage\n\nتفاصيل الخطأ: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 8),
          ),
        );
      }
    } finally {
      setState(() {
        uploadingStates[docId] = false;
      });
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
              ),
              onSubmitted: (_) {
                Navigator.of(context).pop();
                _fetchApartments();
              },
            ),
            actions: [
              TextButton(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تحديث بيانات الصكوك")),
      body: Column(
        children: [
          const SizedBox(height: 50),
          Center(
            child: ElevatedButton(
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
              child: const Text('تحديث الصكوك', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 20),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (!loading && apartmentsData.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apartmentsData.length,
                itemBuilder: (context, index) {
                  final docId = apartmentsData.keys.elementAt(index);
                  final data = apartmentsData[docId]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "شقة رقم: ${data['number']}",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text("الاتجاه: ${data['direction']}"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: data['deedNumber'],
                                  decoration: InputDecoration(
                                    labelText: "رقم الصك",
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: data['deedDate'],
                                  decoration: InputDecoration(
                                    labelText: "تاريخ الصك",
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: data['code'],
                                  decoration: InputDecoration(
                                    labelText: "الترقيم",
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    uploadingStates[docId] == true
                                        ? null
                                        : () => _uploadDeedPDF(docId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[800],
                                  foregroundColor: Colors.white,
                                ),
                                icon:
                                    uploadingStates[docId] == true
                                        ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : Icon(Icons.upload_file),
                                label: Text(
                                  uploadingStates[docId] == true
                                      ? 'جاري الرفع...'
                                      : 'رفع الصك',
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _saveChanges(docId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[800],
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('حفظ التعديلات'),
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
        ],
      ),
    );
  }
}
