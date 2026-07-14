import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

Future<void> addNewContract(Map<String, dynamic> data) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    // جلب بيانات العميل
    final clientSnapshot =
        await firestore
            .collection('customers')
            .where('identityNumber', isEqualTo: data['identityNumber'])
            .limit(1)
            .get();

    // جلب بيانات الوحدة
    final unitSnapshot =
        await firestore
            .collection('apartments')
            .where('projectNumber', isEqualTo: data['projectNumber'])
            .where('number', isEqualTo: data['unitNumber'])
            .limit(1)
            .get();

    if (unitSnapshot.docs.isEmpty) {
      throw 'الوحدة غير موجودة';
    }

    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final unitData = unitSnapshot.docs.first.data();
    final unitRef = unitSnapshot.docs.first.reference;

    // التحقق من حالة الحجز
    if (unitData['status'] == 'محجوز') {
      // التحقق من أن العميل هو نفسه الذي حجز الشقة
      if (unitData['clientIdentity'] != null) {
        // مقارنة رقم الهوية مباشرة
        if (unitData['clientIdentity'] != data['identityNumber']) {
          throw 'هذه الشقة محجوزة للعميل ${unitData['clientName']} (رقم الهوية: ${unitData['clientIdentity']}). لا يمكن بيعها لعميل آخر.';
        }
      }
    }

    // إنشاء رقم العقد pn
    final pn = '${data['projectNumber']}-${data['unitNumber']}';
    data['pn'] = pn;

    // التحقق من عدم وجود عقد بنفس pn
    final existingContractWithPn =
        await firestore
            .collection('contracts')
            .where('pn', isEqualTo: pn)
            .get();

    if (existingContractWithPn.docs.isNotEmpty) {
      throw 'رقم العقد $pn مستخدم مسبقًا';
    }

    if (clientSnapshot.docs.isNotEmpty) {
      final clientData = clientSnapshot.docs.first.data();
      final clientRef = clientSnapshot.docs.first.reference;

      data['clientData'] = clientData;
      data['clientName'] = clientData['name'];

      // تحديث عقد العميل
      final customerDoc = await clientRef.get();
      final customerData = customerDoc.data() as Map<String, dynamic>;

      List<String> contractNumbers = [];
      if (customerData.containsKey('contractNumbers') &&
          customerData['contractNumbers'] is List) {
        contractNumbers = List<String>.from(customerData['contractNumbers']);
      }

      if (!contractNumbers.contains(pn)) {
        contractNumbers.add(pn);
      }

      await clientRef.update({'contractNumbers': contractNumbers});

      // تحديث بيانات الوحدة
      await unitRef.update({
        'status': 'مباع',
        'totalAmount': data['totalAmount'],
        'tot': data['paidAmount'],
        'تاريخ العقد تحت الانشاء': formattedDate,
        'clientName': clientData['name'],
        'clientIdentity': clientData['identityNumber'],
        'clientPhone': clientData['phone'],
      });

      // تسجيل العملية المالية
      if (data['totalAmount'] != null && data['totalAmount'] > 0) {
        await firestore.collection('financialTransactions').add({
          'date': Timestamp.fromDate(now),
          'pn': pn,
          'customerName': clientData['name'],
          'amount': data['totalAmount'],
          'cod':
              '$pn${data['projectNumber']}' != ''
                  ? '$pn${data['projectNumber']}'
                  : '11111',
          'debitCredit': 'عليه',
          'idNumber': clientData['identityNumber'],
          'unitNumber': data['unitNumber'],
          'description': 'قيمة توقيع العقد  $pn',
          'projectNumber': data['projectNumber'],
          'transactionType': 'عقد بيع',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // إعداد بيانات العقد
    data.addAll({
      'unitData': unitData,
      'contractNumber': '', // حقل اختياري فارغ حالياً
      'status': 'تحت الإنشاء', // الحالة الابتدائية
      'remainingAmount': (data['totalAmount'] ?? 0) - (data['paidAmount'] ?? 0),
      'dateGregorian': DateTime.now().toIso8601String(),
      'dateHijri': DateFormat('dd-MM-yyyy').format(DateTime.now()),
    });

    // التأكد من إضافة الحقول المطلوبة
    if (!data.containsKey('deliveryDays')) data['deliveryDays'] = 0;
    if (!data.containsKey('deliveryMonths')) data['deliveryMonths'] = 0;
    if (!data.containsKey('direction'))
      data['direction'] = unitData['direction'];
    if (!data.containsKey('unitNumber'))
      data['unitNumber'] = data['unitNumber'] ?? unitData['number'];

    // حفظ العقد
    await firestore.collection('contracts').add(data);
  } catch (e) {
    print('❌ خطأ أثناء إضافة العقد: $e');
    rethrow;
  }
}
