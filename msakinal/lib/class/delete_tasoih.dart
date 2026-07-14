import 'package:cloud_firestore/cloud_firestore.dart';

/// دالة حذف أو التراجع عن التسوية المالية مع التعامل مع أرقام العقود بالحرف t
/// ملاحظة: يجب تمرير رقم الشقة مضاف له الحرف t مثلاً: "123t"
Future<void> undoFinancialSettlementForUnit(String unitPnWithT) async {
  final firestore = FirebaseFirestore.instance;

  // إزالة الحرف t للحصول على رقم الوحدة الأصلي
  final String unitPn = unitPnWithT.endsWith('t') 
      ? unitPnWithT.substring(0, unitPnWithT.length - 1) 
      : unitPnWithT;
  final String unitPnWithTSuffix = '${unitPn}t';
  // 1. جلب الوحدة
  final unitSnapshot =
      await firestore
          .collection('apartments')
          .where('pn', isEqualTo: unitPn)
          .limit(1)
          .get();

  if (unitSnapshot.docs.isEmpty) {
    throw Exception('لم يتم العثور على الوحدة');
  }
  final unitDoc = unitSnapshot.docs.first;
  final unitData = unitDoc.data();
  final unitDocId = unitDoc.id;

  // 2. جلب العقد المرتبط بالوحدة بناءً على pn
  final contractSnapshot =
      await firestore
          .collection('contracts')
          .where('pn', isEqualTo: unitPn)
          .limit(1)
          .get();

  if (contractSnapshot.docs.isEmpty) {
    throw Exception('لم يتم العثور على العقد');
  }
  final contractDoc = contractSnapshot.docs.first;
  final contractData = contractDoc.data();
  final contractDocId = contractDoc.id;

  // 3. جلب سجل التسوية المالية المرتبط بالوحدة (إن وجد)
  final settlementSnapshot =
      await firestore
          .collection('financialSettlements')
          .where('newContractNumber', isEqualTo: unitPn)
          .limit(1)
          .get();

  // 4. جلب بيانات العميل القديم من بيانات العقد الأصلي
  final oldClientData = contractData['clientData'] as Map<String, dynamic>?;
  final oldClientName = contractData['clientName'];
  final oldClientIdentity = oldClientData?['identityNumber'];
  final oldClientPhone = oldClientData?['phoneNumber'];

  if (oldClientName == null || oldClientIdentity == null) {
    throw Exception('بيانات العميل الأصلي غير مكتملة في العقد');
  }

  // 5. جلب بيانات العميل الجديد (من التسوية المالية)
  String? newClientIdentity;
  if (settlementSnapshot.docs.isNotEmpty) {
    final settlementData = settlementSnapshot.docs.first.data();
    newClientIdentity = settlementData['newCustomerId'];
  } else {
    // إذا لم يوجد سجل تسوية مالية، نكتفي بإرجاع بيانات الوحدة والعقد فقط
    newClientIdentity = unitData['clientIdentity'];
  }

  // 6. جلب العميل الجديد من جدول العملاء (إذا كان موجودًا)
  DocumentSnapshot<Map<String, dynamic>>? newClientDoc;
  if (newClientIdentity != null) {
    final newClientSnapshot =
        await firestore
            .collection('customers')
            .where('identityNumber', isEqualTo: newClientIdentity)
            .limit(1)
            .get();
    if (newClientSnapshot.docs.isNotEmpty) {
      newClientDoc = newClientSnapshot.docs.first;
    }
  }

  // 7. جلب العميل القديم من جدول العملاء
  DocumentSnapshot<Map<String, dynamic>>? oldClientDoc;
  final oldClientSnapshot =
      await firestore
          .collection('customers')
          .where('identityNumber', isEqualTo: oldClientIdentity)
          .limit(1)
          .get();
  if (oldClientSnapshot.docs.isNotEmpty) {
    oldClientDoc = oldClientSnapshot.docs.first;
  }

  // 8. حذف رقم العقد مع t من العميل الجديد (إن وجد)
  if (newClientDoc != null) {
    final newClientContracts =
        (newClientDoc.data()?['contractNumbers'] as List?)?.cast<String>() ??
        [];
    if (newClientContracts.contains(unitPnWithT)) {
      newClientContracts.remove(unitPnWithT);
      await firestore.collection('customers').doc(newClientDoc.id).update({
        'contractNumbers': newClientContracts,
      });
    }
  }

  // 9. حذف رقم العقد مع t من العميل القديم (إن وجد)
  if (oldClientDoc != null) {
    final oldClientContracts =
        (oldClientDoc.data()?['contractNumbers'] as List?)?.cast<String>() ??
        [];
    if (oldClientContracts.contains(unitPnWithTSuffix)) {
      oldClientContracts.remove(unitPnWithTSuffix);
      await firestore.collection('customers').doc(oldClientDoc.id).update({
        'contractNumbers': oldClientContracts,
      });
    }
  }

  // 10. إعادة بيانات الوحدة إلى العميل القديم
  await firestore.collection('apartments').doc(unitDocId).update({
    'clientName': oldClientName,
    'clientIdentity': oldClientIdentity,
    'status': 'معروضة للبيع',
    'clientPhone': oldClientPhone,
  });

  // 11. إعادة العقد إلى حالته الأصلية وتحديث العميل
  await firestore.collection('contracts').doc(contractDocId).update({
    'clientName': oldClientName,
    'clientData': oldClientData,
    'status': 'إعادة بيع',
    'settlementContractNumber': FieldValue.delete(),
  });

  // 12. حذف سجل التسوية المالية (إن وجد)
}
