import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:barcode/barcode.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../../class/edit_delete_helper.dart';
import '../../class/contract_delete_helper.dart';
import '../../class/logger.dart';
import '../../priovider/auth_provider.dart';

class ContractAssignmentsPage extends StatefulWidget {
  final String? highlightAssignmentId;
  final String? searchQuery;

  const ContractAssignmentsPage({
    Key? key,
    this.highlightAssignmentId,
    this.searchQuery,
  }) : super(key: key);

  @override
  State<ContractAssignmentsPage> createState() =>
      _ContractAssignmentsPageState();
}

class _ContractAssignmentsPageState extends State<ContractAssignmentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  List<QueryDocumentSnapshot>? _filteredDocs;

  @override
  void initState() {
    super.initState();
    // إذا كان هناك معرف تنازل محدد، نقوم بالبحث عنه تلقائياً
    if (widget.searchQuery != null) {
      _searchController.text = widget.searchQuery!;
      _performSearch();
    }
  }

  void _performSearch() {
    if (_searchController.text.isEmpty) {
      setState(() => _filteredDocs = null);
      return;
    }

    _firestore
        .collection('contract_assignments')
        .where('contractId', isEqualTo: _searchController.text + '-تنازل')
        .get()
        .then((snapshot) {
          setState(() {
            _filteredDocs = snapshot.docs;

            if (_filteredDocs!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا توجد نتائج للبحث')),
              );
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'التنازلات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.blue.shade800, Colors.blue.shade600],
            ),
          ),
        ),
        actions: [
          IconButton(icon: Icon(Icons.search), onPressed: _performSearch),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50.withOpacity(0.3), Colors.grey.shade50],
          ),
        ),
        child: Column(
          children: [
            // تاريخ التنازل في أعلى الصفحة
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'تاريخ التنازل: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // محتوى الصفحة الرئيسي
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    _filteredDocs != null
                        ? null
                        : _firestore
                            .collection('contract_assignments')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                builder: (context, snapshot) {
                  if (_filteredDocs != null) {
                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _filteredDocs!.length,
                      itemBuilder:
                          (context, index) =>
                              _buildAssignmentCard(_filteredDocs![index]),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ في جلب البيانات'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(child: Text('لا يوجد تنازلات'));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildAssignmentCard(docs[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _printAssignment(context),
        label: Text('طباعة تنازل جديد'),
        icon: Icon(Icons.print),
      ),
    );
  }

  Widget _buildAssignmentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isHighlighted = doc.id == widget.highlightAssignmentId;

    return Container(
      decoration: BoxDecoration(
        border:
            isHighlighted ? Border.all(color: Colors.orange, width: 2) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Card(
        margin: EdgeInsets.only(bottom: 16),
        elevation: 4,
        child: ListTile(
          title: Text(data['originalOwnerName'] ?? ''),
          subtitle: Text('تنازل لصالح: ${data['newOwnerName'] ?? ''}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editAssignment(doc.id, data),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteAssignment(doc.id, data),
              ),
              IconButton(
                icon: Icon(Icons.print),
                onPressed: () => _printAssignment(context, existingData: data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAssignment(String docId, Map<String, dynamic> data) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? '';
    final editDeleteHelper = EditDeleteHelper();
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

    final canEdit = await editDeleteHelper.canEditItem(userEmail);

    if (canEdit) {
      // تعديل مباشر للمستخدم المصرح له
      showDialog(
        context: context,
        builder: (context) {
          final newOwnerNameController = TextEditingController(
            text: data['newOwnerName'],
          );
          final newOwnerIDController = TextEditingController(
            text: data['newOwnerID'],
          );

          return AlertDialog(
            title: Text('تعديل التنازل'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newOwnerNameController,
                  decoration: InputDecoration(labelText: 'اسم المتنازل له'),
                ),
                TextFormField(
                  controller: newOwnerIDController,
                  decoration: InputDecoration(
                    labelText: 'رقم هوية المتنازل له',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newData = {
                    'newOwnerName': newOwnerNameController.text,
                    'newOwnerID': newOwnerIDController.text,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  await _firestore
                      .collection('contract_assignments')
                      .doc(docId)
                      .update(newData);

                  await logAction(
                    category: 'تنازلات',
                    action: 'تعديل',
                    itemId: docId,
                    userId: userEmail,
                    oldData: data,
                    newData: newData,
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث التنازل بنجاح')),
                  );
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      );
    } else {
      // إنشاء طلب تعديل للمستخدم غير المصرح له
      final shouldEdit = await editDeleteHelper.showEditConfirmationDialog(
        context,
        'التنازل',
      );
      if (shouldEdit) {
        await editDeleteHelper.createEditRequest(
          context: context,
          section: 'contract_assignments',
          itemId: docId,
          requesterName: authProvider.username ?? 'مستخدم',
          requesterEmail: userEmail,
          details: 'طلب تعديل تنازل',
          newData: data,
        );
      }
    }
  }

  Future<void> _deleteAssignment(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final userEmail = currentUser?.email ?? '';
      final editDeleteHelper = EditDeleteHelper();
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

      // التحقق من الصلاحيات
      if (!await editDeleteHelper.canEditItem(userEmail)) {
        // إنشاء طلب حذف للمستخدم غير المصرح له
        final shouldDelete = await editDeleteHelper
            .showDeleteConfirmationDialog(context, 'التنازل');

        if (shouldDelete) {
          await editDeleteHelper.createDeleteRequest(
            context: context,
            section: 'contract_assignments',
            itemId: docId,
            requesterName: authProvider.username ?? 'مستخدم',
            requesterEmail: userEmail,
            details: 'طلب حذف تنازل',
          );
        }
        return;
      }

      final shouldDelete =
          await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('تأكيد الحذف'),
                  content: Text(
                    'هل أنت متأكد من حذف هذا التنازل وإرجاع البيانات للمالك السابق؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('حذف', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
          ) ??
          false;

      if (shouldDelete) {
        // 1. تحديث العقد - إرجاع بيانات المالك السابق
        final contractRef =
            await _firestore
                .collection('contracts')
                .where(
                  'pn',
                  isEqualTo: data['contractId'].toString().replaceAll(
                    '-تنازل',
                    '',
                  ),
                )
                .limit(1)
                .get();

        if (contractRef.docs.isNotEmpty) {
          await contractRef.docs.first.reference.update({
            'clientName': data['originalOwnerName'],
            'clientData': {
              'identityNumber': data['originalOwnerID'],
              'phoneNumber': data['originalOwnerPhone'],
            },
            'status': 'تحت الإنشاء',
            'previousOwner': FieldValue.delete(),
            'assignedTo': FieldValue.delete(),
            'assignmentDate': FieldValue.delete(),
            'lastModified': FieldValue.serverTimestamp(),
            'modifiedBy': userEmail,
          });
        }

        // 2. تحديث الوحدة - إرجاع بيانات المالك السابق
        final apartmentRef =
            await _firestore
                .collection('apartments')
                .where(
                  'pn',
                  isEqualTo: data['contractId'].toString().replaceAll(
                    '-تنازل',
                    '',
                  ),
                )
                .limit(1)
                .get();

        if (apartmentRef.docs.isNotEmpty) {
          await apartmentRef.docs.first.reference.update({
            'clientName': data['originalOwnerName'],
            'clientIdentity': data['originalOwnerID'],
            'clientPhone': data['originalOwnerPhone'],
            'previousOwner': FieldValue.delete(),
            'lastModified': FieldValue.serverTimestamp(),
            'modifiedBy': userEmail,
          });
        }

        // 3. حذف وثيقة التنازل
        await _firestore.collection('contract_assignments').doc(docId).delete();

        // 4. تسجيل العملية
        await logAction(
          category: 'تنازلات',
          action: 'حذف وإرجاع البيانات',
          itemId: docId,
          userId: userEmail,
          oldData: data,
          newData: {},
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف التنازل وإرجاع البيانات للمالك السابق بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('خطأ في حذف التنازل: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحذف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printAssignment(
    BuildContext context, {
    Map<String, dynamic>? existingData,
  }) async {
    final pdf = pw.Document();

    try {
      final arabicFont = pw.Font.ttf(
        await rootBundle.load('assets/arm/Amiri-Regular.ttf'),
      );
      final imageData = await rootBundle.load('images/m.png');
      final imageDaa = await rootBundle.load('images/4.jpg');
      final image = pw.MemoryImage(imageData.buffer.asUint8List());
      final image1 = pw.MemoryImage(imageDaa.buffer.asUint8List());

      // استخدام تاريخ التنازل المحفوظ أو تاريخ اليوم للتنازلات الجديدة
      DateTime assignmentDate;
      try {
        if (existingData?['assignmentDate'] != null) {
          final dateValue = existingData!['assignmentDate'];
          if (dateValue is Timestamp) {
            assignmentDate = dateValue.toDate();
          } else if (dateValue is String) {
            assignmentDate = DateTime.parse(dateValue);
          } else {
            assignmentDate = DateTime.now();
          }
        } else {
          assignmentDate = DateTime.now();
        }
      } catch (e) {
        print('خطأ في تحويل تاريخ التنازل: $e');
        assignmentDate = DateTime.now();
      }
      final dateStr = DateFormat('dd - MM - yyyy').format(assignmentDate);

      // تعديل طريقة إنشاء الباركود - استخدام أرقام وحروف إنجليزية فقط
      final barcodeData =
          'MSK-${existingData?['contractId'] ?? ''}-${dateStr.replaceAll(' - ', '')}';

      // تنظيف البيانات من أي حروف غير مدعومة
      final cleanBarcodeData = barcodeData.replaceAll(
        RegExp(r'[^A-Za-z0-9\-]'),
        '',
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 1.0 * PdfPageFormat.cm,
            marginRight: 1.0 * PdfPageFormat.cm,
            marginTop: 1.0 * PdfPageFormat.cm,
            marginBottom: 1.0 * PdfPageFormat.cm,
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2, color: PdfColors.black),
                  image: pw.DecorationImage(
                    image: image1,
                    fit: pw.BoxFit.cover,
                  ),
                ),
                child: pw.Column(
                  children: [
                    // الهيدر
                    pw.Container(
                      margin: const pw.EdgeInsets.all(10),
                      width: double.infinity,
                      height: 100,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            width: 2,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Image(image, height: 100, fit: pw.BoxFit.contain),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              borderRadius: pw.BorderRadius.circular(5),
                            ),
                            child: pw.Text(
                              'تاريخ التنازل: $dateStr',
                              style: pw.TextStyle(
                                font: arabicFont,
                                color: PdfColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // المحتوى
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(20),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'بسم الله الرحمن الرحيم',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 16,
                                  ),
                                ),
                                pw.Text(
                                  'تاريخ التنازل: $dateStr',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ],
                            ),
                            pw.Center(
                              child: pw.Text(
                                'الحمد لله والصلاة والسلام على رسول الله',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              'السيد/ة ${existingData?['originalOwnerName'] ?? '_______'} هوية رقم ${existingData?['originalOwnerID'] ?? '_______'} جوال رقم ${existingData?['originalOwnerPhone'] ?? '_______'} المحترم/ة،',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text(
                              'السلام عليكم ورحمة الله وبركاته،',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text(
                              'نحيطكم علمًا أنكم قد قمتم بشراء شقة رقم ${existingData?['unitNumber'] ?? '_'} في الدور رقم ${existingData?['floor'] ?? '_'} بمشروع رقم (${existingData?['projectNumber'] ?? '_'}) بمدينة ${existingData?['city'] ?? '_____'}، في حي ${existingData?['district'] ?? '_____'}، وهي شقة ${existingData?['direction'] ?? '_____'}.',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontSize: 12,
                              ),
                            ),
                            pw.Text(
                              'وفقًا للعقد المبرم بينكم وبين شركة مساكن الرفاهية للمقاولات العامة والتطوير العقاري بتاريخ ${existingData?['contractDate'] ?? '[___/___/____]'}.',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              'هذا إقرار منك (مالك العقد) باني لا ارغب بافراغ الصك باسمي وانا بكامل قواي العقلية وارغب بنقل ملكية العقد الى ${existingData?['newOwnerName'] ?? '_______'} حامل/ة للهوية رقم ${existingData?['newOwnerID'] ?? '_______'} وافراغ الصك باسمه/باسمها وانني استلمت كامل مستحقاتي ولا أطالب الشركة بأي مبالغ مستقبلاً والله على ما أقول شهيد.',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              'نرجو منكم التوقيع على هذا الإخطار كتأكيد لموافقتكم على الإقرار الموجود اعلاه.\nشاكرين لكم تعاونكم، ونتطلع إلى إتمام هذه العملية بكل سهولة ويسر.',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Text(
                              'مع خالص التحية والتقدير،\nشركة مساكن الرفاهية',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontSize: 12,
                              ),
                            ),
                            pw.SizedBox(height: 40),
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      existingData?['originalOwnerName'] ??
                                          '_______',
                                      style: pw.TextStyle(
                                        font: arabicFont,
                                        fontSize: 12,
                                      ),
                                    ),
                                    pw.SizedBox(height: 20),
                                    pw.Text(
                                      'التوقيع: ________________',
                                      style: pw.TextStyle(
                                        font: arabicFont,
                                        fontSize: 12,
                                      ),
                                    ),
                                    pw.SizedBox(height: 20),
                                    pw.Text(
                                      'البصمة: ________________',
                                      style: pw.TextStyle(
                                        font: arabicFont,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      'الطرف الثاني: ${existingData?['newOwnerName'] ?? '_______'}',
                                      style: pw.TextStyle(
                                        font: arabicFont,
                                        fontSize: 12,
                                      ),
                                    ),
                                    pw.SizedBox(height: 20),
                                    pw.Text(
                                      'التوقيع: ________________',
                                      style: pw.TextStyle(
                                        font: arabicFont,
                                        fontSize: 12,
                                      ),
                                    ),
                                    pw.SizedBox(height: 20),
                                    pw.Text(
                                      'البصمة: ________________',
                                      style: pw.TextStyle(
                                        font: arabicFont,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // الفوتر مع الباركود
                    pw.Container(
                      margin: const pw.EdgeInsets.all(10),
                      height: 50,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: cleanBarcodeData,
                            width: 60,
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      print('Error printing: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الطباعة: $e')));
    }
  }
}
