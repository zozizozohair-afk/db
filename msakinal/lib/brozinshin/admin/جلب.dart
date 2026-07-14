import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:msakinal/brozinshin/admin/%D8%B9%D8%B1%D8%B6%20%D8%B9%D9%82%D9%88%D8%AF%20%D8%A7%D8%B9%D8%A7%D8%AF%D8%A9%20%D8%A8%D9%8A%D8%B9.dart';

import '../../class/edit_delete_helper.dart';
import '../../class/contract_delete_helper.dart';
import '../../class/logger.dart';
import '../../priovider/auth_provider.dart';

class ResaleContractFormPage extends StatefulWidget {
  final String originalContractId;

  const ResaleContractFormPage({super.key, required this.originalContractId});

  @override
  _ResaleContractFormPageState createState() => _ResaleContractFormPageState();
}

class _ResaleContractFormPageState extends State<ResaleContractFormPage> {
  final _formKey = GlobalKey<FormState>();
  late var _contractNumberController = TextEditingController();
  final _secondPartyController = TextEditingController();
  final _resaleFeeController = TextEditingController();
  final _marketingFeeController = TextEditingController();
  final _companyFeeController = TextEditingController();
  final _lawyerFeeController = TextEditingController();
  String _status = 'معروض للبيع';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String projectNumber;
  late String unitNumber;
  Map<String, dynamic>? _unetData;
  bool _isLoading = false;
  Map<String, dynamic> _originalContract = {};

  @override
  void initState() {
    _contractNumberController = TextEditingController(
      text: widget.originalContractId,
    );
    super.initState();

    // البحث التلقائي إذا كان هناك رقم عقد مُمرر
    if (widget.originalContractId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOriginalContract(widget.originalContractId);
      });
    }
  }

  // دالة لتحميل بيانات العقد بناءً على رقم العقد المدخل
  Future<void> _loadOriginalContract(String contractNumber) async {
    setState(() => _isLoading = true);
    try {
      final query =
          await FirebaseFirestore.instance
              .collection('contracts')
              .where('pn', isEqualTo: contractNumber)
              .limit(1)
              .get();

      if (query.docs.isEmpty) {
        throw Exception('لا يوجد عقد بهذا الرقم');
      }

      final doc = query.docs.first;
      setState(() {
        _originalContract = {
          ...doc.data(),
          'docId': doc.id, // حفظ معرف المستند
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب البيانات: ${e.toString()}')),
      );
      setState(() => _originalContract = {});
    } finally {
      setState(() => _isLoading = false);
    }
    projectNumber = _originalContract['projectNumber'];
    unitNumber = _originalContract['unitNumber'];
  }

  Future<void> _searchContract1() async {
    try {
      if (unitNumber == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('بيانات العقد غير مكتملة')));
        return;
      }

      // البحث في الوحدات باستخدام projectNumber و unitNumber
      final querySnapshot =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .where('number', isEqualTo: unitNumber)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لا توجد وحدة')));
        return;
      }

      final doc = querySnapshot.docs.first;
      final unitData = doc.data();
      final pnValue = unitData['pn']; // جلب قيمة حقل pn من الوحدة

      // 1. تحديث بيانات الوحدة
      await _firestore.collection('apartments').doc(doc.id).update({
        'status': 'معروضة للبيع',
        'totalAmount': double.parse(_secondPartyController.text),
        'resaleContractDate': FieldValue.serverTimestamp(),
      });

      // 2. إضافة pn إلى جدول عقود إعادة البيع عند الإنشاء
      // (يتم تنفيذ هذه الخطوة في دالة _submitForm)
      // سنقوم بنقل قيمة pn إلى _originalContract لاستخدامها لاحقاً
      setState(() {
        _unetData = {...unitData, 'docId': doc.id};
        _originalContract['pn'] =
            pnValue; // حفظ قيمة pn للاستخدام في _submitForm
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء البحث: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchContract2() async {
    try {
      if (unitNumber == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('بيانات العقد غير مكتملة')));
        return;
      }

      // البحث في الوحدات باستخدام projectNumber و unitNumber
      final querySnapshot =
          await _firestore
              .collection('customers')
              .where('pn', isEqualTo: _originalContract['pn'])
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لم يتم التعديل في العميل')));
        return;
      }

      final doc = querySnapshot.docs.first;
      final unitData = doc.data();
      final pnValue = unitData['pn']; // جلب قيمة حقل pn من الوحدة

      // 1. تحديث بيانات الوحدة
      await _firestore.collection('customers').doc(doc.id).update({
        'contractNumber':
            '${unitData['pn']}'
            'a',
      });

      // 2. إضافة pn إلى جدول عقود إعادة البيع عند الإنشاء
      // (يتم تنفيذ هذه الخطوة في دالة _submitForm)
      // سنقوم بنقل قيمة pn إلى _originalContract لاستخدامها لاحقاً
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تحديث حالة العميل: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // دالة لإرسال البيانات بعد تعديلها
  // دالة لحذف عقد إعادة البيع
  Future<void> _deleteResaleContract(String resaleContractId) async {
    // استخدام EditDeleteHelper بدلاً من الحذف المباشر
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final editDeleteHelper = EditDeleteHelper();
    final shouldDelete = await editDeleteHelper.showDeleteConfirmationDialog(
      context,
      'عقد إعادة البيع',
    );

    if (shouldDelete) {
      try {
        // الحصول على بريد المستخدم الحالي
        final currentUser = FirebaseAuth.instance.currentUser;
        final userEmail = currentUser?.email ?? '';

        // جلب بيانات عقد إعادة البيع قبل الحذف لتسجيلها
        final resaleDoc =
            await FirebaseFirestore.instance
                .collection('resale_contracts')
                .doc(resaleContractId)
                .get();
        final resaleData = resaleDoc.data();
        final rs = resaleData!['pn'];
        await editDeleteHelper.createDeleteRequest(
          context: context,
          section: 'resale_contracts',
          itemId: rs,
          requesterName: authProvider.username ?? 'مستخدم',
          requesterEmail: userEmail,
          details: 'طلب حذف عقد إعادة البيع رقم ${resaleData['pn'] ?? ''}',
        );

        // إذا كان المستخدم هو المستر، قم بتنفيذ عملية الحذف مباشرة
        if (userEmail == 'zizoalzohairy@gmail.com') {
          final contractDeleteHelper = ContractDeleteHelper();
          await contractDeleteHelper.deleteResaleContractByPn(rs, context);

          // تسجيل عملية الحذف
          await logAction(
            category: 'حذف',
            action: 'حذف عقد إعادة بيع',
            itemId: resaleContractId,
            userId: userEmail,
            oldData: resaleData ?? {},
            newData: {},
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حذف عقد إعادة البيع: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. التحقق من عدم وجود عقد إعادة بيع سابق بنفس pn
      final existingResaleQuery =
          await FirebaseFirestore.instance
              .collection('resale_contracts')
              .where('pn', isEqualTo: _originalContract['pn'])
              .limit(1)
              .get();

      if (existingResaleQuery.docs.isNotEmpty) {
        throw Exception('يوجد عقد إعادة بيع سابق لهذه الوحدة');
      }

      // 2. جلب أحدث نسخة من العقد الأصلي
      final originalContractDoc =
          await FirebaseFirestore.instance
              .collection('contracts')
              .doc(_originalContract['docId'])
              .get();

      if (!originalContractDoc.exists) {
        throw Exception('العقد الأصلي لم يعد موجوداً');
      }

      // 3. إنشاء بيانات عقد إعادة البيع
      final resaleData = {
        ...originalContractDoc.data()!,
        'secondPartyAmount': double.parse(_secondPartyController.text),
        'resaleFee': double.parse(_resaleFeeController.text),
        'marketingFee': double.parse(_marketingFeeController.text),
        'companyFee': double.parse(_companyFeeController.text),
        'lawyerFee': double.parse(_lawyerFeeController.text),
        'status': _status,
        'createdAt': FieldValue.serverTimestamp(),
        'isResale': true,
        'originalContractId': _originalContract['docId'],
        'pn': _originalContract['pn'],
        'resaleContractNumber': 'RES-${_originalContract['contractNumber']}',
      };

      // 4. حفظ العقد الجديد
      final resaleRef = await FirebaseFirestore.instance
          .collection('resale_contracts')
          .add(resaleData);

      // 5. تحديث العقد الأصلي
      await FirebaseFirestore.instance
          .collection('contracts')
          .doc(_originalContract['docId'])
          .update({
            'status': 'إعادة بيع',
            'resaleDate': FieldValue.serverTimestamp(),
          });

      // 6. تحديث حالة الوحدة
      await _firestore
          .collection('apartments')
          .doc(_unetData!['docId'])
          .update({
            'status': 'معروضة للبيع',
            'totalAmount': double.parse(_secondPartyController.text),
            'resaleContractDate': FieldValue.serverTimestamp(),
          });

      // 7. إضافة العملية المالية
      await FirebaseFirestore.instance.collection('financialTransactions').add({
        'date':
            FieldValue.serverTimestamp(), // أو استخدم _selectedDate إذا كان لديك
        'pn': _originalContract['pn'],
        'projectNumber': _originalContract['projectNumber'],
        'unitNumber': _originalContract['unitNumber'],
        'customerName':
            _originalContract['clientName'], // أو أي حقل آخر يحتوي على اسم العميل
        'amount': double.parse(_resaleFeeController.text),
        'debitCredit': 'عليه', // أو 'credit' حسب احتياجاتك
        'idNumber':
            _originalContract['identityNumber'], // أو أي حقل آخر يحتوي على رقم الهوية
        'description': 'عقد إعادة بيع للوحدة ${_originalContract['pn']}',
        'transactionType': 'رسوم اعادة بيع',
        'createdAt': FieldValue.serverTimestamp(),
        'relatedContractId': resaleRef.id, // ربط العملية بالعقد الجديد
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء عقد إعادة البيع وإضافة العملية المالية بنجاح',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ResaleContractsListPage()),
          );
        },
        label: Text(
          'طباعة العقود',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: Icon(Icons.local_print_shop_sharp),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 6,
      ),

      appBar: AppBar(title: Text('إنشاء عقد إعادة بيع')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
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
                                  Icon(
                                    Icons.search,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'البحث عن العقد',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                controller: _contractNumberController,
                                decoration: InputDecoration(
                                  labelText: 'رقم العقد',
                                  hintText: 'أدخل رقم العقد للبحث',
                                  prefixIcon: Icon(
                                    Icons.assignment,
                                    color: Colors.blue,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return 'رقم العقد مطلوب';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isLoading
                                          ? null
                                          : () {
                                            if (_contractNumberController
                                                .text
                                                .isNotEmpty) {
                                              _loadOriginalContract(
                                                _contractNumberController.text,
                                              );
                                            }
                                          },
                                  icon: Icon(Icons.search),
                                  label: Text(
                                    'بحث عن العقد',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_originalContract.isNotEmpty) ...[
                        SizedBox(height: 20),
                        _buildContractInfoCard(),
                        SizedBox(height: 20),
                        _buildResaleForm(),
                        SizedBox(height: 24),

                        // أزرار العمليات
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isLoading
                                        ? null
                                        : () {
                                          _searchContract1();
                                          _submitForm();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      ResaleContractsListPage(),
                                            ),
                                          );
                                        },
                                icon: Icon(Icons.save),
                                label: Text(
                                  'حفظ العقد',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              ResaleContractsListPage(),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.list),
                                label: Text(
                                  'عرض العقود',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildContractInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'البيانات الأساسية للعقد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'رقم العقد',
                    _originalContract['pn']?.toString() ?? 'غير معروف',
                    Icons.assignment,
                  ),
                  Divider(color: Colors.green[200]),
                  _buildInfoRow(
                    'اسم العميل',
                    _originalContract['clientName']?.toString() ?? 'غير معروف',
                    Icons.person,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResaleForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_document, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text(
                  'بيانات إعادة البيع',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField('مبلغ الطرف الثاني', _secondPartyController),
            _buildTextField('رسوم إعادة البيع', _resaleFeeController),
            _buildTextField('أتعاب التسويق', _marketingFeeController),
            _buildTextField('أتعاب الشركة', _companyFeeController),
            _buildTextField('أتعاب المحامي', _lawyerFeeController),
            SizedBox(height: 16),
            _buildStatusDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, [
    FormFieldValidator<String>? validator,
  ]) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'أدخل $label',
          prefixIcon: Icon(Icons.attach_money, color: Colors.orange),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        keyboardType: TextInputType.number,
        validator:
            validator ?? (value) => value!.isEmpty ? '$label مطلوب' : null,
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      items:
          [
            'معروض للبيع',
            'تم البيع',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (value) => setState(() => _status = value!),
      decoration: InputDecoration(
        labelText: 'حالة العقد',
        prefixIcon: Icon(Icons.flag, color: Colors.orange),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.orange, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData String) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.green[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green[800],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _secondPartyController.dispose();
    _resaleFeeController.dispose();
    _marketingFeeController.dispose();
    _companyFeeController.dispose();
    _lawyerFeeController.dispose();
    super.dispose();
  }
}
