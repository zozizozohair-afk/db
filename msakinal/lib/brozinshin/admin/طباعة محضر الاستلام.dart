import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../priovider/auth_provider.dart';
import '../../class/edit_delete_helper.dart';
import 'agency_form.dart' as forms;
import 'agency_manager.dart';

class Fprintastlam extends StatefulWidget {
  const Fprintastlam({super.key});

  @override
  _FprintastlamState createState() => _FprintastlamState();
}

class _FprintastlamState extends State<Fprintastlam> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'محضر استلام',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        elevation: 4,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade600],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () {
              // زر الطباعة (لاحقاً)
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                labelText: 'بحث برقم العقد أو اسم العميل',
                labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                prefixIcon: const Icon(Icons.search),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('astlam')
                        .orderBy('date', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('حدث خطأ...'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snapshot.data!.docs;

                  if (_searchQuery.isNotEmpty) {
                    docs =
                        docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final contractNumber =
                              data['newContractNumber']?.toString() ?? '';
                          final originalContractNumber =
                              data['originalContractNumber']?.toString() ?? '';
                          final name = data['nameNow']?.toString() ?? '';
                          final customerName =
                              data['customerName']?.toString() ?? '';
                          return contractNumber.contains(_searchQuery) ||
                              originalContractNumber.contains(_searchQuery) ||
                              name.contains(_searchQuery) ||
                              customerName.contains(_searchQuery);
                        }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text('لا توجد تسويات مالية'));
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 1;
                      if (constraints.maxWidth >= 1200) {
                        crossAxisCount = 3;
                      } else if (constraints.maxWidth >= 800) {
                        crossAxisCount = 2;
                      }
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          return _buildSettlementCard(data, docs[index].id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard(Map<String, dynamic> data, String docId) {
    return Card(
      elevation: 6,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('كود العقد الجديد:', data['newContractNumber']),
            _infoRow('رقم العقد الأصلي:', data['originalContractNumber']),
            _infoRow('اسم العميل :', data['customerName']),
            _infoRow('رقم الهوية :', data['clientIdentityNumber']),
            _infoRow('رقم العداد:', data['adad']),
            _infoRow('رقم الموقف:', data['maoakif']),
            _infoRow('تاريخ الاستلام:', data['date']),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.indigo),
                  onPressed: () => _editSettlement(docId, data),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteSettlement(docId),
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.teal),
                  onPressed: () async {
                    _showPrintingDialog();
                    await printContract(data['newContractNumber']);
                    Navigator.pop(context); // لإغلاق حوار الطباعة بعد الانتهاء
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.blue),
                  onPressed: () => _showAgencyDialog(context, data),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '$label ${value ?? 'غير محدد'}',
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // مؤشر جاري الطباعة
  void _showPrintingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const AlertDialog(
            title: Text('جاري الطباعة...'),
            content: SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
    );
  }

  void _deleteSettlement(String docId) async {
    // استخدام EditDeleteHelper بدلاً من الحذف المباشر
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final editDeleteHelper = EditDeleteHelper();
    final shouldDelete = await editDeleteHelper.showDeleteConfirmationDialog(
      context,
      'محضر الاستلام',
    );

    if (shouldDelete) {
      // الحصول على بريد المستخدم الحالي
      final currentUser = FirebaseAuth.instance.currentUser;
      final userEmail = currentUser?.email ?? '';

      await editDeleteHelper.createDeleteRequest(
        context: context,
        section: 'astlam',
        itemId: docId,
        requesterName: authProvider.username ?? 'مستخدم',
        requesterEmail: userEmail,
        details: 'طلب حذف محضر استلام',
      );
    }
  }

  void _editSettlement(String docId, Map<String, dynamic> data) async {
    // التحقق من صلاحية المستخدم للتعديل
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? '';
    final editDeleteHelper = EditDeleteHelper();
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

    final canEdit = await editDeleteHelper.canEditItem(userEmail);

    if (canEdit) {
      // إذا كان المستخدم هو المستر، يمكنه التعديل مباشرة
      final TextEditingController priceController = TextEditingController(
        text: data['adad'].toString(),
      );
      final TextEditingController maoakifController = TextEditingController(
        text: data['maoakif'].toString(),
      );

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('تعديل البيانات'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'السعر'),
                    ),
                    TextField(
                      controller: maoakifController,
                      decoration: const InputDecoration(labelText: 'رقم الوقف'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('إلغاء'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('حفظ'),
                  onPressed: () async {
                    await _firestore.collection('astlam').doc(docId).update({
                      'adad': priceController.text,
                      'maoakif': maoakifController.text,
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
      );
    } else {
      // إنشاء طلب موافقة للتعديل
      // عرض رسالة للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('سيتم إرسال طلب للموافقة على التعديل')),
      );

      // إنشاء طلب موافقة للتعديل
      await editDeleteHelper.createEditRequest(
        context: context,
        section: 'astlam',
        itemId: docId,
        requesterName: authProvider.username ?? 'مستخدم',
        requesterEmail: userEmail,
        details: 'طلب تعديل محضر استلام',
        newData: {
          'adad': data['adad'],
          'maoakif': data['maoakif'],
          'requestedEdit': true,
        },
      );
    }
  }

  void _showAgencyDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder:
          (context) => forms.AgencyForm(
            contractId: data['newContractNumber'],
            principalId: data['clientIdentityNumber'],
            principalName: data['customerName'],
            principalPhone: data['clientPhoneNumber'],
            onAgencySaved: (agencyData) async {
              // تسجيل استخدام الوكالة
              try {
                await FirebaseFirestore.instance
                    .collection('agencyUsages')
                    .add({
                      'agencyId': agencyData['id'],
                      'contractId': data['newContractNumber'],
                      'contractType': 'محضر استلام',
                      'usageDate': FieldValue.serverTimestamp(),
                      'usageDetails': 'استخدام في محضر استلام',
                      'usedBy': FirebaseAuth.instance.currentUser?.email,
                    });

                // تحديث الوكالة بإضافة معرف العقد
                await FirebaseFirestore.instance
                    .collection('agencies')
                    .doc(agencyData['id'])
                    .update({
                      'usedIn': FieldValue.arrayUnion([
                        data['newContractNumber'],
                      ]),
                      'lastUsed': FieldValue.serverTimestamp(),
                    });

                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Fprintastlam()),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ في تسجيل استخدام الوكالة: $e'),
                  ),
                );
              }
            },
          ),
    );
  }
}

Future<void> printContract(docId) async {
  final DateTime todayGregorian = DateTime.now();
  final String formattedGregorian =
      "${todayGregorian.year}-${todayGregorian.month}-${todayGregorian.day}";
  final querySnapshot =
      await FirebaseFirestore.instance
          .collection('astlam')
          .where('newContractNumber', isEqualTo: docId)
          .get();

  if (querySnapshot.docs.isEmpty) {
    throw Exception('العقد غير موجود');
  }

  final contractData = querySnapshot.docs.first.data();
  final cont = contractData['newContractNumber'];
  final dateHijri = contractData['contractDateHijri'] ?? '';
  final clientName = contractData['customerName'] ?? '';
  final identityNumber = contractData['clientIdentityNumber'] ?? '';
  final unitNumber = contractData['apartmentNumber'] ?? '';
  final direction = contractData['unitDirection'] ?? '';
  final projectNumber = contractData['projectNumber'] ?? '';
  final price = contractData['adad']?.toString() ?? '0';
  final deedNumber = contractData['deedNumber'] ?? '';
  final regionNumber = contractData['regionNumber'] ?? '';
  final phoneNumber = contractData['clientPhoneNumber'] ?? '';
  final floorNumber = contractData['numberf'] ?? '';
  final planNumber = contractData['numbermo'] ?? '';
  final district = contractData['hy'] ?? '';
  final maoakif = contractData['maoakif'] ?? '';
  DateTime now = DateTime.now().toLocal();
  String dateOnly = DateFormat('yyyy/MM/dd').format(now);

  final pdf = pw.Document();
  final arabicFont = pw.Font.ttf(
    await rootBundle.load('assets/arm/Amiri-Regular.ttf'),
  );
  final imageData = await rootBundle.load('images/m.png');
  final image = pw.MemoryImage(imageData.buffer.asUint8List());
  final imageData1 = await rootBundle.load('images/4.jpg');
  final image1 = pw.MemoryImage(imageData1.buffer.asUint8List());

  // جلب بيانات الوكيل
  final agencySnapshot =
      await FirebaseFirestore.instance
          .collection('agencies')
          .where('contractId', isEqualTo: docId)
          .where(
            'usedIn',
            arrayContains: docId,
          ) // تأكد من استخدام الوكالة في هذا العقد
          .get();

  final agencyData =
      agencySnapshot.docs.isNotEmpty ? agencySnapshot.docs.first.data() : null;

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14),
                decoration: pw.BoxDecoration(
                  image: pw.DecorationImage(image: image1),
                  border: pw.Border.all(width: 1, color: PdfColors.black),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 10),
                    pw.Image(image),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text(
                        'محضر استلام وحدة سكنية وضمانها',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'رقم الشقة .$unitNumber. رقم المشروع .$projectNumber..  ',
                          style: pw.TextStyle(font: arabicFont, fontSize: 11),
                        ),
                        pw.Text(
                          'التاريخ: $dateOnly',
                          style: pw.TextStyle(font: arabicFont, fontSize: 11),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'بهذا اقر بانني استلمت الشقة المبينة بيانتها ادناه و المشتراه من المالك ( شركة مساكن الرفاهية للمقوالات العامة) هوبة رقم (7027279632 ) وهي كاملة البنيان والتشطيبات حسب ما هو على الطبيعة ولالتزام بالتالي : :',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        lineSpacing: 8,
                      ),
                    ),

                    pw.Text(
                      'لا يحق لي القيام باى تعديلات على الهيكل الانشائي او احداث اى تغييرات او تشويه للواجهات  ',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      'لا يحق لي التصرف في الاجزاء المشتركة بين جيمع الملاك في العمارة   ',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      'لا يجق لي المطالبة باى جزء من اجزاء الاسطح السفلية او العلوية للعمارة او استخدامها   ',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      'التزم بنقل ملكية عداد الكهرباء الخاص بالشقة باسمي بعد الافراغ مباشرة ومسئولا عن فواتيره من تاريخ هذا القرار ',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      'اتعهد منفردا ومجتمعا مع ملاك الشقق الاخرى في العمارة بنقل ملكية عداد كهرباء الخدمات وعداد المياه باسم احد اعضاء لجنة الملاك  ',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      'لا يحق لي استخدام المصعد في نقل الاثاث حفاظا على سلامته  ',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      'الاتزام بسداد كل ماتحتاجة العمارة من مصروفات خاصة بالصيانة والنضافة والمياه والحارس  ',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 17),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: pw.FlexColumnWidth(2),
                        1: pw.FlexColumnWidth(1),
                        2: pw.FlexColumnWidth(2),
                        3: pw.FlexColumnWidth(1),
                      },
                      children: [
                        // الصف الأول (عنوان الطرف الأول والطرف الثاني)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                '$price  ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                'رقم عداد الكهرباء  ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                '$direction ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                'اتجاه الشقة  ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                          ],
                        ),
                        // الصف الثاني (أسماء الأطراف)
                        pw.TableRow(
                          children: [
                            pw.Container(
                              padding: pw.EdgeInsets.all(5),

                              child: pw.Text(
                                '$floorNumber',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),

                            pw.Container(
                              padding: pw.EdgeInsets.all(5),

                              child: pw.Text(
                                'الدور  ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(5),

                              child: pw.Text(
                                '$unitNumber ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(5),

                              child: pw.Text(
                                'رقم الشقة  ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                          ],
                        ),
                        // الصف الثالث (تواقيع الأطراف)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                ' $planNumber ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                'مخطط رقم',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                '$district ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'الحي ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                          ],
                        ),
                        // الصف الرابع (أرقام الهوية)
                        pw.TableRow(
                          children: [
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                '$deedNumber',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                'رقم صك الشقة ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                '$regionNumber',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),

                              child: pw.Text(
                                'رقم القطعة ',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Text(
                      'وبعد أن أقر بانني الطرف الأول عاينت الشقة المبينة بياناتها أعلاه معاينة تامة نافية للجهالة، وأني قبلت بحالتها الراهنة التي هي كما عليها ، وأصبحت مسؤولاً عنها المسؤولية المدنية والجنائية، ولا يحق لي الرجوع للمالك لأى سبب، وهذا أقرار مني بذلك ولهذا جرى التوقيع....',
                      style: pw.TextStyle(
                        fontSize: 12,
                        font: arabicFont,
                        height: 1.5, // تباعد بين الأسطر
                      ),
                      textAlign: pw.TextAlign.justify,
                    ),
                    pw.SizedBox(height: 15), // مسافة بين النص والجدول
                    // الجدول أسفل النص

                    // في جدول التوقيعات
                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: pw.FlexColumnWidth(2),
                        1: pw.FlexColumnWidth(1),
                        2: pw.FlexColumnWidth(2),
                        3: pw.FlexColumnWidth(1),
                      },
                      children: [
                        // عنوان الجدول
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            pw.Container(),
                            pw.Text(
                              'الطرف الثاني',
                              style: pw.TextStyle(font: arabicFont),
                            ),
                            pw.Container(),
                            pw.Text(
                              'الطرف الأول',
                              style: pw.TextStyle(font: arabicFont),
                            ),
                          ],
                        ),
                        // بيانات الأطراف
                        pw.TableRow(
                          children: [
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    clientName,
                                    style: pw.TextStyle(font: arabicFont),
                                  ),
                                  if (agencyData != null) ...[
                                    pw.Text(
                                      'بواسطة وكيله:',
                                      style: pw.TextStyle(font: arabicFont),
                                    ),
                                    pw.Text(
                                      agencyData['agentName'],
                                      style: pw.TextStyle(font: arabicFont),
                                    ),
                                    pw.Text(
                                      'رقم الوكالة: ${agencyData['agencyNumber']}',
                                      style: pw.TextStyle(font: arabicFont),
                                    ),
                                    pw.Text(
                                      'هوية الوكيل: ${agencyData['agentId']}',
                                      style: pw.TextStyle(font: arabicFont),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'الاسم',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'شركة مساكن الرفاهية للمقاولات العامة',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'الاسم',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                          ],
                        ),
                        // مساحة للتوقيع
                        pw.TableRow(
                          children: [
                            pw.Container(
                              padding: pw.EdgeInsets.symmetric(vertical: 20),
                              child: pw.Text(
                                '',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'التوقيع',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.symmetric(vertical: 20),
                              child: pw.Text(
                                '',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'التوقيع',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                          ],
                        ),
                        // أرقام الهوية - دائماً نستخدم هوية العميل
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue100,
                          ),
                          children: [
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                identityNumber,
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'رقم الهوية',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                '7027279632',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                            ),
                            pw.Container(
                              padding: pw.EdgeInsets.all(2),
                              child: pw.Text(
                                'رقم الهوية',
                                style: pw.TextStyle(font: arabicFont),
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
          ],
    ),
  );

  if (kIsWeb) {
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'محضر استلام-$cont.pdf',
    );
  } else {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}

pw.Widget _contractField(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Text('$label $value', style: pw.TextStyle(fontSize: 12)),
  );
}

pw.Widget normalCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 10),

      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget mergedCell(String text, {int colspan = 1}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    alignment: pw.Alignment.center,
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget headerCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      textAlign: pw.TextAlign.center,
    ),
  );
}

pw.Widget labelCell(String text) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    ),
  );
}
