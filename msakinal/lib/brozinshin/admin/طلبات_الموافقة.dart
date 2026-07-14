import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:msakinal/priovider/auth_provider.dart';

import '../../class/approval_service.dart';
import '../../class/contract_delete_helper.dart';

class ApprovalRequestsPage extends StatefulWidget {
  final String currentUserEmail;
  final String userType;

  const ApprovalRequestsPage({
    super.key,
    required this.currentUserEmail,
    required this.userType,
  });

  @override
  _ApprovalRequestsPageState createState() => _ApprovalRequestsPageState();
}

class _ApprovalRequestsPageState extends State<ApprovalRequestsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthorization();
  }

  void _checkAuthorization() {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

    // جلب نوع المستخدم بشكل مباشر من مزود المصادقة (افترض أن لديه خاصية userType)
    String? currentUserType = authProvider.userType;

    if (currentUserType == 'مستر') {
      setState(() {
        _isAuthorized = true;
      });
    } else {
      setState(() {
        _isAuthorized = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('طلبات الموافقة'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.red.shade700, Colors.red.shade900],
              ),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security, size: 80, color: Colors.red.shade300),
              SizedBox(height: 20),
              Text(
                'غير مصرح لك بالوصول',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'هذه الصفحة مخصصة للمستر فقط',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          '🔐 طلبات الموافقة',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.purple.shade800, Colors.deepPurple.shade600],
            ),
          ),
        ),
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'طلبات التعديل', icon: Icon(Icons.edit)),
            Tab(text: 'طلبات الحذف', icon: Icon(Icons.delete)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRequestsList('edit'), _buildRequestsList('delete')],
      ),
    );
  }

  Widget _buildRequestsList(String requestType) {
    // استخدام Future بدلاً من Stream لتجنب مشكلة اختفاء البيانات
    return FutureBuilder<QuerySnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('approval_requests')
              .where('type', isEqualTo: requestType)
              .where('status', isEqualTo: 'pending')
              .orderBy('timestamp', descending: true)
              .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade300),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  requestType == 'edit' ? Icons.edit_off : Icons.delete_forever,
                  size: 70,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 20),
                Text(
                  'لا توجد طلبات ${requestType == 'edit' ? 'تعديل' : 'حذف'} حالياً',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data() as Map<String, dynamic>;
            final requestId = requests[index].id;
            final timestamp = (request['timestamp'] as Timestamp).toDate();
            final formattedDate = DateFormat(
              'yyyy/MM/dd - hh:mm a',
            ).format(timestamp);

            return Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      requestType == 'edit'
                          ? Colors.blue.shade50
                          : Colors.red.shade50,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            requestType == 'edit'
                                ? Colors.blue.shade700
                                : Colors.red.shade700,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            requestType == 'edit' ? Icons.edit : Icons.delete,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            requestType == 'edit' ? 'طلب تعديل' : 'طلب حذف',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            'المستخدم',
                            request['requesterName'] ?? 'غير معروف',
                            Icons.person,
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            'القسم',
                            request['section'] ?? 'غير محدد',
                            Icons.category,
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            'العنصر',
                            request['itemId'] ?? 'غير محدد',
                            Icons.label,
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            'التفاصيل',
                            request['details'] ?? 'لا توجد تفاصيل',
                            Icons.description,
                          ),
                          if (request['additionalData'] != null) ...[
                            SizedBox(height: 8),
                            _buildInfoRow(
                              'بيانات إضافية',
                              request['additionalData'].toString(),
                              Icons.info,
                            ),
                          ],
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                'رفض',
                                Icons.close,
                                Colors.grey.shade700,
                                () => _handleRequest(
                                  requestId,
                                  'rejected',
                                  request,
                                ),
                              ),
                              _buildActionButton(
                                'موافقة',
                                Icons.check,
                                requestType == 'edit'
                                    ? Colors.blue.shade700
                                    : Colors.red.shade700,
                                () => _handleRequest(
                                  requestId,
                                  'approved',
                                  request,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData iconData) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(iconData, size: 18, color: Colors.grey.shade700),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 2),
              Text(value, style: TextStyle(color: Colors.grey.shade900)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _handleRequest(
    String requestId,
    String decision,
    Map<String, dynamic> requestData,
  ) {
    // استخدام خدمة الموافقة بدلاً من التعامل المباشر مع Firestore
    // هذا سيضمن استخدام نظام الإشعارات وتسجيل الأحداث بشكل موحد
    final approvalService = ApprovalService();

    if (decision == 'approved') {
      // استخدام دالة الموافقة من خدمة الموافقة
      approvalService
          .approveRequest(requestId, widget.currentUserEmail)
          .then((_) {
            // تم تنفيذ الموافقة بنجاح
            _executeApprovedRequest(requestData, null);

            // إشعار المستخدم بالنتيجة
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تمت الموافقة على الطلب',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.all(10),
                duration: Duration(seconds: 3),
              ),
            );

            // تحديث واجهة المستخدم لإظهار التغييرات
            setState(() {});
          })
          .catchError((error) {
            // إظهار رسالة خطأ
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'حدث خطأ أثناء الموافقة: $error',
                  textAlign: TextAlign.center,
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.all(10),
              ),
            );
          });
    } else {
      // استخدام دالة الرفض من خدمة الموافقة
      approvalService
          .rejectRequest(
            requestId,
            widget.currentUserEmail,
            'تم الرفض من قبل المدير',
          )
          .then((_) {
            // تم تنفيذ الرفض بنجاح

            // إشعار المستخدم بالنتيجة
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم رفض الطلب',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.all(10),
                duration: Duration(seconds: 3),
              ),
            );

            // تحديث واجهة المستخدم لإظهار التغييرات
            setState(() {});
          })
          .catchError((error) {
            // إظهار رسالة خطأ
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'حدث خطأ أثناء الرفض: $error',
                  textAlign: TextAlign.center,
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.all(10),
              ),
            );
          });
    }
  }

  void _executeApprovedRequest(
    Map<String, dynamic> requestData,
    BuildContext? context,
  ) {
    final String requestType = requestData['type'];
    final String section = requestData['section'];
    final String itemId = requestData['itemId'];

    final ContractDeleteHelper helper = ContractDeleteHelper();

    if (requestType == 'delete') {
      // حذف عقد بيع عادي
      if (section == 'contracts') {
        helper.deleteContract(itemId, context);

        // حذف عقد إعادة بيع (عادة حسب pn)
      } else if (section == 'resale_contracts') {
        final resalePn = requestData['pn'] ?? '';
        helper.deleteResaleContractByPn(resalePn, context);

        // حذف تسوية مالية
      } else if (section == 'financial_settlements') {
        helper.deleteFinancialSettlement(itemId, context);

        // حذف عقد إفراغ
      } else if (section == 'emptying_contracts') {
        helper.deleteEmptyingContract(itemId, context);

        // حذف أي وثيقة أخرى حذف عادي مباشر
      } else {
        FirebaseFirestore.instance.collection(section).doc(itemId).delete();
      }
    } else if (requestType == 'edit') {
      // تنفيذ عملية التعديل
      if (requestData['newData'] != null &&
          requestData['newData'] is Map<String, dynamic>) {
        FirebaseFirestore.instance
            .collection(section)
            .doc(itemId)
            .update(requestData['newData'] as Map<String, dynamic>);
      }
    } else if (requestType == 'duplicate_contract') {
      // السماح بإضافة عقد مكرر لنفس الشقة
      if (requestData['contractData'] != null &&
          requestData['contractData'] is Map<String, dynamic>) {
        FirebaseFirestore.instance
            .collection('contracts')
            .add(requestData['contractData'] as Map<String, dynamic>);
      }
    } else if (requestType == 'apartment_modification') {
      // تعديل بيانات شقة في نظام الموافقة
      if (requestData['apartmentData'] != null &&
          requestData['apartmentData'] is Map<String, dynamic> &&
          requestData['apartmentId'] != null) {
        FirebaseFirestore.instance
            .collection('apartments')
            .doc(requestData['apartmentId'])
            .update(requestData['apartmentData'] as Map<String, dynamic>);
      }
    }
  }
}
