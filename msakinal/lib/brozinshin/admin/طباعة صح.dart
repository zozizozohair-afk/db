import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Prinerer2 extends StatefulWidget {
  const Prinerer2({super.key});

  @override
  State<Prinerer2> createState() => _PrinererState();
}

class _PrinererState extends State<Prinerer2> {
  Map<String, dynamic>? contractData;
  String newDocumentNumber = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طباعة العقد")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'رقم الصك الجديد'),
              onChanged: (val) => newDocumentNumber = val,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final data = await fetchContractData(
                  newDocumentNumber: newDocumentNumber,
                );

                if (data != null) {
                  setState(() {
                    contractData = data;
                  });
                  await _generateContract();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("لم يتم العثور على بيانات.")),
                  );
                }
              },
              child: const Text("طباعة العقد"),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> fetchContractData({
    required String newDocumentNumber,
  }) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('contracts')
            .where('newDocumentNumber', isEqualTo: newDocumentNumber)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  Future<void> _generateContract() async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.tajawalRegular();
    final imageData = await rootBundle.load('images/m.png');
    final image = pw.MemoryImage(imageData.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
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
                      child: pw.Text(
                        'عقد بيع شقة - رقم الصك: (${contractData?['newDocumentNumber'] ?? '____'})',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Center(
                      child: pw.Text(
                        'بسم الله الرحمن الرحيم',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Center(
                      child: pw.Text(
                        'الحمد لله والصلاة والسلام على رسول الله',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text(
                          'تاريخ العقد هـ : ____',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                        pw.Text(
                          'تاريخ العقد م : ____',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 30),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text(
                          'الطرف الأول : شركة مساكن الرفاهية',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                        pw.Text(
                          'رقم الجوال : 920007936',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'س . ت : 7027279632',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Row(
                      children: [
                        pw.Text(
                          'اسم المدينة : ${contractData?['city'] ?? '____'}  ',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                        pw.Text(
                          'الحي : ${contractData?['district'] ?? '____'}  ',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'اسم المشتري : ${contractData?['customerName'] ?? '____'}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.Text(
                      'رقم الهوية : ${contractData?['nationalId'] ?? '____'}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.Text(
                      'رقم الجوال : ${contractData?['phone'] ?? '____'}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'المبلغ الكلي : ${contractData?['totalAmount'] ?? '____'} ريال',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.Text(
                      'المدفوع كاش : ${contractData?['cashPaid'] ?? '____'} ريال',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.Text(
                      'المدفوع شيك : ${contractData?['checkPaid'] ?? '____'} ريال - رقم الشيك: ${contractData?['checkNumber'] ?? '____'}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.Text(
                      'المدفوع حوالة : ${contractData?['transferPaid'] ?? '____'} ريال - رقم الحوالة: ${contractData?['transferNumber'] ?? '____'}',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.Text(
                      'المتبقي : ${contractData?['remaining'] ?? '____'} ريال',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Text(
                      'وحرر بينهم هذا العقد على نسختين',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
