import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResalePrinter {
  final String contractId;

  ResalePrinter({required this.contractId});

  Future<void> printContract() async {
    final contractDoc = await FirebaseFirestore.instance
        .collection('resale_contracts')
        .doc(contractId)
        .get();

    if (!contractDoc.exists) {
      throw Exception('العقد غير موجود');
    }

    final contractData = contractDoc.data()!;
    final unitData = contractData['unitData'] ?? {};
    final paidAmount = double.tryParse(contractData['paidAmount'].toString()) ?? 0;
    final totalAmount = double.tryParse(contractData['totalAmount'].toString()) ?? 0;

    final pdf = pw.Document();
    final arabicFont = pw.Font.ttf(await rootBundle.load('assets/Tajawal/Tajawal-Medium.ttf'));
    final imageData = await rootBundle.load('images/m.png');
    final image = pw.MemoryImage(imageData.buffer.asUint8List());

    double adminFee = 5000;
    double resaleCost = 15000;
    double marketingCost = 2500;
    double finalAmount = paidAmount - adminFee;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1, color: PdfColors.black),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 5),
                  pw.Image(image),
                  pw.SizedBox(height: 5),
                  pw.Divider(),
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Text('بسم الله الرحمن الرحيم',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('إعادة بيع', style: pw.TextStyle(font: arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text('تاريخ اليوم: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.SizedBox(height: 20),
                  pw.Text('السيد / .............................. المحترم',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.Text('تحية طيبة وبعد،،،', style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.SizedBox(height: 10),
                  pw.Text('نفيدكم علماً أنه تم إعادة بيع شقة...', style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.SizedBox(height: 10),
                  pw.Bullet(text: 'تم حجز الشقة وكتابة العقد بمبلغ وقدره [$totalAmount] ريال سعودي.', style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.Bullet(text: 'تم خصم [$adminFee] ريال سعودي كمصاريف إدارية.', style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.SizedBox(height: 10),
                  pw.Text('المبلغ النهائي المستحق لكم هو: [$totalAmount] - [$adminFee] = [$finalAmount] ريال سعودي.',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.SizedBox(height: 20),
                  pw.Text('تكاليف سحب الشقة مرة أخرى: [$resaleCost] ريال و [$marketingCost] ريال مصاريف تسويق.',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                  pw.SizedBox(height: 30),
                  pw.Text('مع خالص التحية، شركة مساكن الرفاهية للمقاولات العامة',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14)),
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
