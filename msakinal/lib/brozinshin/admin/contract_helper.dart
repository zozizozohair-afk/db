import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../class/approval_service.dart';

class ContractHelper {
  final ApprovalService _approvalService = ApprovalService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // التحقق من وجود عقود مكررة وإنشاء طلب موافقة إذا لزم الأمر
  Future<bool> checkAndHandleDuplicateContract({
    required BuildContext context,
    required String apartmentId,
    required Map<String, dynamic> contractData,
    required String requesterName,
    required String requesterEmail,
  }) async {
    try {
      // التحقق من وجود عقود مكررة
      final bool hasDuplicateContract = await _approvalService.checkDuplicateContract(apartmentId);

      if (hasDuplicateContract) {
        // إظهار رسالة للمستخدم
        final bool shouldProceed = await _showDuplicateContractDialog(context);

        if (shouldProceed) {
          // إنشاء طلب موافقة
          await _approvalService.createApprovalRequest(
            type: 'duplicate_contract',
            section: 'contracts',
            itemId: apartmentId,
            requesterName: requesterName,
            requesterEmail: requesterEmail,
            details: 'طلب إضافة عقد مكرر للشقة رقم $apartmentId',
            additionalData: {'contractData': contractData},
          );

          // إظهار رسالة تأكيد للمستخدم
          _showConfirmationMessage(context);
          return false; // لا تقم بإضافة العقد مباشرة، انتظر الموافقة
        } else {
          return false; // المستخدم ألغى العملية
        }
      }

      return true; // لا يوجد عقود مكررة، يمكن المتابعة
    } catch (e) {
      // إظهار رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // عرض رسالة تأكيد للمستخدم
  void _showConfirmationMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم إرسال طلبك للموافقة. سيتم إعلامك عند مراجعته.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // عرض رسالة تنبيه بوجود عقد مكرر
  Future<bool> _showDuplicateContractDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 10),
                  Text('تنبيه: عقد مكرر'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'يوجد بالفعل عقد تحت الإنشاء لهذه الشقة.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'هل تريد إرسال طلب للمستر للموافقة على إضافة عقد آخر؟',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              actions: [
                TextButton(
                  child: Text('إلغاء'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text('إرسال للموافقة'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // إنشاء طلب موافقة للتعديل أو الحذف
  Future<void> createEditOrDeleteRequest({
    required BuildContext context,
    required String type, // 'edit' أو 'delete'
    required String section,
    required String itemId,
    required String requesterName,
    required String requesterEmail,
    required String details,
    Map<String, dynamic>? newData,
  }) async {
    try {
      await _approvalService.createApprovalRequest(
        type: type,
        section: section,
        itemId: itemId,
        requesterName: requesterName,
        requesterEmail: requesterEmail,
        details: details,
        newData: newData,
      );

      // إظهار رسالة تأكيد للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال طلب ${type == 'edit' ? 'التعديل' : 'الحذف'} للموافقة',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // إظهار رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}