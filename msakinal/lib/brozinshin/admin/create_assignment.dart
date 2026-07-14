import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;

import '../../priovider/auth_provider.dart';
import '../../class/logger.dart';
import 'contract_assignments.dart';

class CreateAssignment extends StatefulWidget {
  final String? contractId;
  const CreateAssignment({super.key, this.contractId});

  @override
  State<CreateAssignment> createState() => _CreateAssignmentState();
}

class _CreateAssignmentState extends State<CreateAssignment> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  // للبحث عن العقد والوحدة
  final _contractSearchController = TextEditingController();
  Map<String, dynamic>? _contractData;
  Map<String, dynamic>? _unitData;

  // بيانات المالك الأصلي
  final _originalOwnerNameController = TextEditingController();
  final _originalOwnerIDController = TextEditingController();
  final _originalOwnerPhoneController = TextEditingController();

  // إضافة متغير لتخزين بيانات العميل المتنازل له
  Map<String, dynamic>? _newCustomerData;
  final _newOwnerNameController = TextEditingController();
  final _newOwnerIDController = TextEditingController();
  final _newOwnerPhoneController = TextEditingController();

  // بيانات الوحدة
  String? _projectNumber;
  String? _unitNumber;
  String? _floor;
  String? _city;
  String? _district;
  String? _direction;
  String? _contractDate;

  @override
  void initState() {
    super.initState();
    if (widget.contractId != null) {
      _contractSearchController.text = widget.contractId!;
      _searchContract();
    }
  }

  Future<bool> _canCreateAssignment(Map<String, dynamic> contractData) async {
    try {
      // التحقق من حالة العقد
      final status = contractData['status']?.toString().trim() ?? '';

      // قائمة الحالات التي تمنع التنازل
      final forbiddenStatuses = [
        'تم الافراغ',
        'ملغي',
        'إعادة بيع',
        'تمت إعادة البيع',
        'تنازل',
        'منتهي',
      ];

      if (forbiddenStatuses.contains(status)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن إنشاء تنازل لهذا العقد - الحالة: $status'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // التحقق من المبلغ المدفوع
      final totalAmount =
          double.tryParse(contractData['totalAmount']?.toString() ?? '0') ??
          0.0;
      final paidAmount =
          double.tryParse(contractData['paidAmount']?.toString() ?? '0') ?? 0.0;

      if (totalAmount > 0 && paidAmount < (totalAmount * 0.5)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن إنشاء تنازل - المبلغ المدفوع أقل من 50%'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      print('خطأ في التحقق من إمكانية التنازل: $e');
      return false;
    }
  }

  Future<void> _searchContract() async {
    setState(() => _isLoading = true);
    try {
      // التحقق من وجود تنازل سابق أولاً
      final assignmentQuery =
          await _firestore
              .collection('contract_assignments')
              .where(
                'contractId',
                isEqualTo: _contractSearchController.text + '-تنازل',
              )
              .limit(1)
              .get();

      if (assignmentQuery.docs.isNotEmpty) {
        final assignmentDoc = assignmentQuery.docs.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يوجد تنازل سابق لهذا العقد'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        // الانتقال إلى صفحة التنازلات مع تمرير معرف التنازل
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => ContractAssignmentsPage(
                  highlightAssignmentId: assignmentDoc.id,
                  searchQuery: _contractSearchController.text,
                ),
          ),
        );
        return;
      }

      // إذا لم يكن هناك تنازل سابق، نكمل البحث عن العقد
      final contractQuery =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: _contractSearchController.text)
              .limit(1)
              .get();

      if (contractQuery.docs.isEmpty) {
        throw Exception('لا يوجد عقد بهذا الرقم');
      }

      final contractDoc = contractQuery.docs.first;
      final contractData = contractDoc.data();

      // التحقق من إمكانية إنشاء تنازل
      if (!await _canCreateAssignment(contractData)) {
        setState(() => _isLoading = false);
        return;
      }

      // تحديث المتغيرات إذا مر كل شيء بنجاح
      _contractData = contractData;

      // البحث عن الوحدة
      final unitQuery =
          await _firestore
              .collection('apartments')
              .where('pn', isEqualTo: _contractData!['pn'])
              .limit(1)
              .get();

      if (unitQuery.docs.isNotEmpty) {
        _unitData = unitQuery.docs.first.data();
        _loadUnitData();
      }

      // تحميل بيانات المالك
      _loadOwnerData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadUnitData() {
    setState(() {
      _projectNumber = _unitData!['projectNumber'];
      _unitNumber = _unitData!['number'];
      _floor = _unitData!['floor'];
      _city = _unitData!['city'];
      _district = _unitData!['district'];
      _direction = _unitData!['direction'];
      _contractDate = _contractData!['dateHijri'];
    });
  }

  void _loadOwnerData() {
    setState(() {
      _originalOwnerNameController.text = _contractData!['clientName'] ?? '';
      _originalOwnerIDController.text =
          _contractData!['clientData']['identityNumber'] ?? '';
      _originalOwnerPhoneController.text =
          _contractData!['clientData']['phoneNumber'] ?? '';
    });
  }

  // دالة البحث عن العميل
  Future<void> _searchCustomer(String identityNumber) async {
    try {
      final customerQuery =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: identityNumber)
              .limit(1)
              .get();

      if (customerQuery.docs.isNotEmpty) {
        final customerData = customerQuery.docs.first.data();
        setState(() {
          _newCustomerData = customerData;
          _newOwnerNameController.text = customerData['name'] ?? '';
          _newOwnerPhoneController.text = customerData['phoneNumber'] ?? '';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم العثور على العميل')));
      } else {
        setState(() => _newCustomerData = null);
        // إظهار حقول إضافة عميل جديد
        _newOwnerNameController.clear();
        _newOwnerPhoneController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في البحث عن العميل: $e')));
    }
  }

  // دالة إضافة/تحديث العميل
  Future<void> _updateCustomerData() async {
    try {
      final customerData = {
        'name': _newOwnerNameController.text,
        'identityNumber': _newOwnerIDController.text,
        'phoneNumber': _newOwnerPhoneController.text,
        'contractNumbers': [_contractData!['pn'] + '-تنازل'],
        'lastModified': FieldValue.serverTimestamp(),
      };

      // البحث عن العميل باستخدام رقم الهوية
      final customerQuery =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: _newOwnerIDController.text)
              .limit(1)
              .get();

      if (customerQuery.docs.isNotEmpty) {
        // تحديث العميل الموجود
        final customerDoc = customerQuery.docs.first;
        final existingContractNumbers = List<String>.from(
          customerDoc.data()['contractNumbers'] ?? [],
        );

        if (!existingContractNumbers.contains(
          _contractData!['pn'] + '-تنازل',
        )) {
          existingContractNumbers.add(_contractData!['pn'] + '-تنازل');
        }

        customerData['contractNumbers'] = existingContractNumbers;
        await _firestore
            .collection('customers')
            .doc(customerDoc.id)
            .update(customerData);
      } else {
        // إضافة عميل جديد
        customerData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('customers').add(customerData);
      }
    } catch (e) {
      print('خطأ في تحديث بيانات العميل: $e');
      throw e;
    }
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _updateCustomerData();
      final username =
          Provider.of<AppAuthProvider>(context, listen: false).username;

      // 1. تحديث بيانات الوحدة باستخدام pn
      final unitQuery =
          await _firestore
              .collection('apartments')
              .where('pn', isEqualTo: _contractData!['pn'])
              .limit(1)
              .get();

      if (unitQuery.docs.isNotEmpty) {
        await _firestore
            .collection('apartments')
            .doc(unitQuery.docs.first.id)
            .update({
              'clientName': _newOwnerNameController.text,
              'clientIdentity': _newOwnerIDController.text,
              'clientPhone': _newOwnerPhoneController.text,
              'previousOwner': _originalOwnerNameController.text,
              'lastModified': FieldValue.serverTimestamp(),
              'modifiedBy': username,
            });
      } else {
        throw Exception('لم يتم العثور على الوحدة');
      }

      // 2. تحديث بيانات العقد
      final contractQuerySnapshot =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: _contractSearchController.text)
              .limit(1)
              .get();

      if (contractQuerySnapshot.docs.isNotEmpty) {
        await _firestore
            .collection('contracts')
            .doc(contractQuerySnapshot.docs.first.id)
            .update({
              'clientName': _newOwnerNameController.text,
              'clientData': {
                'identityNumber': _newOwnerIDController.text,
                'phoneNumber': _newOwnerPhoneController.text,
              },
              'previousOwnerData': {
                'name': _originalOwnerNameController.text,
                'identityNumber': _originalOwnerIDController.text,
                'phoneNumber': _originalOwnerPhoneController.text,
              },
              'status': 'تم التنازل',
              'assignmentDate': FieldValue.serverTimestamp(),
              'lastModified': FieldValue.serverTimestamp(),
              'modifiedBy': username,
            });
      }

      // 3. إنشاء وثيقة التنازل
      final assignmentData = {
        'originalOwnerName': _originalOwnerNameController.text,
        'originalOwnerID': _originalOwnerIDController.text,
        'originalOwnerPhone': _originalOwnerPhoneController.text,
        'newOwnerName': _newOwnerNameController.text,
        'newOwnerID': _newOwnerIDController.text,
        'projectNumber': _projectNumber,
        'unitNumber': _unitNumber,
        'floor': _floor,
        'city': _city,
        'district': _district,
        'direction': _direction,
        'contractDate': _contractDate,
        'assignmentDate': intl.DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'contractId': _contractData!['pn'] + '-تنازل',
        'newOwnerPhone': _newOwnerPhoneController.text,
        'status': 'جديد',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': username,
      };

      // حفظ التنازل
      final docRef = await _firestore
          .collection('contract_assignments')
          .add(assignmentData);

      // تسجيل العملية
      await logAction(
        category: 'تنازلات',
        action: 'إنشاء',
        itemId: docRef.id,
        userId: username ?? '',
        oldData: {},
        newData: assignmentData,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ التنازل وتحديث البيانات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ContractAssignmentsPage()),
      );
    } catch (e) {
      print('خطأ تحديث البيانات: $e'); // إضافة للتشخيص
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _printAssignment(
    BuildContext context, {
    Map<String, dynamic>? existingData,
  }) async {
    // نفس دالة الطباعة الموجودة في ContractAssignmentsPage
    // يمكن نقلها إلى ملف مشترك أو إعادة استخدامها هنا
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إنشاء تنازل جديد'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بطاقة البحث عن العقد
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.search, color: Colors.blue.shade700),
                          SizedBox(width: 8),
                          Text(
                            'البحث عن العقد',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextFormField(
                          controller: _contractSearchController,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: 'رقم العقد',
                            prefixIcon: Icon(Icons.assignment, color: Colors.blue.shade600),
                            suffixIcon: Container(
                              margin: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.search, color: Colors.white),
                                onPressed: _searchContract,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'رقم العقد مطلوب' : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              if (_contractData != null) ...[
                // بطاقة بيانات المالك الأصلي
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.green.shade700),
                            SizedBox(width: 8),
                            Text(
                              'بيانات المالك الأصلي',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildStyledTextField(
                          controller: _originalOwnerNameController,
                          label: 'اسم المالك',
                          icon: Icons.person_outline,
                          validator: (value) => value?.isEmpty ?? true ? 'اسم المالك مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        _buildStyledTextField(
                          controller: _originalOwnerIDController,
                          label: 'رقم الهوية',
                          icon: Icons.badge_outlined,
                          textDirection: TextDirection.rtl,
                          validator: (value) => value?.isEmpty ?? true ? 'رقم الهوية مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        _buildStyledTextField(
                           controller: _originalOwnerPhoneController,
                           label: 'رقم الجوال',
                           icon: Icons.phone_outlined,
                           textDirection: TextDirection.rtl,
                           validator: (value) => value?.isEmpty ?? true ? 'رقم الجوال مطلوب' : null,
                         ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // بطاقة بيانات المتنازل له
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_add, color: Colors.orange.shade700),
                            SizedBox(width: 8),
                            Text(
                              'بيانات المتنازل له',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: TextFormField(
                            controller: _newOwnerIDController,
                            textDirection: TextDirection.rtl,
                            decoration: InputDecoration(
                              labelText: 'رقم هوية المتنازل له',
                              prefixIcon: Icon(Icons.badge_outlined, color: Colors.orange.shade600),
                              suffixIcon: Container(
                                margin: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.search, color: Colors.white),
                                  onPressed: () => _searchCustomer(_newOwnerIDController.text),
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) {
                              if (value.length >= 10) {
                                _searchCustomer(value);
                              }
                            },
                            validator: (value) => value?.isEmpty ?? true ? 'رقم الهوية مطلوب' : null,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildStyledTextField(
                          controller: _newOwnerNameController,
                          label: 'اسم المتنازل له',
                          icon: Icons.person_outline,
                          validator: (value) => value?.isEmpty ?? true ? 'اسم المتنازل له مطلوب' : null,
                        ),
                        SizedBox(height: 16),
                        _buildStyledTextField(
                           controller: _newOwnerPhoneController,
                           label: 'رقم جوال المتنازل له',
                           icon: Icons.phone_outlined,
                           textDirection: TextDirection.rtl,
                           validator: (value) => value?.isEmpty ?? true ? 'رقم الجوال مطلوب' : null,
                         ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // زر الحفظ
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade300,
                        offset: Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'جاري الحفظ...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'حفظ التنازل',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextDirection? textDirection,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        textDirection: textDirection,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
      ),
    );
  }
}
