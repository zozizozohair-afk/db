import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'approval_service.dart';

class EditDeleteHelper {
  final ApprovalService _approvalService = ApprovalService();
  final String _masterEmail = 'zizoalzohairy@gmail.com';

  // التحقق من صلاحية المستخدم للتعديل
  Future<bool> canEditItem(String userEmail) async {
    // فقط المستخدم المحدد يمكنه التعديل مباشرة
    return userEmail == _masterEmail;
  }

  // إنشاء طلب تعديل
  Future<void> createEditRequest({
    required BuildContext context,
    required String section,
    required String itemId,
    required String requesterName,
    required String requesterEmail,
    required String details,
    required Map<String, dynamic> newData,
  }) async {
    try {
      // التحقق من صلاحية المستخدم للتعديل المباشر
      final canEdit = await canEditItem(requesterEmail);

      if (canEdit) {
        // إذا كان المستخدم هو المستر، يمكنه التعديل مباشرة
        await FirebaseFirestore.instance
            .collection(section)
            .doc(itemId)
            .update(newData);

        // إضافة سجل في الـ logs
        await FirebaseFirestore.instance.collection('logs').add({
          'action': 'تعديل مباشر',
          'category': 'تعديل',
          'itemId': itemId,
          'details': details,
          'user': requesterEmail,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _showConfirmationMessage(context, 'تم التعديل بنجاح');
      } else {
        // إنشاء طلب موافقة للتعديل
        await _approvalService.createApprovalRequest(
          type: 'edit',
          section: section,
          itemId: itemId,
          requesterName: requesterName,
          requesterEmail: requesterEmail,
          details: details,
          newData: newData,
        );

        // إظهار رسالة تأكيد للمستخدم
        _showConfirmationMessage(context, 'تم إرسال طلب التعديل للموافقة');
      }
    } catch (e) {
      _showErrorMessage(context, e.toString());
    }
  }

  // التحقق من صلاحية المستخدم للحذف
  Future<bool> canDeleteItem(String userEmail) async {
    // فقط المستخدم المحدد يمكنه الحذف مباشرة
    return userEmail == _masterEmail;
  }

  // إنشاء طلب حذف
  Future<void> createDeleteRequest({
    required BuildContext context,
    required String section,
    required String itemId,
    required String requesterName,
    required String requesterEmail,
    required String details,
  }) async {
    try {
      // التحقق من صلاحية المستخدم للحذف المباشر
      final canDelete = await canDeleteItem(requesterEmail);

      if (canDelete) {
        // إذا كان المستخدم هو المستر، يمكنه الحذف مباشرة
        await FirebaseFirestore.instance
            .collection(section)
            .doc(itemId)
            .delete();

        // إضافة سجل في الـ logs
        await FirebaseFirestore.instance.collection('logs').add({
          'action': 'حذف مباشر',
          'category': 'حذف',
          'itemId': itemId,
          'details': details,
          'user': requesterEmail,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _showConfirmationMessage(context, 'تم الحذف بنجاح');
      } else {
        // إنشاء طلب موافقة للحذف
        await _approvalService.createApprovalRequest(
          type: 'delete',
          section: section,
          itemId: itemId,
          requesterName: requesterName,
          requesterEmail: requesterEmail,
          details: details,
        );

        // إظهار رسالة تأكيد للمستخدم
        _showConfirmationMessage(context, 'تم إرسال طلب الحذف للموافقة');
      }
    } catch (e) {
      _showErrorMessage(context, e.toString());
    }
  }

  // عرض حوار تأكيد قبل إنشاء طلب حذف
  Future<bool> showDeleteConfirmationDialog(
    BuildContext context,
    String itemName,
  ) async {
    // الحصول على بريد المستخدم الحالي
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? '';
    final isMaster = userEmail == _masterEmail;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red),
                  SizedBox(width: 10),
                  Text('تأكيد الحذف'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'هل أنت متأكد من رغبتك في حذف $itemName؟',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Text(
                    isMaster
                        ? 'سيتم حذف العنصر مباشرة.'
                        : 'سيتم إرسال طلب للمستر للموافقة على الحذف.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              actions: [
                TextButton(
                  child: Text('إلغاء'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text('تأكيد'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // عرض حوار تأكيد قبل إنشاء طلب تعديل
  Future<bool> showEditConfirmationDialog(
    BuildContext context,
    String itemName,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('تأكيد التعديل'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'هل أنت متأكد من رغبتك في تعديل $itemName؟',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'سيتم إرسال طلب للمستر للموافقة على التعديل.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text('تأكيد'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // عرض رسالة تأكيد للمستخدم
  void _showConfirmationMessage(BuildContext? context, String message) {
    if (context != null && context.mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blue.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        print('ℹ️ $message');
      }
    } else {
      print('ℹ️ $message');
    }
  }

  // عرض رسالة خطأ
  void _showErrorMessage(BuildContext? context, String error) {
    if (context != null && context.mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $error', textAlign: TextAlign.center),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
          ),
        );
      } else {
        print('❌ حدث خطأ: $error');
      }
    } else {
      print('❌ حدث خطأ: $error');
    }
  }
}
