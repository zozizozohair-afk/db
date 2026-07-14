import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../class/delete_tasoih.dart';
import '../../priovider/auth_provider.dart';
import '../../class/edit_delete_helper.dart';
import '../../class/contract_delete_helper.dart';
import '../../class/logger.dart';

class FinancialSettlementsPage extends StatefulWidget {
  const FinancialSettlementsPage({super.key});

  @override
  _FinancialSettlementsPageState createState() => _FinancialSettlementsPageState();
}

class _FinancialSettlementsPageState extends State<FinancialSettlementsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التسويات المالية',
            style: TextStyle(

                fontWeight: FontWeight.bold,
                fontSize: 22)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.blue.shade800,
                Colors.blue.shade600,
              ],
            ),
          ),
        ),
        elevation: 10,
        shadowColor: Colors.blue.shade200,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
              ),
              child: const Icon(Icons.print, color: Colors.white),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50.withOpacity(0.3),
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    labelText: 'بحث برقم العقد أو اسم العميل',
                    labelStyle: const TextStyle(

                        color: Colors.blueGrey),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.search,
                          color: Colors.blueAccent),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('financialSettlements')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('حدث خطأ في جلب البيانات',
                              style: TextStyle(

                                  color: Colors.red.shade700)));
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  Colors.blue.shade700),
                            ),
                            const SizedBox(height: 16),
                            Text('جاري تحميل البيانات...',
                                style: TextStyle(

                                    color: Colors.blue.shade700)),
                          ],
                        ),
                      );
                    }

                    var docs = snapshot.data!.docs;

                    if (_searchQuery.isNotEmpty) {
                      docs = docs.where((doc) {
                        final data =
                        doc.data() as Map<String, dynamic>;
                        final contractNumber = data[
                        'newContractNumber']
                            ?.toString()
                            .toLowerCase() ??
                            '';
                        final name = data['nameNow']
                            ?.toString()
                            .toLowerCase() ??
                            '';
                        final name1 = data['customerName']
                            ?.toString()
                            .toLowerCase() ??
                            '';
                        return contractNumber
                            .contains(_searchQuery.toLowerCase()) ||
                            name.contains(_searchQuery.toLowerCase()) ||
                            name1.contains(_searchQuery.toLowerCase());
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment,
                                size: 60,
                                color: Colors.blue.shade200),
                            const SizedBox(height: 16),
                            Text('لا توجد تسويات مالية',
                                style: TextStyle(

                                    fontSize: 18,
                                    color: Colors.blueGrey)),
                          ],
                        ),
                      );
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
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data()
                            as Map<String, dynamic>;
                            return _buildSettlementCard(
                                data, docs[index].id);
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
      ),
    );
  }

  Widget _buildSettlementCard(Map<String, dynamic> data, String docId) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.blue.shade100,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
    }
          ,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.assignment,
                          color: Colors.blue.shade700, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data['newContractNumber']?.toString() ?? 'N/A',
                        style: TextStyle(

                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 1),
                _infoRow('العميل البائع:', data['customerName']),
                _infoRow('العميل الجديد:', data['nameNow']),
                _infoRow('السعر الجديد:',
                    '${data['newPrice']?.toString() ?? 'N/A'} ر.س'),
                _infoRow('التاريخ:', data['settlementDate']),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _actionButton(
                      icon: Icons.edit,
                      color: Colors.blue,
                      onPressed: () => _editSettlement(docId, data),
                    ),
                    _actionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      onPressed: () => undoFinancialSettlementForUnit(data['newContractNumber']),
                    ),
                    _actionButton(
                      icon: Icons.print,
                      color: Colors.green,
                      onPressed: () =>
                          printContract(data['newContractNumber']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade700,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: value ?? 'N/A',
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: Colors.grey.shade800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  void _deleteSettlement(String docId) async {
    // استخدام EditDeleteHelper بدلاً من الحذف المباشر
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final editDeleteHelper = EditDeleteHelper();
    final shouldDelete = await editDeleteHelper.showDeleteConfirmationDialog(context, 'التسوية المالية');
    
    if (shouldDelete) {
      try {

        final contractDeleteHelper = ContractDeleteHelper();
        await contractDeleteHelper.deleteFinancialSettlement(docId, context);
        
        // إذا كان المستخدم هو المستر، قم بتنفيذ عملية الحذف مباشرة

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حذف التسوية المالية: $e')),
        );
      }
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
      final TextEditingController priceController = TextEditingController(text: data['newPrice'].toString());

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تعديل السعر'),
          content: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر الجديد'),
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('حفظ'),
              onPressed: () async {
                await _firestore.collection('financialSettlements').doc(docId).update({
                  'newPrice': double.parse(priceController.text),
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else {
      // إنشاء طلب موافقة للتعديل
      // عرض حوار للمستخدم لإدخال السعر الجديد
      final TextEditingController priceController = TextEditingController(text: data['newPrice'].toString());
      
      final shouldEdit = await editDeleteHelper.showEditConfirmationDialog(context, 'التسوية المالية');
      
      if (shouldEdit) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تعديل السعر'),
            content: TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر الجديد'),
            ),
            actions: [
              TextButton(
                child: const Text('إلغاء'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('إرسال للموافقة'),
                onPressed: () async {
                  // إنشاء طلب موافقة للتعديل
                  await editDeleteHelper.createEditRequest(
                    context: context,
                    section: 'financialSettlements',
                    itemId: docId,
                    requesterName: authProvider.username ?? 'مستخدم',
                    requesterEmail: userEmail,
                    details: 'طلب تعديل سعر تسوية مالية',
                    newData: {
                      'newPrice': double.parse(priceController.text),
                      'requestedEdit': true
                    },
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
    }
  }
  }
Future<void> printContract(docId) async {
  final DateTime todayGregorian = DateTime.now();
  final String formattedGregorian = "${todayGregorian.year}-${todayGregorian.month}-${todayGregorian.day}";
  final querySnapshot = await FirebaseFirestore.instance
      .collection('financialSettlements')
      .where('newContractNumber', isEqualTo: docId)
      .get();

  if (querySnapshot.docs.isEmpty) {
    throw Exception('العقد غير موجود');
  }

  final contractData = querySnapshot.docs.first.data();
  final dateHijri = contractData['contractDateHijri'] ?? '';
  final settlementDate = contractData['settlementDate'] ?? '';
  final clientName = contractData['customerName'] ?? '';
  final identityNumber = contractData['clientIdentityNumber'] ?? '';
  final newClientName = contractData['nameNow'] ?? '';
  final newClientId = contractData['newCustomerId'] ?? '';
  final unitNumber = contractData['apartmentNumber'] ?? '';
  final direction = contractData['unitDirection'] ?? '';
  final projectNumber = contractData['projectNumber'] ?? '';
  final newPrice = contractData['newPrice']?.toStringAsFixed(0) ?? '0';
  final deedNumber = contractData['deedNumber'] ?? '';
  final regionNumber = contractData['regionNumber'] ?? '';
  final phoneNumber = contractData['clientPhoneNumber'] ?? '';
  final cont = contractData['newContractNumber']??'1';

  final pdf = pw.Document();
  final arabicFont = pw.Font.ttf(
    await rootBundle.load('assets/arm/Amiri-Regular.ttf'),
  );
  final imageData = await rootBundle.load('images/m.png');
  final imageDaa = await rootBundle.load('images/4.jpg');
  final image = pw.MemoryImage(imageData.buffer.asUint8List());

  final image1 = pw.MemoryImage(imageDaa.buffer.asUint8List());

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            decoration: pw.BoxDecoration(
                image: pw.DecorationImage(image: image1,fit: pw.BoxFit.cover),
              border: pw.Border.all(width: 1, color: PdfColors.black),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 1),
                pw.Image(image,),
                pw.SizedBox(height: 1),
                pw.Divider(),
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text('تسوية مالية',
                      style: pw.TextStyle(font: arabicFont, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('بين كلا من ',
                        style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                    pw.Text('التاريخ: $settlementDate',
                        style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                  ],
                ),
                pw.SizedBox(height: 25),
                pw.Text('الطرف الأول:',
                    style: pw.TextStyle(font: arabicFont, fontSize: 15, fontWeight: pw.FontWeight.bold)),
               pw.SizedBox(height: 14),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('شركة مساكن الرقاهية للمقاولات العامة',
                        style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                    pw.Text('الرقم الموحد: 920007936',
                        style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                  ]
                ),
                pw.SizedBox(height: 15),
                pw.Text('الطرف الثاني:',
                    style: pw.TextStyle(font: arabicFont, fontSize: 15, fontWeight: pw.FontWeight.bold))
                ,pw.SizedBox(height: 16),
               pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                 children: [
                   pw.Text(' $clientName',
                       style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                   pw.Text('حامل الهوية رقم: $identityNumber',
                       style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                   pw.Text('جوال: $phoneNumber',
                       style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                 ]
               ),
                pw.SizedBox(height: 15),
                pw.Text('بناءً على عقد الشراء الشقة تحت الانشاء السابق  المؤرخ في $dateHijri , على الشقة رقم .$unitNumber.. وهي شقة  ${contractData['unitDirection']} من القطعة رقم .$regionNumber.  الذى قام بشرائها الطرف الثاني من الاول يقر الطرف الثاني .$clientName. بانه وافق على بيع الشقة بسعر  .$newPrice. الف ريال سعودى بتاريخ .$formattedGregorian. ',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13,lineSpacing: 8)),
                pw.SizedBox(height: 15),
                pw.Text(' سيتم بيع الشقة للمالك الجديد : $newClientName    حامل الهوية رقم  $newClientId  \nوتحويل مبلغ $newPrice   الاف الى رصيد السيد/ة  $clientName  لدى الشركة وله الحق في استردارده او شراء شقة اخرى به .',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13, fontWeight: pw.FontWeight.bold,lineSpacing: 7)),
                pw.SizedBox(height: 15),
                pw.Text('ويؤكد الطرف الثاني بتوقيعه وبصمتة على هذه الورقة انه لا يطالب شركة مساكن الرفاهية للمقاولات العامة او ممثليها باى مبالغ اخرى غير المذكور او الشقة المذكورة اعلاه بعد تاريخه , وانة قام باتوقيع والموافقة وهو بكامل اهليتة المعتبرة شرعا دون اى اكراه من اى طرف . ',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13,lineSpacing: 7)),
                pw.SizedBox(height: 20),
                    pw.Column(
                      children: [
                        pw.Text('توقيع الطرف الثاني',
                            style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                        pw.SizedBox(height: 20),
                        pw.Text('الاسم: $clientName',
                            style: pw.TextStyle(font: arabicFont, fontSize: 13)),
                      ],
                    ),

                pw.SizedBox(height: 30),
                pw.Text('البصمة:',
                    style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                pw.SizedBox(height: 20)
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
      filename: 'تسوية مالية-$cont.pdf',
    );
  } else {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}