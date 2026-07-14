import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ResaleContractService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addResaleContract(Map<String, dynamic> data) async {
    try {
      final clientSnapshot = await _firestore
          .collection('customers')
          .where('identityNumber', isEqualTo: data['identityNumber'])
          .limit(1)
          .get();

      final unitSnapshot = await _firestore
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

      // تحويل بيانات الوحدة إلى Map<String, dynamic> بشكل صريح
      final unitData = Map<String, dynamic>.from(unitSnapshot.docs.first.data());
      final unitRef = unitSnapshot.docs.first.reference;

      final pn = '${data['projectNumber']}-${data['unitNumber']}';
      data['pn'] = pn;

      final existingContractWithPn = await _firestore
          .collection('resale_contracts')
          .where('pn', isEqualTo: pn)
          .get();

      if (existingContractWithPn.docs.isNotEmpty) {
        throw 'رقم العقد $pn مستخدم مسبقًا';
      }

      if (clientSnapshot.docs.isNotEmpty) {
        // تحويل بيانات العميل إلى Map<String, dynamic> بشكل صريح
        final clientData = Map<String, dynamic>.from(clientSnapshot.docs.first.data());
        final clientRef = clientSnapshot.docs.first.reference;

        // نسخ بيانات العميل إلى خريطة جديدة لتجنب مشاكل التحويل
        final Map<String, dynamic> clientDataCopy = Map<String, dynamic>.from(clientData);
        data['clientData'] = clientDataCopy;
        data['clientName'] = clientData['name'];

        final customerDoc = await clientRef.get();

        final rawCustomerData = customerDoc.data();
        final customerData = rawCustomerData != null
            ? rawCustomerData.map((key, value) => MapEntry(key, value))
            : {};


        List<String> contractNumbers = [];
        if (customerData['contractNumbers'] is List) {
          contractNumbers = List<String>.from(customerData['contractNumbers']);
        }

        if (!contractNumbers.contains(pn)) {
          contractNumbers.add(pn);
        }

        await clientRef.update({'contractNumbers': contractNumbers});

        await unitRef.update({
          'status': 'معروضة للبيع',
          'totalAmount': data['totalAmount'],
          'tot': data['paidAmount'],
          'تاريخ عقد إعادة البيع': formattedDate,
          'clientName': clientData['name'],
          'clientIdentity': clientData['identityNumber'],
          'clientPhone': clientData['phone'],
        });

        if (data['totalAmount'] != null && data['totalAmount'] > 0) {
          await _firestore.collection('financialTransactions').add({
            'date': Timestamp.fromDate(now),
            'pn': pn,
            'customerName': clientData['name'],
            'amount': data['totalAmount'],
            'cod': '$pn${data['projectNumber']}' != '' ? '$pn${data['projectNumber']}' : '11111',
            'debitCredit': 'عليه',
            'idNumber': clientData['identityNumber'],
            'unitNumber': data['unitNumber'],
            'description': 'قيمة توقيع عقد إعادة البيع $pn',
            'projectNumber': data['projectNumber'],
            'transactionType': 'عقد إعادة بيع',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // إنشاء نسخة جديدة من البيانات لتجنب مشاكل التحويل
      final Map<String, dynamic> newData = <String, dynamic>{};
      
      // إضافة بيانات الوحدة والعقد
      newData['unitData'] = Map<String, dynamic>.from(unitData);
      newData['contractNumber'] = '';
      newData['status'] = 'اعادة بيع';
      newData['remainingAmount'] = (data['totalAmount'] ?? 0) - (data['paidAmount'] ?? 0);
      newData['dateGregorian'] = DateTime.now().toIso8601String();
      newData['dateHijri'] = DateFormat('dd-MM-yyyy').format(DateTime.now());
      newData['contractType'] = 'إعادة بيع';
      
      // نسخ البيانات الأصلية إلى الخريطة الجديدة
      data.forEach((key, value) {
        if (value != null && key != 'unitData') {
          newData[key] = value;
        }
      });
      
      // استبدال البيانات الأصلية بالنسخة الجديدة
      data = newData;

      data['deliveryDays'] ??= 0;
      data['deliveryMonths'] ??= 0;
      data['direction'] ??= unitData['direction'];
      data['unitNumber'] ??= unitData['number'];

      // تم بالفعل تحويل البيانات إلى Map<String, dynamic> في الخطوات السابقة
      // لذلك يمكننا إضافتها مباشرة إلى Firestore
      await _firestore.collection('resale_contracts').add(data);

      // تحديث حالة العقد الأصلي إلى "تم إعادة البيع"
      await _updateOriginalContractStatus(pn);
    } catch (e) {
      print('❌ خطأ أثناء إضافة عقد إعادة البيع: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getResaleContractById(String contractId) async {
    try {
      final doc = await _firestore.collection('resale_contracts').doc(contractId).get();
      if (doc.exists && doc.data() != null) {
        // تحويل البيانات إلى Map<String, dynamic> بشكل صريح
        return Map<String, dynamic>.from(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ خطأ أثناء جلب عقد إعادة البيع: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllResaleContracts() async {
    try {
      final snapshot = await _firestore.collection('resale_contracts').get();
      return snapshot.docs.map((doc) {
        // تحويل البيانات إلى Map<String, dynamic> بشكل صريح
        final data = Map<String, dynamic>.from(doc.data());
        // إضافة معرف المستند
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ خطأ أثناء جلب عقود إعادة البيع: $e');
      return [];
    }
  }

  Future<void> updateResaleContractStatus(String contractId, String newStatus) async {
    try {
      await _firestore.collection('resale_contracts').doc(contractId).update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ خطأ أثناء تحديث حالة عقد إعادة البيع: $e');
      rethrow;
    }
  }

  /// تحديث حالة العقد الأصلي إلى "تم إعادة البيع"
  Future<void> _updateOriginalContractStatus(String pn) async {
    try {
      // البحث عن العقد الأصلي باستخدام pn (بدون -R)
      final originalPn = pn;
      
      final originalContractQuery = await _firestore
          .collection('contracts')
          .where('pn', isEqualTo: originalPn)
          .limit(1)
          .get();

      if (originalContractQuery.docs.isNotEmpty) {
        final originalContractRef = originalContractQuery.docs.first.reference;
        await originalContractRef.update({
          'status': 'إعادة بيع',
          'resaleDate': FieldValue.serverTimestamp(),
        });
        print('✅ تم تحديث حالة العقد الأصلي إلى "تم إعادة البيع"');
      } else {
        print('⚠️ لم يتم العثور على العقد الأصلي برقم: $originalPn');
      }
    } catch (e) {
      print('❌ خطأ في تحديث حالة العقد الأصلي: $e');
      // لا نرمي الخطأ هنا لأن إضافة عقد إعادة البيع تمت بنجاح
      // نكتفي بطباعة الخطأ
    }
  }
}
