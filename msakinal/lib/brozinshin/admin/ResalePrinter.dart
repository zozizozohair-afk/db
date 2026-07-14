import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResalePrinter {
  final String docId;

  ResalePrinter({required this.docId});

  Future<void> printContract(String contractNumber) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('resale_contracts')
        .where('contractNumber', isEqualTo: contractNumber)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('العقد غير موجود');
    }

    final contractData = querySnapshot.docs.first.data();
    final clientName = contractData['clientName'] ?? '';
    final companyFee = double.tryParse(contractData['companyFee'].toString()) ?? 0;
    final secondPartyAmount = double.tryParse(contractData['secondPartyAmount'].toString()) ?? 0;
    final unitNumber = contractData['unitNumber'] ?? '';
    final direction = contractData['direction'] ?? '';
    final paidAmount = double.tryParse(contractData['paidAmount'].toString()) ?? 0;
    final totalAmount = double.tryParse(contractData['totalAmount'].toString()) ?? 0;
    final marketingFee = double.tryParse(contractData['marketingFee'].toString()) ?? 0;
    final lawyerFee = double.tryParse(contractData['lawyerFee'].toString()) ?? 0;
    final resaleFee = double.tryParse(contractData['resaleFee'].toString()) ?? 0;
    final dateGregorian = contractData['dateGregorian'] ?? '';
    final dateHijri = contractData['dateHijri'] ?? '';
    final identityNumber = contractData['identityNumber'] ?? '';

    final pdf = pw.Document();
    final arabicFont = pw.Font.ttf(await rootBundle.load('assets/Tajawal/Tajawal-Medium.ttf'));
    final imageData = await rootBundle.load('images/m.png');
    final imageDaa = await rootBundle.load('images/4.jpg');
    final image = pw.MemoryImage(imageData.buffer.asUint8List());
    final image1 = pw.MemoryImage(imageDaa.buffer.asUint8List());
    
    // احسب المبلغ النهائي بعد الخصومات
    double totalFees = companyFee + marketingFee + lawyerFee + resaleFee;
    double finalAmount = paidAmount - totalFees;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10),
              decoration: pw.BoxDecoration(
                image: pw.DecorationImage(image: image1, fit: pw.BoxFit.cover),
                border: pw.Border.all(width: 1, color: PdfColors.black),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 1),
                  pw.Image(image),
                  pw.SizedBox(height: 2),
                  pw.Divider(),
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Text('بسم الله الرحمن الرحيم',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الحمد لله والصلاة والسلام على رسول الله ', 
                          style: pw.TextStyle(font: arabicFont, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('التاريخ : $dateHijri', 
                          style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                    ]
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('     السيد /ة/  $clientName   المحترم    (رقم الهوية: $identityNumber)   ', 
                      style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                  pw.SizedBox(height: 7),
                  pw.Text('تحية طيبة وبعد،،،', 
                      style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      'نحيطكم علماً بانكم قد قمتم بشراء شقة رقم .$unitNumber. في الدور رقم ..${contractData['unitData']?['floor'] ?? ''}.. '
                      'بمشروع رقم .${contractData['projectNumber'] ?? ''}. بلهه ..${contractData['unitData']?['city'] ?? ''}..  '
                      'في حي .${contractData['unitData']?['district'] ?? ''}. وهي شقة| .$direction. وفقا للعقد المبرم بينكم وبين '
                      'وبين شركة مساكن الرفاهية للمقاولات العامة والتطوير العقارى بتاريخ $dateHijri.',
                      style: pw.TextStyle(font: arabicFont, fontSize: 11, lineSpacing: 7)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      'ونظراً لرغبتكم في التنازل عن العقد والتخلي عن ملكية الشقة المذكورة , '
                      'وعدم قبولكم افراغ الصك باسمكم وتسليم الشقة لكم , ورغبتكم باعطاء الشركة حق التصرف في بيعها . '
                      'نفيدكم باننا نقبل هذا التنازل بشرط دفع مبلغ اضافي , ونرغب في توضيح الشروط كما يلي',
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text('الطرف الاول :  شركة مساكن الرفاهية', 
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text('الطرف الثاني :  المبرم للعقد مع الشركة \nالطرف الثالث :  المشتري الجديد', 
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      '1. يقر الطرف الثاني بأنه قد استلم من الطرف الأول مبلغ وقدره $secondPartyAmount ريال سعودي فقط لا غير.', 
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      '2. يقر الطرف الثاني بأنه قد تنازل عن كافة حقوقه في العقد المبرم بينه وبين الطرف الأول.', 
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      '3. يقر الطرف الثاني بأنه ليس له أي حقوق مادية أو عينية لدى الطرف الأول بعد استلامه للمبلغ المذكور أعلاه.', 
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      '4. يحق للطرف الأول التصرف في الوحدة العقارية محل العقد بالبيع أو التأجير أو غير ذلك دون الرجوع للطرف الثاني.', 
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      '5. يتحمل الطرف الثاني رسوم إعادة البيع وقدرها $resaleFee ريال سعودي.', 
                      style: pw.TextStyle(lineSpacing: 7, font: arabicFont, fontSize: 11)),
                  pw.SizedBox(height: 20),
                  pw.Text('وعليه جرى التوقيع،،،', 
                      style: pw.TextStyle(font: arabicFont, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 30),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('الطرف الأول', style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                          pw.SizedBox(height: 20),
                          pw.Text('التوقيع: ________________', style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('الطرف الثاني', style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                          pw.SizedBox(height: 20),
                          pw.Text('التوقيع: ________________', style: pw.TextStyle(font: arabicFont, fontSize: 12)),
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}