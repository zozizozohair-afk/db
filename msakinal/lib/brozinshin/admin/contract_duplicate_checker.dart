import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../class/approval_service.dart';

class ContractDuplicateChecker {
  final ApprovalService _approvalService = ApprovalService();

  // التحقق من وجود عقود مكررة للشقة
  Future<bool> checkForDuplicateContract(String apartmentId) async {
    try {
      return await _approvalService.checkDuplicateContract(apartmentId);
    } catch (e) {
      print('خطأ في التحقق من العقود المكررة: $e');
      return false;
    }
  }

  // عرض حوار التأكيد عند وجود عقد مكرر
  Future<bool> showDuplicateContractDialog(BuildContext context, String apartmentId) async {
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
                    'يوجد بالفعل عقد تحت الإنشاء لهذه الشقة رقم $apartmentId.',
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

  // إنشاء طلب موافقة لإضافة عقد مكرر
  Future<void> createDuplicateContractRequest({
    required BuildContext context,
    required String apartmentId,
    required Map<String, dynamic> contractData,
    required String requesterName,
    required String requesterEmail,
  }) async {
    try {
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