import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'اللطباعة.dart';

class Prinerer extends StatefulWidget {
  final String contractId;
  const Prinerer({super.key, required this.contractId});

  @override
  State<Prinerer> createState() => _PrinererState();
}

class _PrinererState extends State<Prinerer> {
  bool _isPrinting = false;
  bool showAgencyFields = false;

  final TextEditingController _agentNameController = TextEditingController();
  final TextEditingController _agentIdController = TextEditingController();
  final TextEditingController _agencyNumberController = TextEditingController();
  final TextEditingController _agencyDateController =
      TextEditingController(); // تاريخ الوكالة
  String fonter = '';

  // متغيرات البحث والربط
  final TextEditingController _agentSearchController =
      TextEditingController(); // للبحث عن الوكيل
  final TextEditingController _principalIdController =
      TextEditingController(); // هوية الموكل

  // متغيرات لحفظ بيانات الموكل
  String? principalName;
  String? principalPhone;

  // متغيرات لبيانات الوكيل بعد البحث
  String? agentName;
  String? agentId;
  String? agencyNumber;
  String? savedAgentName;
  String? savedAgentId;
  String? savedAgencyNumber;
  String? savedAgencyDate;
  String? savedPrincipalName;
  String? savedPrincipalPhone;

  // أضف متغير لتخزين بيانات العقد
  Map<String, dynamic>? contractData;

  // إضافة متغير جديد لتخزين الوكالات الحالية
  List<Map<String, dynamic>> existingAgencies = [];
  Map<String, dynamic>? selectedAgency;

  Future<List<Map<String, dynamic>>> fetchPayments({
    required String idNumber,
    required String pn,
  }) async {
    // جلب الدفعات العادية (له)
    final paymentsQuery =
        await FirebaseFirestore.instance
            .collection('financialTransactions')
            .where('idNumber', isEqualTo: idNumber)
            .where('pn', isEqualTo: pn)
            .where('debitCredit', isEqualTo: 'له')
            .get();
    List<Map<String, dynamic>> allPayments = [];

    // إضافة الدفعات العادية
    allPayments.addAll(
      paymentsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'transactionType': data['transactionType'] ?? '',
          'date':
              data['date'] is Timestamp
                  ? (data['date'] as Timestamp).toDate()
                  : DateTime.tryParse(data['date'].toString()) ??
                      DateTime.now(),
          'cod': data['cod'] ?? '',
          'amount': data['amount']?.toDouble() ?? 0.0,
          'description': data['description'] ?? '',
        };
      }).toList(),
    );

    // إضافة العربون

    // ترتيب الدفعات حسب التاريخ
    allPayments.sort((a, b) => a['date'].compareTo(b['date']));

    return allPayments;
  }

  Map<String, dynamic>? _lastContractData;

  // تعديل _generateContract لتخزين بيانات العقد
  Future<void> _generateContract() async {
    final contractDoc =
        await FirebaseFirestore.instance
            .collection('contracts')
            .doc(widget.contractId)
            .get();

    if (!contractDoc.exists) {
      // محاولة البحث في مجموعة إعادة البيع
      final resaleDoc =
          await FirebaseFirestore.instance
              .collection('resale_contracts')
              .doc(widget.contractId)
              .get();
      if (!resaleDoc.exists) {
        // التحقق من أن السياق لا يزال نشطًا قبل استخدام ScaffoldMessenger
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'العقد غير موجود في العقود الأساسية ولا في عقود إعادة البيع',
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
      // إذا وجد في إعادة البيع استخدم بياناته
      final contractData = resaleDoc.data()!;
      final clientData =
          contractData['clientData'] as Map<String, dynamic>? ?? {};
      final unitData = contractData['unitData'] as Map<String, dynamic>? ?? {};
      // ... باقي الكود كما هو مع استخدام contractData و clientData و unitData
      // يمكنك هنا نسخ منطق استخراج البيانات وإنشاء PDF من الأسطر التالية
      // ...
      return;
    }

    contractData = contractDoc.data()!;
    final clientData =
        contractData!['clientData'] as Map<String, dynamic>? ?? {};
    final unitData = contractData!['unitData'] as Map<String, dynamic>? ?? {};

    // استخراج البيانات المطلوبة
    final projectNumber = contractData!['projectNumber'] ?? 'غير محدد';
    final unitNumber = contractData!['unitNumber'] ?? 'غير محدد';
    final clientName = contractData!['clientName'] ?? 'غير معروف';
    final clientId = contractData!['identityNumber'] ?? 'غير محدد';

    final clientPhone = clientData['phoneNumber'] ?? 'غير محدد';

    // اجعل بيانات الموكل من العقد مباشرة
    principalName = clientName;
    principalPhone = clientPhone;

    final totalAmount = contractData!['totalAmount']?.toString() ?? '0';
    final deliveryMonths = contractData!['deliveryMonths']?.toString() ?? '0';
    final deliveryDays = contractData!['deliveryDays']?.toString() ?? '0';
    final arre = unitData['area'];

    final payments = await fetchPayments(
      idNumber: clientId,
      pn: contractData!['pn'],
    );

    final gregorianDate =
        contractData!['dateGregorian'] != null
            ? DateFormat(
              'yyyy/MM/dd',
            ).format(DateTime.parse(contractData!['dateGregorian']))
            : '____';
    String getArabicMonthName(String englishMonthName) {
      const monthNames = {
        'Muharram': 'محرم',
        'Safar': 'صفر',
        'Rabi\' Al-Awwal': 'ربيع الأول',
        'Rabi\' Al-Thani': 'ربيع الثاني',
        'Jumada Al-Awwal': 'جمادى الأولى',
        'Jumada Al-Thani': 'جمادى الآخرة',
        'Rajab': 'رجب',
        'Sha\'Ban': 'شعبان',
        'Ramadan': 'رمضان',
        'Shawwal': 'شوال',
        'Dhu Al-Qi\'dah': 'ذو القعدة',
        'Dhu Al-Hijjah': 'ذو الحجة',
      };

      return monthNames[englishMonthName] ?? englishMonthName;
    }

    // دالة لتحويل الأرقام الإنجليزية إلى عربية (إذا كنت تحتاجها)
    String convertToArabicNumbers(String input) {
      const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

      String output = input;
      for (int i = 0; i < english.length; i++) {
        output = output.replaceAll(english[i], arabic[i]);
      }

      return output;
    }

    final hijriDate =
        contractData!['dateGregorian'] != null
            ? "${convertToArabicNumbers(HijriCalendar.fromDate(DateTime.parse(contractData!['dateGregorian'])).hDay.toString())} "
                "${getArabicMonthName(HijriCalendar.fromDate(DateTime.parse(contractData!['dateGregorian'])).longMonthName)} "
                "${convertToArabicNumbers(HijriCalendar.fromDate(DateTime.parse(contractData!['dateGregorian'])).hYear.toString())} هـ"
            : '____';

    // دالة لتحويل أسماء الأشهر الإنجليزية إلى العربية

    final city = unitData['city'] ?? '____';
    final district = unitData['district'] ?? '____';
    final floor = unitData['floor'];
    final deedNumber = unitData['deedNumber'] ?? '____';
    final planNumber = unitData['planNumber'] ?? '____';
    final direction = unitData['direction'] ?? '____';
    final description = unitData['description'] ?? '____';
    final regionNumber = unitData['regionNumber'] ?? '';
    final idcontact = projectNumber + unitNumber + clientId;
    // تحويل القيم الرقمية

    final arabicFont = pw.Font.ttf(
      await rootBundle.load('assets/arm/Amiri-Regular.ttf'),
    );

    final arabicFontb = pw.Font.ttf(
      await rootBundle.load('assets/arm/Amiri-Bold.ttf'),
    );

    final total = double.tryParse(totalAmount) ?? 0.0;

    // جدول المدفوعات
    late double paid = 0.0;
    // هذا يحسب مجموع المدفوعات قبل بناء الجدول
    double calculatePaidAmount(List<Map<String, dynamic>> payments) {
      double totalAmount = 0.0;
      for (final payment in payments) {
        final amount = payment['amount'] ?? 0.0;
        totalAmount += amount;
      }
      return totalAmount;
    }

    // هنا يتم استدعاء قبل بناء الجدول
    paid = calculatePaidAmount(payments);

    late String paymentStatusDescription;

    if (paid >= total) {
      paymentStatusDescription = ' يتم الدفع الفورى للمبلغ الاجمالي ';
    } else {
      final remaining = total - paid;
      final percentage = (paid / total * 100).toStringAsFixed(1);
      final duration = '  $deliveryDays يوم';

      paymentStatusDescription =
          'دفع مبلغ وقدره $paid ريال سعودى يتم دفعة فورا \n ويتم دفع المتبقي خلال مدة $deliveryDays يوماً تبدا من تاريخه والمتبقي هو $remaining ر.س ';
    }

    String getAgentDataText() {
      if (savedAgentName != null &&
          savedAgentId != null &&
          savedAgencyNumber != null) {
        return '  ووكيلاً عنه: $savedAgentName\n'
            'حامل الهوية: $savedAgentId\n'
            'برقم وكالة: $savedAgencyNumber\n';
      } else {
        return '';
      }
    }

    final son = getAgentDataText();
    pw.Widget buildPaymentsTable(List<Map<String, dynamic>> payments) {
      double totalAmount = 0.0;
      int counter = 1;

      final textStyle = pw.TextStyle(font: arabicFont, fontSize: 9);

      final smallTextStyle = pw.TextStyle(font: arabicFont, fontSize: 7);

      final boldTextStyle = pw.TextStyle(
        font: arabicFont,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      );

      pw.Widget cell(String text, {pw.TextStyle? style}) {
        return pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            text,
            style: style ?? textStyle,
            textAlign: pw.TextAlign.center,
          ),
        );
      }

      final rows = <pw.TableRow>[
        pw.TableRow(
          children: [
            cell('طريقة الدفع', style: boldTextStyle),
            cell('التاريخ', style: boldTextStyle),
            cell('رقم المرجع', style: boldTextStyle),
            cell('المبلغ', style: boldTextStyle),
            cell('البيان', style: boldTextStyle),
            cell('م', style: boldTextStyle),
          ],
        ),
      ];

      for (final payment in payments) {
        final amount = payment['amount'] ?? 0.0;
        totalAmount += amount;

        rows.add(
          pw.TableRow(
            children: [
              cell(payment['transactionType']),
              cell(payment['date'].toString().split(' ')[0]),
              cell(payment['cod'] ?? '541848711'),
              cell('${amount.toStringAsFixed(2)} ر.س'),
              cell(payment['description'], style: smallTextStyle),
              cell('$counter'),
            ],
          ),
        );

        counter++;
      }

      rows.add(
        pw.TableRow(
          children: [
            cell(''),
            cell(''),
            cell(''),
            cell(''),
            cell('${totalAmount.toStringAsFixed(2)} ر.س', style: boldTextStyle),
            cell('الإجمالي', style: boldTextStyle),
          ],
        ),
      );

      setState(() {
        paid = totalAmount;
      });
      return pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Table(
          border: pw.TableBorder.all(),
          children: rows,
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        ),
      );
    }

    // إنشاء وصف حالة الدفع بعد أن يتم تنفيذ buildPaymentsTable()

    setState(() {});
    final pdf = pw.Document();

    final imageData = await rootBundle.load('images/m.png');
    final imageDaa = await rootBundle.load('images/4.jpg');
    final image = pw.MemoryImage(imageData.buffer.asUint8List());

    final image1 = pw.MemoryImage(imageDaa.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 5),
                decoration: pw.BoxDecoration(
                  image: pw.DecorationImage(image: image1),
                  border: pw.Border.all(width: 2, color: PdfColors.black),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 5),
                    pw.Image(image),
                    pw.SizedBox(height: 5),
                    pw.Divider(),
                    pw.SizedBox(height: 10),

                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text(
                        ' عقد بيع شقة - مشروع رقم: ($projectNumber)',
                        style: pw.TextStyle(
                          font: arabicFontb,
                          fontSize: 14,
                          color: PdfColor.fromHex('#0086BF'),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 30),
                    pw.Center(
                      child: pw.Text(
                        'بسم الله الرحمن الرحيم',
                        style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                      ),
                    ),

                    pw.SizedBox(height: 15),

                    pw.Center(
                      child: pw.Text(
                        'الحمد لله والصلاة والسلام على رسول الله',
                        style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'تاريخ العقد : $gregorianDate م ',
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 14,
                            color: PdfColor.fromHex('#0086BF'),
                          ),
                        ),
                        pw.Text(
                          'الموافق :$hijriDate',
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 14,
                            color: PdfColor.fromHex('#0086BF'),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 21),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'الطرف الأول: شركة مساكن الرفاهية للتطوير العقارى',
                          style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                        ),
                        pw.Text(
                          'رقم الجوال: 920007936',
                          style: pw.TextStyle(font: arabicFont, fontSize: 14),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'س.ت: 7027279632',
                      style: pw.TextStyle(font: arabicFontb, fontSize: 17),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '   اسم المدينة :  $city',
                          style: pw.TextStyle(
                            font: arabicFontb,
                            fontSize: 14,
                            color: PdfColor.fromHex('#0086BF'),
                          ),
                        ),
                        pw.Text(
                          '   الحي: $district',
                          style: pw.TextStyle(
                            font: arabicFontb,
                            fontSize: 14,
                            color: PdfColor.fromHex('#0086BF'),
                          ),
                        ),
                        pw.Text(
                          '   اسم المخطط: $planNumber',
                          style: pw.TextStyle(
                            font: arabicFontb,
                            fontSize: 14,
                            color: PdfColor.fromHex('#0086BF'),
                          ),
                        ),
                        pw.SizedBox(width: 25),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '  رقم الصك:   $deedNumber',
                          style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                        ),
                        pw.Text(
                          '  رقم القطعة: $regionNumber',
                          style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                        ),
                        pw.SizedBox(width: 25),
                      ],
                    ),
                    pw.SizedBox(height: 25),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          ' الطرف الثاني : $clientName',
                          style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                        ),
                        pw.Text(
                          ' رقم الهوية: $clientId',
                          style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                        ),
                        pw.SizedBox(width: 25),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'رقم الجوال: $clientPhone',
                      style: pw.TextStyle(font: arabicFontb, fontSize: 14),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'لقد باع الطرف الأول شقة معلومة المواصفات والمقاييس مساحتها ($arre) متر مربع تقريباً سطح مع مباني واشترى الطرف الثاني',
                      style: pw.TextStyle(
                        font: arabicFontb,
                        fontSize: 14,
                        lineSpacing: 7,
                        color: PdfColor.fromHex('#0086BF'),
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      'وحرر بينهم هذا العقد على نسختين:',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 60),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: idcontact,
                          width: 60,
                          height: 60,
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20), // هوامش خفيفة
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                image: pw.DecorationImage(image: image1),
                border: pw.Border.all(width: 2, color: PdfColors.black),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ✅ الشعار في الأعلى
                  pw.Center(child: pw.Image(image)),
                  pw.Divider(),

                  pw.SizedBox(height: 9),
                  pw.Text(
                    'القسم الاول: شروط العقد:',
                    style: pw.TextStyle(font: arabicFont, fontSize: 14),
                  ),
                  pw.SizedBox(height: 6),

                  // ✅ البنود كاملة
                  pw.Text(
                    '1- تملك الطــرف الثــاني شــقة رقـم $unitNumber  فــي الــدور رقم  $floor',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#0086BF'),
                      font: arabicFont,
                      fontSize: 13,
                      lineSpacing: 2,
                    ),
                  ),

                  pw.Text(
                    '   2- وهي  الموقع   $direction    بمبلغ وقدره  $totalAmount ريال سعودى',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#0086BF'),
                      font: arabicFont,
                      fontSize: 13,
                      lineSpacing: 2,
                    ),
                  ),

                  pw.Text(
                    ' من القطعة رقم$regionNumber)',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#0086BF'),
                      font: arabicFont,
                      fontSize: 13,
                      lineSpacing: 2,
                    ),
                  ),

                  pw.Text(
                    'شروط الدفع \n   $paymentStatusDescription ',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#0086BF'),
                      font: arabicFont,
                      fontSize: 13,
                      lineSpacing: 2,
                    ),
                  ),
                  buildPaymentsTable(payments),

                  pw.Text(
                    '  رقم الدور: $floor     رقم الشقة: $unitNumber      الوصف: $description',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#0086BF'),
                      font: arabicFont,
                      fontSize: 13,
                    ),
                  ),

                  pw.Text(
                    '3- تخليص كل ما تطلبه الأوراق الرسمية والحكومية عن طريق شركة مساكن الرفاهية.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '4- لا يحق للطرفين فسخ العقد بعد التوقيع',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '5- يتحمل الطرف الثاني رسوم المياه التي تفرضها الدولة',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '6- لا يحق للطرف الثاني المطالبة بالمبلغ بعد توقيع العقد.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '7- بناء المشروع حسب ما هو موجود في المخطط الكروكي المرفق والمختوم من الشركة ولا تتحمل الشركة أى تعديل في قيشاني الجدران والارضيات للشقق او أى تعديل اخر.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '8- سعر الشقة لا يشمل الضريبة',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '9- مدة تنفيذ المشروع وتسليمه ($deliveryMonths) شهرًا من تاريخ توقيع العقد، باستثناء شهر رمضان. ومع ذلك، إذا حدث تأخير ناتج عن ظروف قاهرة خارجة عن سيطرة الشركة، مثل الكوارث الطبيعية (كالزلازل، الفيضانات، الأعاصير، وغيرها)، أو نتيجة قرارات أو إجراءات صادرة عن الجهات الحكومية أو الرسمية تؤثر على سير العمل، فإنه يتم تمديد مدة المشروع بما يعادل فترة التأخير دون أن تتحمل الشركة أى مسؤولية أو غرامات نتيجة لذلك.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '10- يتحمل الطرف الثاني أى رسوم وضــرائب حكوميــة تفرضــها الدولــة بعــد إطلاق التيــار الكهربــائي ورســوم الميــاه التي تفرضها الدولة',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '11- الشركة لا تتحمل أى تعديل او إضافات في الشقة وفي حالة التعديل يكون التعديل قبل العمل وفي حال بدا العمل لن يتم أى تعديل نهائيا',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),

                  pw.Text(
                    '12- شرط جزائي في حال التأخر عن التسليم أكثر من ($deliveryMonths) شهر من تاريخ توقيع العقد عن كل شــهر تــأخير 1500 الف ريــال فقط لا غير ويأخذ البند رقم 9 بعين الاعتبار.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20), // ✅ هوامش صغيرة
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                image: pw.DecorationImage(image: image1),
                border: pw.Border.all(width: 2, color: PdfColors.black),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ✅ الشعار في الأعلى
                  pw.Center(child: pw.Image(image)),
                  pw.Divider(),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'القسم الثاني: مواصفات البناء:',
                    style: pw.TextStyle(font: arabicFont, fontSize: 16),
                  ),
                  pw.SizedBox(height: 15),

                  // ✅ العنوان الرئيسي
                  pw.Text(
                    'مرحلة البناء والعظم:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 15),

                  // ✅ البنود
                  pw.Text(
                    '1- عمل لبشة أو قواعد حسب ما يقرره المكتب الهندسي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '2- استخداما السمنت المقاوم للقواعد والميدات والرقاب وخزان المياه والبيارة.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '3- عزل القواعد والحمامات وخزان المياه والسطح بعازل مائي بيوت مات 4 ملم.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '4- المباني الداخلية بلوك أحمر والخارجية بلوك احمر معزول مقاس 20*40*20.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.SizedBox(height: 15),
                  pw.Text(
                    'مرحلة التشطيب:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // ✅ القسم الأول
                  pw.Text(
                    'أولًا: الأعمال المعمارية:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text(
                    '1- الواجهة الرئيسية حسب ما تراه الشركة مواكب للتطور العمراني.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '2- التشطيبات ليآسة إسمنتية ببطحة الشعيبة + الرياض.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '3- الأرضيات الحواش والسطح مزايكو المتر 12 ريال داخل الشقة سيراميك المتر 18 ريال.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '4- الجدران قيشاني المتر 13 ريال.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.SizedBox(height: 12),
                  pw.Text(
                    'ثانيًا: الأعمال الكهربائية:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '1- الكابلات من الشركة السعودية 35 ملم، 50 ملم.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '2- تركيب طبلون لكل شقة.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '3- تركيب قاطع كهرباء إلترا.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '4- اللمبات في الغرف كبس عادى.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.Text(
                    '5- أفياش نوع ألفا.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.Text(
                    '6- أفياش التلفون نوع ألفا.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.Text(
                    '7- أفياش التلفزيون نوع ألفا.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.Text(
                    '8- تأسيس مراوح شفط مقاس 25*25 سم للحمامات والمطابخ.',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 13,
                      lineSpacing: 12,
                    ),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '9- لكل شقة عداد مستقل.',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 13,
                      lineSpacing: 12,
                    ),
                  ),
                  pw.SizedBox(height: 7),

                  // ✅ القسم الثاني
                ],
              ),
            ),
          );
        },
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                image: pw.DecorationImage(image: image1),
                border: pw.Border.all(width: 2, color: PdfColors.black),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // ✅ الشعار في الأعلى
                  pw.Center(child: pw.Image(image)),
                  pw.Divider(),
                  pw.SizedBox(height: 7),

                  pw.Text(
                    'ثالثًا: الأعمال الصحية:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 7),
                  pw.Text(
                    '1- أطقم الحمامات والمغاسل 500 ريال للطقم الواحد.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '2- الخلاط للكراسي 200 ريال.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '3- تمديدات للسخانات.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '4- مواسير للصرف الصحي 4 بوصة سماكة 7 مم خليجي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '5- مواسير المياه 2 بوصة و¾ بوصة ضغط 80 حار خليجي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '6- محابس الدفن المائي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 12),
                  ),

                  pw.Text(
                    '7- الليات والشطافات إريال ستاندر المائي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '8- محابس الزاوية المائي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '9- صفايات ومهرب المغاسل ايطالي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    'رابعًا: أعمال الجبس:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '1- نظام ساقط كامل.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    'خامسًا: أعمال الدهان:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'نوع جوتن والجزيرة سادة.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.Text(
                    'سادسًا: الأعمال الخشبية:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '1- باب الشقة الرئيسي خشب مقنو درجة أولى مع دهان الستار والكيلون والمقبض.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.Text(
                    '2- الأبواب الداخلية من قشر السنديان والكيلون والمقبض 50 ريال.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.SizedBox(width: 30),
                ],
              ),
            ),
          );
        },
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                image: pw.DecorationImage(image: image1),
                border: pw.Border.all(width: 2, color: PdfColors.black),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(child: pw.Image(image)),
                  pw.Divider(),
                  pw.SizedBox(height: 50),

                  pw.Text(
                    'سابعًا: أعمال الألمنيوم:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '1- لون حليبي أو أسود أو أبيض النوع البكو خليجي.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 12),
                  ),

                  pw.Text(
                    '2- الزجاج دبل جلاس الخط أبيض مانع للحرارة والصوت.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 12),
                  ),
                  pw.SizedBox(height: 50),
                  pw.Text(
                    'ملاحظات:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.Text(
                    'دولاب المطبخ والسخانات وشبك الحديد للشبابيك ليست ضمن قيمة العقد .',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),
                  pw.Text(
                    '• إبراء للذمة في حال عدم توفر نوع من إحدى مواصفات البناء الموضحة في العقد بالسوق يتم تغييرها بما يعادلها من الجودة.',
                    style: pw.TextStyle(font: arabicFont, fontSize: 13),
                  ),

                  pw.SizedBox(height: 150),

                  // ✅ توقيعات الأطراف بتنسيق جذاب
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.SizedBox(width: 60),
                          pw.Text(
                            'الطرف الأول: \n شركة مساكن الرفاهية ',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#0086BF'),
                              lineSpacing: 7,
                              font: arabicFontb,
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 60),
                          pw.Container(
                            width: 120,
                            height: 1,
                            color: PdfColors.grey,
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'التوقيع',
                            style: pw.TextStyle(font: arabicFont, fontSize: 13),
                          ),
                        ],
                      ),
                      pw.SizedBox(width: 120),
                      pw.Column(
                        children: [
                          pw.Text(
                            'الطرف الثاني: \n $clientName '
                            '\n $son',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#0086BF'),
                              lineSpacing: 7,
                              font: arabicFontb,
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 60),
                          pw.Container(
                            width: 120,
                            height: 1,
                            color: PdfColors.grey,
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'التوقيع',
                            style: pw.TextStyle(font: arabicFont, fontSize: 13),
                          ),
                        ],
                      ),
                      pw.SizedBox(width: 30),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'عقدتحت الانشاء-${contractData!['pn']}.pdf',
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
      child: pw.Text('$label $value', style: pw.TextStyle(fontSize: 13)),
    );
  }

  // دالة البحث عن الوكيل في جدول الوكالات
  Future<void> searchAgent() async {
    final String searchId = _agentSearchController.text.trim();
    if (searchId.isEmpty) return;

    try {
      final agentDoc =
          await FirebaseFirestore.instance
              .collection('agencies')
              .where('agentId', isEqualTo: searchId)
              .limit(1)
              .get();

      if (agentDoc.docs.isNotEmpty) {
        final data = agentDoc.docs.first.data();
        setState(() {
          _agentNameController.text = data['agentName'] ?? '';
          _agentIdController.text = data['agentId'] ?? '';
          // لا نملأ رقم الوكالة لأنه سيكون جديداً
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في البحث عن الوكيل: $e')));
    }
  }

  // دالة حفظ الوكالة
  Future<void> saveAgency() async {
    if (selectedAgency != null) {
      try {
        // تحديث الوكالة
        await FirebaseFirestore.instance
            .collection('agencies')
            .doc(selectedAgency!['id'])
            .update({
              'usedIn': FieldValue.arrayUnion([widget.contractId]),
              'lastUsed': FieldValue.serverTimestamp(),
            });

        // تحديث العقد بإضافة معرف الوكالة
        await FirebaseFirestore.instance
            .collection('contracts')
            .doc(widget.contractId)
            .update({
              'agencyId': selectedAgency!['id'],
              'agentName': selectedAgency!['agentName'],
              'agentId': selectedAgency!['agentId'],
              'agencyNumber': selectedAgency!['agencyNumber'],
              'agencyDate': selectedAgency!['agencyDate'],
            });

        // تسجيل استخدام الوكالة
        await FirebaseFirestore.instance.collection('agencyUsages').add({
          'agencyId': selectedAgency!['id'],
          'contractId': widget.contractId,
          'contractType': 'عقد تحت الانشاء',
          'usageDate': FieldValue.serverTimestamp(),
          'usageDetails': 'طباعة عقد تحت الانشاء',
          'usedBy': FirebaseAuth.instance.currentUser?.email,
        });

        setState(() {
          savedAgentName = selectedAgency!['agentName'];
          savedAgentId = selectedAgency!['agentId'];
          savedAgencyNumber = selectedAgency!['agencyNumber'];
          savedAgencyDate = selectedAgency!['agencyDate'];
          showAgencyFields = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم ربط الوكالة بالعقد بنجاح')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ في ربط الوكالة: $e')));
      }
      return;
    }

    // في حالة إضافة وكالة جديدة
    if (_agentNameController.text.isEmpty ||
        _agentIdController.text.isEmpty ||
        _agencyNumberController.text.isEmpty ||
        _agencyDateController.text.isEmpty ||
        _principalIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تعبئة جميع الحقول المطلوبة')),
      );
      return;
    }

    try {
      // إنشاء الوكالة الجديدة
      final agencyRef = FirebaseFirestore.instance.collection('agencies').doc();
      final agencyData = {
        'id': agencyRef.id,
        'agentName': _agentNameController.text,
        'agentId': _agentIdController.text,
        'agencyNumber': _agencyNumberController.text,
        'agencyDate': _agencyDateController.text,
        'principalId': _principalIdController.text,
        'principalName': principalName,
        'principalPhone': principalPhone,
        'contractId': widget.contractId,
        'agencyType': 'توكيل عقد تحت الانشاء',
        'createdAt': FieldValue.serverTimestamp(),
        'usedIn': [widget.contractId],
        'lastUsed': FieldValue.serverTimestamp(),
      };

      // حفظ الوكالة
      await agencyRef.set(agencyData);

      // تحديث العقد بإضافة معرف الوكالة
      await FirebaseFirestore.instance
          .collection('contracts')
          .doc(widget.contractId)
          .update({
            'agencyId': agencyRef.id,
            'agentName': _agentNameController.text,
            'agentId': _agentIdController.text,
            'agencyNumber': _agencyNumberController.text,
            'agencyDate': _agencyDateController.text,
          });

      // تسجيل استخدام الوكالة
      await FirebaseFirestore.instance.collection('agencyUsages').add({
        'agencyId': agencyRef.id,
        'contractId': widget.contractId,
        'contractType': 'عقد تحت الانشاء',
        'usageDate': FieldValue.serverTimestamp(),
        'usageDetails': 'طباعة عقد تحت الانشاء',
        'usedBy': FirebaseAuth.instance.currentUser?.email,
      });

      setState(() {
        savedAgentName = _agentNameController.text;
        savedAgentId = _agentIdController.text;
        savedAgencyNumber = _agencyNumberController.text;
        savedAgencyDate = _agencyDateController.text;
        savedPrincipalName = principalName;
        savedPrincipalPhone = principalPhone;
        showAgencyFields = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حفظ واستخدام الوكالة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في حفظ الوكالة: $e')));
    }
  }

  // تعديل دالة _generateContract لتتحقق من وجود وكالة نشطة
  Future<Map<String, dynamic>?> _getActiveAgency() async {
    try {
      final agencySnapshot =
          await FirebaseFirestore.instance
              .collection('agencies')
              .where('contractId', isEqualTo: widget.contractId)
              .where('usedIn', arrayContains: widget.contractId)
              .get();

      if (agencySnapshot.docs.isEmpty) return null;

      // ترتيب الوكالات حسب آخر استخدام
      final sortedDocs =
          agencySnapshot.docs.toList()..sort((a, b) {
            final aTime = (a.data()['lastUsed'] as Timestamp).toDate();
            final bTime = (b.data()['lastUsed'] as Timestamp).toDate();
            return bTime.compareTo(aTime);
          });

      return sortedDocs.first.data();
    } catch (e) {
      print('Error fetching agency data: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _agentSearchController.dispose();
    _principalIdController.dispose();
    _agencyDateController.dispose();
    _agentNameController.dispose();
    _agentIdController.dispose();
    _agencyNumberController.dispose();
    super.dispose();
  }

  // UI للبحث وإضافة الوكالة
  Widget buildAgencyFormFields() {
    // تم تغيير اسم الدالة
    return Column(
      children: [
        // عرض الوكالات الحالية
        if (existingAgencies.isNotEmpty) ...[
          Text(
            'الوكالات الحالية للعميل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children:
                  existingAgencies.map((agency) {
                    bool isSelected = selectedAgency?['id'] == agency['id'];
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: Colors.blue.shade700,
                      ),
                      title: Text(agency['agentName'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رقم الوكالة: ${agency['agencyNumber']}\n'
                            'تاريخ: ${agency['agencyDate']}',
                          ),
                          if (agency['usedIn']?.isNotEmpty ?? false)
                            Text(
                              'استخدمت في ${(agency['usedIn'] as List).length} عقد/عقود',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      selected: isSelected,
                      selectedTileColor: Colors.blue.shade50,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedAgency = null;
                          } else {
                            selectedAgency = agency;
                            // تعبئة الحقول بالبيانات المحددة
                            _agentNameController.text =
                                agency['agentName'] ?? '';
                            _agentIdController.text = agency['agentId'] ?? '';
                            _agencyNumberController.text =
                                agency['agencyNumber'] ?? '';
                            _agencyDateController.text =
                                agency['agencyDate'] ?? '';
                          }
                        });
                      },
                    );
                  }).toList(),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'أو إضافة وكالة جديدة:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 10),
        ],

        // حقول إضافة الوكالة الجديدة كما هي
        TextField(
          controller: _agentNameController,
          decoration: InputDecoration(
            labelText: 'اسم الوكيل',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _agentIdController,
          decoration: InputDecoration(
            labelText: 'رقم هوية الوكيل',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _agencyNumberController,
          decoration: InputDecoration(
            labelText: 'رقم الوكالة',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _agencyDateController,
          decoration: InputDecoration(
            labelText: 'تاريخ الوكالة',
            border: OutlineInputBorder(),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              _agencyDateController.text = DateFormat(
                'yyyy-MM-dd',
              ).format(date);
            }
          },
          readOnly: true,
        ),
        SizedBox(height: 20),
        ElevatedButton(onPressed: saveAgency, child: Text('حفظ الوكالة')),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadContractData();
    _loadExistingAgencies(); // إضافة تحميل الوكالات الحالية
  }

  // دالة جديدة لتحميل الوكالات الحالية للزبون
  Future<void> _loadExistingAgencies() async {
    try {
      final contractDoc =
          await FirebaseFirestore.instance
              .collection('contracts')
              .doc(widget.contractId)
              .get();

      if (contractDoc.exists) {
        final clientId = contractDoc.data()?['identityNumber'];
        if (clientId != null) {
          final agenciesSnapshot =
              await FirebaseFirestore.instance
                  .collection('agencies')
                  .where('principalId', isEqualTo: clientId)
                  .get();

          setState(() {
            existingAgencies =
                agenciesSnapshot.docs
                    .map((doc) => {...doc.data(), 'id': doc.id})
                    .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading existing agencies: $e');
    }
  }

  // تعديل دالة buildAgencyFields لإضافة قائمة الوكالات الحالية
  Widget buildAgencyFields() {
    return Column(
      children: [
        // عرض الوكالات الحالية
        if (existingAgencies.isNotEmpty) ...[
          Text(
            'الوكالات الحالية للعميل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children:
                  existingAgencies.map((agency) {
                    bool isSelected = selectedAgency?['id'] == agency['id'];
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: Colors.blue.shade700,
                      ),
                      title: Text(agency['agentName'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رقم الوكالة: ${agency['agencyNumber']}\n'
                            'تاريخ: ${agency['agencyDate']}',
                          ),
                          if (agency['usedIn']?.isNotEmpty ?? false)
                            Text(
                              'استخدمت في ${(agency['usedIn'] as List).length} عقد/عقود',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      selected: isSelected,
                      selectedTileColor: Colors.blue.shade50,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedAgency = null;
                          } else {
                            selectedAgency = agency;
                            // تعبئة الحقول بالبيانات المحددة
                            _agentNameController.text =
                                agency['agentName'] ?? '';
                            _agentIdController.text = agency['agentId'] ?? '';
                            _agencyNumberController.text =
                                agency['agencyNumber'] ?? '';
                            _agencyDateController.text =
                                agency['agencyDate'] ?? '';
                          }
                        });
                      },
                    );
                  }).toList(),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'أو إضافة وكالة جديدة:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 10),
        ],

        // حقول إضافة الوكالة الجديدة كما هي
        TextField(
          controller: _agentNameController,
          decoration: InputDecoration(
            labelText: 'اسم الوكيل',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _agentIdController,
          decoration: InputDecoration(
            labelText: 'رقم هوية الوكيل',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _agencyNumberController,
          decoration: InputDecoration(
            labelText: 'رقم الوكالة',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _agencyDateController,
          decoration: InputDecoration(
            labelText: 'تاريخ الوكالة',
            border: OutlineInputBorder(),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              _agencyDateController.text = DateFormat(
                'yyyy-MM-dd',
              ).format(date);
            }
          },
          readOnly: true,
        ),
        SizedBox(height: 20),
        ElevatedButton(onPressed: saveAgency, child: Text('حفظ الوكالة')),
      ],
    );
  }

  Future<void> _loadContractData() async {
    try {
      final contractDoc =
          await FirebaseFirestore.instance
              .collection('contracts')
              .doc(widget.contractId)
              .get();

      if (contractDoc.exists) {
        final data = contractDoc.data()!;
        setState(() {
          contractData = data;
          // تحديث بيانات الموكل
          principalName = data['clientName'];
          principalPhone =
              data['phoneNumber'] ?? data['clientData']?['phoneNumber'];
          _principalIdController.text = data['identityNumber'] ?? '';

          // تحقق من وجود وكالة مرتبطة بالفعل
          if (data['agencyId'] != null) {
            _loadExistingAgencyData(data['agencyId']);
          }
        });
      }
    } catch (e) {
      print('Error loading contract data: $e');
    }
  }

  // إضافة دالة لتحميل بيانات الوكالة الحالية إذا وجدت
  Future<void> _loadExistingAgencyData(String agencyId) async {
    try {
      final agencyDoc =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(agencyId)
              .get();

      if (agencyDoc.exists) {
        final agencyData = agencyDoc.data()!;
        setState(() {
          savedAgentName = agencyData['agentName'];
          savedAgentId = agencyData['agentId'];
          savedAgencyNumber = agencyData['agencyNumber'];
          savedAgencyDate = agencyData['agencyDate'];
          savedPrincipalName = agencyData['principalName'];
          savedPrincipalPhone = agencyData['principalPhone'];
        });
      }
    } catch (e) {
      print('Error loading agency data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'طباعة العقد',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade900,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 10,
        shadowColor: Colors.blueAccent.withOpacity(0.5),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // صورة أو أيقونة توضيحية
                Image.asset(
                  'images/4.png', // تأكد من وجود هذه الصورة في مجلد assets
                  height: 150,
                  width: 150,
                ),
                SizedBox(height: 20),

                // زر "وكالة"
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      showAgencyFields = true;
                    });
                  },
                  icon: Icon(Icons.assignment_ind, color: Colors.white),
                  label: Text(
                    savedAgentName == null ? 'إضافة وكيل' : 'تعديل وكيل',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                ),
                SizedBox(height: 10),

                // ملخص بيانات الوكيل بعد الحفظ
                if (savedAgentName != null &&
                    savedAgentId != null &&
                    savedAgencyNumber != null)
                  Card(
                    margin: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    child: ListTile(
                      leading: Icon(Icons.assignment_ind, color: Colors.blue),
                      title: Text('اسم الوكيل: $savedAgentName'),
                      subtitle: Text(
                        'رقم الهوية: $savedAgentId\n'
                        'رقم الوكالة: $savedAgencyNumber\n'
                        'تاريخ الوكالة: $savedAgencyDate\n'
                        'اسم الموكل: ${savedPrincipalName ?? ""}\n'
                        'جوال الموكل: ${savedPrincipalPhone ?? ""}',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          setState(() {
                            showAgencyFields = true;
                          });
                        },
                      ),
                    ),
                  ),

                // واجهة إضافة وكيل (فقط إذا showAgencyFields = true)
                if (showAgencyFields)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30.0,
                      vertical: 10,
                    ),
                    child: buildAgencyFormFields(), // تحديث اسم الدالة هنا
                  ),

                // ... باقي الكود (زر الطباعة وغيره) ...
                SizedBox(height: 10),

                _isPrinting
                    ? Column(
                      children: [
                        SizedBox(height: 30),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade900.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade900,
                              ),
                              strokeWidth: 6,
                              backgroundColor: Colors.blue.shade100,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text(
                          'جاري طباعة العقد...',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'الرجاء الانتظار حتى انتهاء العملية',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    )
                    : Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.95, end: 1.05),
                          duration: Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                margin: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    setState(() => _isPrinting = true);
                                    try {
                                      await _generateContract();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تمت طباعة العقد بنجاح',
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => ContractsPage0(),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().contains(
                                                    'العقد غير موجود',
                                                  )
                                                  ? 'العقد غير موجود'
                                                  : 'حدث خطأ أثناء الطباعة: ${e.toString()}',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      setState(() => _isPrinting = false);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.blue.shade900,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.print,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'طباعة العقد',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 3,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'العودة للصفحة السابقة',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blue.shade800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
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
}
