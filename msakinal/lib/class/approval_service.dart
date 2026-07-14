import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'contract_delete_helper.dart';

class ApprovalService {
  // دالة لإرسال إشعار للمستخدم الذي قدم الطلب
  Future<void> _sendNotificationToRequester(
    String requesterEmail,
    String title,
    String body,
  ) async {
    try {
      // البحث عن المستخدم بواسطة البريد الإلكتروني
      final usersQuery =
          await _firestore
              .collection('users')
              .where('name', isEqualTo: requesterEmail)
              .limit(1)
              .get();

      if (usersQuery.docs.isNotEmpty) {
        final userData = usersQuery.docs.first.data();
        final fcmToken = userData['fcmToken'];

        if (fcmToken != null) {
          // إضافة الإشعار إلى مجموعة الإشعارات
          await _firestore.collection('notifications').add({
            'userId': usersQuery.docs.first.id,
            'title': title,
            'body': body,
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });

          print('تم إرسال إشعار إلى المستخدم: $requesterEmail');
        }
      }
    } catch (e) {
      print('خطأ في إرسال الإشعار: $e');
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _masterEmail = 'zizoalzohairy@gmail.com';

  // إنشاء طلب موافقة جديد
  Future<void> createApprovalRequest({
    required String type, // 'edit', 'delete', 'duplicate_contract'
    required String
    section, // اسم المجموعة في فايربيس (مثل 'apartments', 'contracts')
    required String itemId, // معرف العنصر
    required String requesterName, // اسم مقدم الطلب
    required String requesterEmail, // بريد مقدم الطلب
    required String details, // تفاصيل الطلب
    Map<String, dynamic>? newData, // البيانات الجديدة في حالة التعديل
    Map<String, dynamic>? additionalData, // بيانات إضافية
  }) async {
    try {
      await _firestore.collection('approval_requests').add({
        'type': type,
        'section': section,
        'itemId': itemId,
        'requesterName': requesterName,
        'requesterEmail': requesterEmail,
        'details': details,
        'status': 'pending', // 'pending', 'approved', 'rejected'
        'timestamp': FieldValue.serverTimestamp(),
        'newData': newData,
        'additionalData': additionalData,
      });

      // إضافة سجل في الـ logs
      await _firestore.collection('logs').add({
        'action': 'إنشاء طلب موافقة',
        'category': _getRequestTypeArabic(type),
        'itemId': itemId,
        'details': 'تم إنشاء طلب $details',
        'user': requesterEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // التحقق من وجود عقود مكررة لنفس الشقة
  Future<bool> checkDuplicateContract(String apartmentId) async {
    try {
      final QuerySnapshot contractsSnapshot =
          await _firestore
              .collection('contracts')
              .where('apartmentId', isEqualTo: apartmentId)
              .where('status', isEqualTo: 'تحت الإنشاء')
              .get();

      return contractsSnapshot.docs.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  // التحقق من أن المستخدم هو المستر المصرح له
  bool isMasterUser(String email, String userType) {
    return email == _masterEmail && userType == 'مستر';
  }

  // تنفيذ طلب الحذف المعتمد
  Future<bool> executeDeleteRequest(
    String requestId,
    String approverEmail,
  ) async {
    try {
      // التحقق من أن المستخدم المصرح له هو من يقوم بالموافقة
      if (approverEmail != _masterEmail) {
        throw 'غير مصرح لك بتنفيذ هذا الإجراء';
      }

      // جلب بيانات الطلب
      final requestDoc =
          await _firestore.collection('approval_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        return false;
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      if (requestData['status'] != 'approved') {
        throw 'لم تتم الموافقة على الطلب بعد';
      }

      final section = requestData['section'] as String;
      final itemId = requestData['itemId'] as String;
      final requesterEmail = requestData['requesterEmail'] as String;

      // التعامل مع حذف العقود بشكل خاص
      if (section == 'contracts') {
        try {
          // جلب وثيقة العقد أولاً للحصول على رقم العقد (pn)
          final contractDoc =
              await _firestore.collection('contracts').doc(itemId).get();

          if (!contractDoc.exists) {
            throw 'العقد غير موجود';
          }

          final contractData = contractDoc.data() as Map<String, dynamic>;
          final pn = contractData['pn'];

          if (pn == null || pn.toString().isEmpty) {
            throw 'رقم العقد غير موجود في بيانات الوثيقة';
          }

          print('بدء حذف العقد برقم: $pn');

          // استخدام ContractDeleteHelper لحذف العقد وتنظيف البيانات المرتبطة
          final contractDeleteHelper = ContractDeleteHelper();
          final result = await contractDeleteHelper.deleteContract(
            itemId,
            null,
          );

          if (result) {
            // تحديث حالة الطلب
            await _firestore
                .collection('approval_requests')
                .doc(requestId)
                .update({
                  'status': 'executed',
                  'executionTimestamp': FieldValue.serverTimestamp(),
                  'executedBy': approverEmail,
                });

            // إرسال إشعار للمستخدم الذي قدم الطلب
            await _sendNotificationToRequester(
              requesterEmail,
              'تم تنفيذ طلب الحذف',
              'تم تنفيذ طلب حذف العقد بنجاح',
            );
          }

          return result;
        } catch (e) {
          print('خطأ في حذف العقد: $e');
          rethrow;
        }
      }
      // التعامل مع حذف عقود إعادة البيع
      else if (section == 'resale_contracts') {
        try {
          // جلب رقم العقد (pn) من وثيقة عقد إعادة البيع
          final resaleDoc =
              await _firestore.collection('resale_contracts').doc(itemId).get();
          if (!resaleDoc.exists) {
            throw 'عقد إعادة البيع غير موجود';
          }

          final resaleData = resaleDoc.data() as Map<String, dynamic>;
          final pn = resaleData['pn'] as String?;

          if (pn == null || pn.isEmpty) {
            throw 'رقم العقد غير موجود في بيانات عقد إعادة البيع';
          }

          print('بدء حذف عقد إعادة البيع برقم: $pn');

          // استخدام ContractDeleteHelper لحذف عقد إعادة البيع وتنظيف البيانات المرتبطة
          final contractDeleteHelper = ContractDeleteHelper();
          final result = await contractDeleteHelper.deleteResaleContractByPn(
            pn,
            null,
          );

          if (result) {
            // تحديث حالة الطلب
            await _firestore
                .collection('approval_requests')
                .doc(requestId)
                .update({
                  'status': 'executed',
                  'executionTimestamp': FieldValue.serverTimestamp(),
                  'executedBy': approverEmail,
                });

            // إرسال إشعار للمستخدم الذي قدم الطلب
            await _sendNotificationToRequester(
              requesterEmail,
              'تم تنفيذ طلب الحذف',
              'تم تنفيذ طلب حذف عقد إعادة البيع بنجاح',
            );
          }

          return result;
        } catch (e) {
          print('خطأ في حذف عقد إعادة البيع: $e');
          rethrow;
        }
      }
      // التعامل مع حذف التسويات المالية
      else if (section == 'financial_settlements') {
        try {
          // جلب بيانات التسوية المالية أولاً للحصول على رقم العقد (pn)
          final settlementDoc =
              await _firestore
                  .collection('financial_settlements')
                  .doc(itemId)
                  .get();
          if (!settlementDoc.exists) {
            throw 'التسوية المالية غير موجودة';
          }

          final settlementData = settlementDoc.data() as Map<String, dynamic>;
          final pn = settlementData['pn'] as String?;

          if (pn == null || pn.isEmpty) {
            throw 'رقم العقد غير موجود في بيانات التسوية المالية';
          }

          print('بدء حذف التسوية المالية برقم العقد: $pn');

          // استخدام ContractDeleteHelper لحذف التسوية المالية وتنظيف البيانات المرتبطة
          final contractDeleteHelper = ContractDeleteHelper();
          final result = await contractDeleteHelper.deleteFinancialSettlement(
            itemId,
            null,
          );

          if (result) {
            // تحديث حالة الطلب
            await _firestore
                .collection('approval_requests')
                .doc(requestId)
                .update({
                  'status': 'executed',
                  'executionTimestamp': FieldValue.serverTimestamp(),
                  'executedBy': approverEmail,
                });

            // إرسال إشعار للمستخدم الذي قدم الطلب
            await _sendNotificationToRequester(
              requesterEmail,
              'تم تنفيذ طلب الحذف',
              'تم تنفيذ طلب حذف التسوية المالية بنجاح',
            );
          }

          return result;
        } catch (e) {
          print('خطأ في حذف التسوية المالية: $e');
          rethrow;
        }
      }
      // التعامل مع حذف عقود الإفراغ
      else if (section == 'emptying_contracts') {
        try {
          // جلب بيانات عقد الإفراغ أولاً للحصول على رقم العقد (pn)
          final emptyingDoc =
              await _firestore
                  .collection('emptying_contracts')
                  .doc(itemId)
                  .get();
          if (!emptyingDoc.exists) {
            throw 'عقد الإفراغ غير موجود';
          }

          final emptyingData = emptyingDoc.data() as Map<String, dynamic>;
          final pn = emptyingData['pn'] as String?;

          if (pn == null || pn.isEmpty) {
            throw 'رقم العقد غير موجود في بيانات عقد الإفراغ';
          }

          print('بدء حذف عقد الإفراغ برقم العقد: $pn');

          // استخدام ContractDeleteHelper لحذف عقد الإفراغ وتنظيف البيانات المرتبطة
          final contractDeleteHelper = ContractDeleteHelper();
          final result = await contractDeleteHelper.deleteEmptyingContract(
            itemId,
            null,
          );

          if (result) {
            // تحديث حالة الطلب
            await _firestore
                .collection('approval_requests')
                .doc(requestId)
                .update({
                  'status': 'executed',
                  'executionTimestamp': FieldValue.serverTimestamp(),
                  'executedBy': approverEmail,
                });

            // إرسال إشعار للمستخدم الذي قدم الطلب
            await _sendNotificationToRequester(
              requesterEmail,
              'تم تنفيذ طلب الحذف',
              'تم تنفيذ طلب حذف عقد الإفراغ بنجاح',
            );
          }

          return result;
        } catch (e) {
          print('خطأ في حذف عقد الإفراغ: $e');
          rethrow;
        }
      }
      // التعامل مع حذف محاضر الاستلام
      else if (section == 'astlam') {
        try {
          // جلب بيانات محضر الاستلام أولاً للحصول على معلومات إضافية
          final astlamDoc =
              await _firestore.collection(section).doc(itemId).get();
          if (!astlamDoc.exists) {
            throw 'محضر الاستلام غير موجود';
          }

          final astlamData = astlamDoc.data() as Map<String, dynamic>;
          final pn = astlamData['pn'] as String?;
          final unitNumber = astlamData['unitNumber'] as String?;

          print(
            'بدء حذف محضر الاستلام للوحدة: ${unitNumber ?? 'غير معروف'} برقم العقد: ${pn ?? 'غير معروف'}',
          );

          // حذف محضر الاستلام
          await _firestore.collection(section).doc(itemId).delete();

          // تحديث حالة الطلب
          await _firestore
              .collection('approval_requests')
              .doc(requestId)
              .update({
                'status': 'executed',
                'executionTimestamp': FieldValue.serverTimestamp(),
                'executedBy': approverEmail,
              });

          // إرسال إشعار للمستخدم الذي قدم الطلب
          await _sendNotificationToRequester(
            requesterEmail,
            'تم تنفيذ طلب الحذف',
            'تم تنفيذ طلب حذف محضر استلام بنجاح',
          );

          // إضافة سجل في الـ logs
          await _firestore.collection('logs').add({
            'action': 'تنفيذ طلب حذف محضر استلام',
            'category': 'حذف',
            'itemId': itemId,
            'details':
                'تم تنفيذ طلب حذف محضر استلام للوحدة: ${unitNumber ?? 'غير معروف'} برقم العقد: ${pn ?? 'غير معروف'}',
            'user': approverEmail,
            'timestamp': FieldValue.serverTimestamp(),
          });

          return true;
        } catch (e) {
          print('خطأ في حذف محضر الاستلام: $e');
          rethrow;
        }
      }

      // التعامل مع باقي أنواع الحذف
      // تنفيذ عملية الحذف
      await _firestore.collection(section).doc(itemId).delete();

      // تحديث حالة الطلب
      await _firestore.collection('approval_requests').doc(requestId).update({
        'status': 'executed',
        'executionTimestamp': FieldValue.serverTimestamp(),
        'executedBy': approverEmail,
      });

      // إرسال إشعار للمستخدم الذي قدم الطلب
      await _sendNotificationToRequester(
        requesterEmail,
        'تم تنفيذ طلب الحذف',
        'تم تنفيذ طلب الحذف بنجاح',
      );

      // إضافة سجل في الـ logs
      await _firestore.collection('logs').add({
        'action': 'تنفيذ طلب حذف',
        'category': 'حذف',
        'itemId': itemId,
        'details': 'تم تنفيذ طلب حذف في قسم $section',
        'user': approverEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('خطأ في تنفيذ طلب الحذف: $e');
      rethrow;
    }
  }

  // تنفيذ طلب التعديل المعتمد
  Future<bool> executeEditRequest(
    String requestId,
    String approverEmail,
  ) async {
    try {
      // التحقق من أن المستخدم المصرح له هو من يقوم بالموافقة
      if (approverEmail != _masterEmail) {
        throw 'غير مصرح لك بتنفيذ هذا الإجراء';
      }

      // جلب بيانات الطلب
      final requestDoc =
          await _firestore.collection('approval_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw 'الطلب غير موجود';
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      if (requestData['status'] != 'approved') {
        throw 'لم تتم الموافقة على الطلب بعد';
      }

      final section = requestData['section'] as String;
      final itemId = requestData['itemId'] as String;
      final newData = requestData['newData'] as Map<String, dynamic>?;

      if (newData == null) {
        throw 'بيانات التعديل غير موجودة';
      }

      // جلب البيانات الحالية للعنصر قبل التعديل
      final currentDoc = await _firestore.collection(section).doc(itemId).get();
      if (!currentDoc.exists) {
        throw 'العنصر المراد تعديله غير موجود';
      }

      final currentData = currentDoc.data() as Map<String, dynamic>;

      // تنفيذ عملية التعديل
      await _firestore.collection(section).doc(itemId).update(newData);

      // إذا كان التعديل في قسم العقود وتم تعديل المبالغ، نقوم بتحديث جدول العمليات المالية
      if (section == 'contracts' && newData.containsKey('paidAmount')) {
        final double originalPaidAmount = currentData['paidAmount'] ?? 0;
        final double newPaidAmount = newData['paidAmount'] ?? 0;

        if (newPaidAmount != originalPaidAmount) {
          // إضافة سجل في جدول العمليات المالية يوضح التعديل
          await _firestore.collection('financial_transactions').add({
            'contractId': itemId,
            'contractNumber': currentData['pn'] ?? '',
            'clientName': currentData['clientName'] ?? '',
            'type': 'تعديل',
            'amount': newPaidAmount - originalPaidAmount, // الفرق بين المبلغين
            'notes':
                'تعديل المبلغ المدفوع من $originalPaidAmount إلى $newPaidAmount',
            'timestamp': FieldValue.serverTimestamp(),
            'userId': approverEmail,
          });
        }
      }

      // تحديث حالة الطلب
      await _firestore.collection('approval_requests').doc(requestId).update({
        'status': 'executed',
        'executionTimestamp': FieldValue.serverTimestamp(),
        'executedBy': approverEmail,
      });

      // إضافة سجل في الـ logs
      await _firestore.collection('logs').add({
        'action': 'تنفيذ طلب تعديل',
        'category': 'تعديل',
        'itemId': itemId,
        'details': 'تم تنفيذ طلب تعديل في قسم $section',
        'user': approverEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('خطأ في تنفيذ طلب التعديل: $e');
      rethrow;
    }
  }

  // الموافقة على طلب
  Future<bool> approveRequest(String requestId, String approverEmail) async {
    try {
      // التحقق من أن المستخدم المصرح له هو من يقوم بالموافقة
      if (approverEmail != _masterEmail) {
        throw 'غير مصرح لك بالموافقة على الطلبات';
      }

      // الحصول على معلومات الطلب قبل التحديث
      final requestDoc =
          await _firestore.collection('approval_requests').doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final requesterEmail = requestData['requesterEmail'];

      await _firestore.collection('approval_requests').doc(requestId).update({
        'status': 'approved',
        'approvalTimestamp': FieldValue.serverTimestamp(),
        'approvedBy': approverEmail,
      });

      // إرسال إشعار للمستخدم الذي قدم الطلب
      await _sendNotificationToRequester(
        requesterEmail,
        'تمت الموافقة على طلبك',
        'تمت الموافقة على طلبك بنجاح',
      );

      // إضافة سجل في الـ logs
      // استخدام البيانات التي تم الحصول عليها مسبقًا بدلاً من إعادة جلبها

      await _firestore.collection('logs').add({
        'action': 'الموافقة على طلب',
        'category': _getRequestTypeArabic(requestData['type']),
        'itemId': requestData['itemId'],
        'details': 'تمت الموافقة على طلب ${requestData['details']}',
        'user': approverEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('خطأ في الموافقة على الطلب: $e');
      rethrow;
    }
  }

  // رفض طلب
  Future<bool> rejectRequest(
    String requestId,
    String approverEmail,
    String reason,
  ) async {
    try {
      // التحقق من أن المستخدم المصرح له هو من يقوم بالرفض
      if (approverEmail != _masterEmail) {
        throw 'غير مصرح لك برفض الطلبات';
      }

      // الحصول على معلومات الطلب قبل التحديث
      final requestDoc =
          await _firestore.collection('approval_requests').doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final requesterEmail = requestData['requesterEmail'];

      await _firestore.collection('approval_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectionTimestamp': FieldValue.serverTimestamp(),
        'rejectedBy': approverEmail,
        'rejectionReason': reason,
      });

      // إرسال إشعار للمستخدم الذي قدم الطلب
      await _sendNotificationToRequester(
        requesterEmail,
        'تم رفض طلبك',
        'تم رفض طلبك: $reason',
      );

      // استخدام البيانات التي تم الحصول عليها مسبقًا بدلاً من إعادة جلبها

      await _firestore.collection('logs').add({
        'action': 'رفض طلب',
        'category': _getRequestTypeArabic(requestData['type']),
        'itemId': requestData['itemId'],
        'details': 'تم رفض طلب ${requestData['details']} بسبب: $reason',
        'user': approverEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('خطأ في رفض الطلب: $e');
      rethrow;
    }
  }

  // الحصول على الترجمة العربية لنوع الطلب
  String _getRequestTypeArabic(String type) {
    switch (type) {
      case 'edit':
        return 'تعديل';
      case 'delete':
        return 'حذف';
      case 'duplicate_contract':
        return 'عقد مكرر';
      default:
        return 'غير معروف';
    }
  }
}
