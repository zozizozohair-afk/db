import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';

import 'brozinshin/admin/طباعة محضر الاستلام.dart';

class Aistlam extends StatefulWidget {
  final String? progect; // رقم العقد (اختياري)
  final String? unitPn; // رقم الشقة (اختياري)
  const Aistlam({super.key, this.progect, this.unitPn});

  @override
  _AistlamState createState() => _AistlamState();
}

class _AistlamState extends State<Aistlam> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final TextEditingController _contractSearchController =
      TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _newPriceController = TextEditingController();
  final TextEditingController _moakif = TextEditingController();
  final TextEditingController _amountController =
      TextEditingController(); // إضافة controller جديد للمبلغ
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _paymentAmountController =
      TextEditingController();
  final TextEditingController _referenceNumberController =
      TextEditingController();
  final TextEditingController _requiredAmountController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _transactionTypeController =
      TextEditingController();
  final TextEditingController _paymentDescriptionController =
      TextEditingController();
  DateTime _paymentSelectedDate = DateTime.now();
  Map<String, dynamic>? _contractData;
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _unetData;
  bool _isLoading = false;
  bool _showContractCard = false;
  bool _showCustomerCard = false;
  bool _showForm = false;
  bool _showPaymentForm = false;
  bool _showPaymentDialog = false;
  bool _showRequiredAmountForm = false;
  double _totalPaidAmount = 0.0;
  double _requiredAmount = 0.0;
  String _amountInWords = '';
  late String projectNumber;
  late String unitNumber;
  String nam = '';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.unitPn != null) {
      // الحالة الجديدة: فتح الصفحة من الوحدة فقط
      _contractSearchController.text = '';
      _searchUnitDirect(widget.unitPn!);
    } else if (widget.progect != null) {
      // الحالة القديمة: البحث بالعقد
      _contractSearchController.text = widget.progect!;
      _generateNewContractNumber();
    }
  }

  void _generateNewContractNumber() {
    setState(() {});
  }

  Future<void> _searchContract() async {
    if (_contractSearchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _contractData = null;
      _showContractCard = true;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: _contractSearchController.text)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لا يوجد عقد بهذا الرقم')));
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final doc = querySnapshot.docs.first;
      setState(() {
        _contractData = {...doc.data(), 'docId': doc.id};
        _showContractCard = true;
      });

      nam = '${_contractData!['pn'] ?? ''}';
      projectNumber = _contractData?['pn'];

      // ابحث أولاً في جدول التسويات المالية
      final settlementSnapshot =
          await _firestore
              .collection('financialSettlements')
              .where('newContractNumber', isEqualTo: nam)
              .limit(1)
              .get();

      if (settlementSnapshot.docs.isNotEmpty) {
        // يوجد تسوية مالية، خذ هوية العميل الجديد من التسوية
        final settlementData = settlementSnapshot.docs.first.data();
        final newCustomerId = settlementData['newCustomerId'];
        // ابحث عن العميل الجديد في جدول العملاء
        final customerSnapshot =
            await _firestore
                .collection('customers')
                .where('identityNumber', isEqualTo: newCustomerId)
                .limit(1)
                .get();
        if (customerSnapshot.docs.isNotEmpty) {
          final doc = customerSnapshot.docs.first;
          setState(() {
            _customerData = {...doc.data(), 'docId': doc.id};
            _showCustomerCard = true;
            _showForm = _showContractCard && _showCustomerCard;
          });
        } else {
          // لم يتم العثور على عميل جديد رغم وجود تسوية مالية
          setState(() {
            _customerData = null;
            _showCustomerCard = false;
            _showForm = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم العثور على العميل الجديد في قاعدة العملاء'),
            ),
          );
        }
      } else {
        // لا يوجد تسوية مالية، استخدم العميل من بيانات العقد الأصلي
        final identity = _contractData!['clientData']['identityNumber'];
        final customerSnapshot =
            await _firestore
                .collection('customers')
                .where('identityNumber', isEqualTo: identity)
                .limit(1)
                .get();
        if (customerSnapshot.docs.isNotEmpty) {
          final doc = customerSnapshot.docs.first;
          setState(() {
            _customerData = {...doc.data(), 'docId': doc.id};
            _showCustomerCard = true;
            _showForm = _showContractCard && _showCustomerCard;
          });
        } else {
          setState(() {
            _customerData = null;
            _showCustomerCard = false;
            _showForm = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم العثور على العميل الأصلي في قاعدة العملاء'),
            ),
          );
        }
      }
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

  Future<void> _searchunt() async {
    setState(() {
      _isLoading = true;
      _customerData = null;
      _showCustomerCard = false;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('apartments')
              .where('pn', isEqualTo: _contractSearchController.text)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _unetData = querySnapshot.docs.first.data();
          _showCustomerCard = true;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لم يتم جلب الوحدة')));
      }
      final doc = querySnapshot.docs.first;
      setState(() {
        _unetData = {
          ...doc.data(),
          'docId': doc.id, // حفظ معرف المستند
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء البحث: $e')));
    } finally {
      setState(() {
        _isLoading = false;
        _showForm = _showContractCard && _showCustomerCard;
      });
    }
  }

  Future<void> _searchCustomer() async {
    setState(() {
      _isLoading = true;
      _customerData = null;
      _showCustomerCard = false;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('customers')
              .where(
                'identityNumber',
                isEqualTo: _customerSearchController.text,
              )
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _customerData = querySnapshot.docs.first.data();
          _showCustomerCard = true;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لا يوجد عميل بهذا الرقم')));
      }
      final doc = querySnapshot.docs.first;
      setState(() {
        _customerData = {
          ...doc.data(),
          'docId': doc.id, // حفظ معرف المستند
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء البحث: $e')));
    } finally {
      setState(() {
        _isLoading = false;
        _showForm = _showContractCard && _showCustomerCard;
      });
    }
  }

  // دالة لحذف عقد الإفراغ

  Future<void> _submitSettlement() async {
    if (_newPriceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يرجى إدخال رقم عداد الكهرباء ')));
      return;
    }

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    try {
      if (_contractData == null && _unetData != null && _customerData != null) {
        // تحقق من وجود محضر استلام سابق
        final existing = await _firestore
            .collection('astlam')
            .where('newContractNumber', isEqualTo: _unetData!['pn'])
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('يوجد محضر استلام سابق لهذه الوحدة')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // إضافة محضر الاستلام
        await _firestore.collection('astlam').add({
          'newContractNumber':
              _unetData!['pn'] ?? '', // لا يوجد رقم عقد جديد في حالة الوحدة فقط
          'originalContractNumber':
              '', // لا يوجد رقم عقد أصلي في حالة الوحدة فقط
          'projectNumber': _unetData!['projectNumber'] ?? '',
          'apartmentNumber': _unetData!['number'] ?? '',
          'adad': _newPriceController.text,
          'maoakif': _moakif.text,
          'date': formattedDate,
          'customerName': _customerData!['name'],
          'clientIdentityNumber': _customerData!['identityNumber'],
          'clientPhoneNumber': _customerData!['phoneNumber'],
          'deedNumber': _unetData!['deedNumber'] ?? '',
          'regionNumber': _unetData!['regionNumber'] ?? '',
          'numberf': _unetData!['floor'] ?? '',
          'numbermo': _unetData!['planNumber'] ?? '',
          'hy': _unetData!['district'] ?? '',
          'unitDirection': _unetData!['direction'] ?? '',
          'dateString': formattedDate,
        });



        // تحديث بيانات الوحدة
        await _firestore
            .collection('apartments')
            .doc(_unetData!['docId'])
            .update({
              'clientName': _customerData!['name'],
              'status': 'تم الإفراغ',
              'clientIdentity': _customerData!['identityNumber'],
              'dateStringafragh': formattedDate,
            });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم حفظ محضر الاستلام بنجاح')));
        _resetForm();
        return;
      }

      // الحالة الأصلية: يوجد عقد
      final docId = _contractData?['docId'];
      final docId1 = _customerData?['docId'];
      final docId2 = _unetData?['docId'];

      // تحقق من وجود محضر استلام مسبقاً بنفس رقم العقد الجديد
      final existingByPn = await _firestore
          .collection('astlam')
          .where('newContractNumber', isEqualTo: nam)
          .limit(1)
          .get();
      if (existingByPn.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يوجد محضر استلام سابق لهذا العقد')),
        );
        setState(() => _isLoading = false);
        return;
      }

      await _firestore.collection('astlam').add({
        'newContractNumber': nam,
        'originalContractNumber': _contractData!['contractNumber'],
        'projectNumber': _contractData!['projectNumber'],
        'apartmentNumber': _contractData!['unitNumber'],
        'adad': _newPriceController.text,
        'maoakif': _moakif.text,
        'date': formattedDate,
        'customerName': _customerData!['name'],
        'clientIdentityNumber': _customerData!['identityNumber'],
        'clientPhoneNumber': _customerData!['phoneNumber'],
        'deedNumber': _unetData!['deedNumber'],
        'regionNumber': _unetData!['regionNumber'],
        'numberf': _unetData!['floor'],
        'numbermo': _unetData!['planNumber'],
        'hy': _unetData!['district'],
        'unitDirection': _unetData!['direction'],
        'dateString': formattedDate,
      });

      // تحديث بيانات العقد والوحدة والعميل كما هو في كودك الحالي...
      await _firestore.collection('contracts').doc(docId).update({
        'status': 'تم الافراغ',
        'settlementContractNumber': nam,
      });

      await _firestore.collection('customers').doc(docId1).update({
        'contractNumbers': nam,
      });
      await _firestore.collection('apartments').doc(docId2).update({
        'clientName': _customerData!['name'],
        'status': 'تم الإفراغ',
        'clientIdentity': _customerData!['identityNumber'],
        'dateStringafragh': formattedDate,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حفظ محضر الاستلام بنجاح')));
      _resetForm();
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // دالة حفظ المبلغ المستحق
  Future<void> _saveRequiredAmount() async {
    if (_requiredAmountController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _transactionTypeController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_requiredAmountController.text);
      final customerName = _customerData!['name'];
      final identityNumber = _customerData!['identityNumber'];

      // إنشاء رقم الكود
      String cod = '';
      if (_contractData != null) {
        cod =
            '${_contractData!['projectNumber']}-${_contractData!['unitNumber']}';
      } else if (_unetData != null) {
        final parts = _unetData!['pn'].split('-');
        cod = _unetData!['pn'];
      }

      // حفظ المبلغ المستحق في قاعدة البيانات
      await _firestore.collection('financialTransactions').add({
        'amount': amount,
        'cod': cod,
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': customerName,
        'date': Timestamp.fromDate(_selectedDate),
        'debitCredit': 'عليه',
        'description': _descriptionController.text,
        'idNumber': identityNumber,
        'pn': cod,
        'projectNumber': cod.split('-')[0],
        'transactionType': _transactionTypeController.text,
        'unitNumber': cod.contains('-') ? cod.split('-')[1] : '',
      });

      setState(() {
        _requiredAmount = amount;
        _showRequiredAmountForm = false;
        _showPaymentForm = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حفظ المبلغ المستحق بنجاح')));

      // مسح الحقول
      _requiredAmountController.clear();
      _descriptionController.clear();
      _transactionTypeController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // دالة اختيار التاريخ
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // دالة اختيار تاريخ الدفعة
  Future<void> _selectPaymentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentSelectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _paymentSelectedDate) {
      setState(() {
        _paymentSelectedDate = picked;
      });
    }
  }

  // دالة للتحقق من وجود مبلغ مستحق مسبقاً
  Future<void> _checkExistingRequiredAmount() async {
    try {
      String cod = '';
      if (_contractData != null) {
        cod =
            '${_contractData!['projectNumber']}-${_contractData!['unitNumber']}';
      } else if (_unetData != null) {
        cod = _unetData!['pn'];
      }

      final querySnapshot =
          await _firestore
              .collection('financialTransactions')
              .where('idNumber', isEqualTo: _customerData!['identityNumber'])
              .where('debitCredit', isEqualTo: 'عليه')
              .where('pn', isEqualTo: cod)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        // يوجد مبلغ مستحق مسبقاً
        final doc = querySnapshot.docs.first.data();
        setState(() {
          _requiredAmount = (doc['amount'] ?? 0.0).toDouble();
          _showRequiredAmountForm = false;
          _showPaymentForm = true;
        });
        await _calculateTotalPaidAmount();
      }
    } catch (e) {
      print('خطأ في التحقق من المبلغ المستحق: $e');
    }
  }

  void _resetForm() {
    _contractSearchController.clear();
    _customerSearchController.clear();
    _newPriceController.clear();
    _moakif.clear();
    _amountController.clear(); // إعادة تعيين حقل المبلغ
    _paymentAmountController.clear();
    _paymentDescriptionController.clear();
    _referenceNumberController.clear();
    _requiredAmountController.clear();
    _descriptionController.clear();
    _transactionTypeController.clear();
    setState(() {
      _contractData = null;
      _customerData = null;
      _showContractCard = false;
      _showCustomerCard = false;
      _showForm = false;
      _showRequiredAmountForm = false;
      _showPaymentForm = false;
      _amountInWords = '';
      _paymentSelectedDate = DateTime.now();
      _selectedDate = DateTime.now();
      _generateNewContractNumber();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('محضر استلام وحدة سكنية'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search for contract - إخفاء عند القدوم من صفحة الوحدات
            if (widget.unitPn == null) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'بحث عن العقد الأصلي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _contractSearchController,
                        decoration: InputDecoration(
                          labelText: 'رقم العقد',
                          hintText: widget.progect,
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.search),
                            onPressed: () {
                              _searchContract();
                              _searchunt();
                            },
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Search for customer
            if (widget.unitPn != null) ...[
              if (_unetData != null) _buildUnitCard(), // بطاقة بيانات الوحدة
              // حقل رقم الهوية الجديد
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'بيانات العميل',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _identityController,
                        decoration: InputDecoration(
                          labelText: 'رقم الهوية',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.search),
                            onPressed: _searchCustomerByIdentity,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (value.length >= 10) {
                            _searchCustomerByIdentity();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_showCustomerCard && _customerData != null)
                _buildCustomerCard(),

              // نموذج المبلغ المستحق
              if (_showRequiredAmountForm && _customerData != null) ...[
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'تحديد المبلغ المستحق على العميل',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 15),

                        // حقل المبلغ المستحق
                        TextField(
                          controller: _requiredAmountController,
                          decoration: InputDecoration(
                            labelText: 'المبلغ المستحق (ريال)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                        ),

                        SizedBox(height: 10),

                        // حقل الوصف/البيان
                        TextField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'البيان/الوصف',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 2,
                        ),

                        SizedBox(height: 10),

                        // حقل نوع المعاملة
                        TextField(
                          controller: _transactionTypeController,
                          decoration: InputDecoration(
                            labelText: 'نوع المعاملة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                            hintText: 'مثال: عقد بيع، رسوم إضافية، إلخ',
                          ),
                        ),

                        SizedBox(height: 10),

                        // حقل التاريخ
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'التاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 15),

                        // أزرار العمليات
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _saveRequiredAmount,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child:
                                    _isLoading
                                        ? CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        )
                                        : Text('حفظ المبلغ المستحق'),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showRequiredAmountForm = false;
                                    _requiredAmountController.clear();
                                    _descriptionController.clear();
                                    _transactionTypeController.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('إلغاء'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // نموذج الدفعات المالية
              if (_showPaymentForm && _customerData != null) ...[
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'إضافة دفعة مالية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        SizedBox(height: 10),

                        // عرض المبلغ المطلوب والمدفوع
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المبلغ المطلوب:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_requiredAmount.toStringAsFixed(0)} ريال',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المبلغ المدفوع:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_totalPaidAmount.toStringAsFixed(0)} ريال',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'المبلغ المتبقي:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${(_requiredAmount - _totalPaidAmount).toStringAsFixed(0)} ريال',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 15),

                        // حقل مبلغ الدفعة
                        TextField(
                          controller: _paymentAmountController,
                          decoration: InputDecoration(
                            labelText: 'مبلغ الدفعة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => _updateAmountInWords(),
                        ),

                        // عرض المبلغ بالكلمات
                        if (_amountInWords.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _amountInWords + ' ريال',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 10),

                        // حقل البيان
                        TextField(
                          controller: _paymentDescriptionController,
                          decoration: InputDecoration(
                            labelText: 'بيان الدفعة',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                        ),

                        SizedBox(height: 10),

                        // حقل تحديد التاريخ
                        InkWell(
                          onTap: _selectPaymentDate,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'تاريخ الدفعة: ${DateFormat('yyyy/MM/dd').format(_paymentSelectedDate)}',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 10),

                        // حقل رقم المرجع
                        TextField(
                          controller: _referenceNumberController,
                          decoration: InputDecoration(
                            labelText: 'رقم المرجع (اختياري)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.receipt),
                          ),
                        ),

                        SizedBox(height: 15),

                        // أزرار العمليات
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _addPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child:
                                    _isLoading
                                        ? CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        )
                                        : Text('إضافة الدفعة'),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showPaymentForm = false;
                                    _paymentAmountController.clear();
                                    _paymentDescriptionController.clear();
                                    _referenceNumberController.clear();
                                    _amountInWords = '';
                                    _paymentSelectedDate = DateTime.now();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('الدفع لاحقاً'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_showCustomerCard && _customerData != null)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'بيانات محضر استلام',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _newPriceController,
                          decoration: InputDecoration(
                            labelText: 'رقم عداد الكهرباء للشقة',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: _moakif,
                          decoration: InputDecoration(
                            labelText: 'رقم الموقف الخاص بالشقة',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitSettlement,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text('حفظ محضر الاستلام'),
                        ),
                      ],
                    ),
                  ),
                ),
            ] else
              // ...الكود الحالي للبحث بالعقد...
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'بحث عن العقد الأصلي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _contractSearchController,
                        decoration: InputDecoration(
                          labelText: 'رقم العقد',
                          hintText: widget.progect,
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.search),
                            onPressed: () {
                              _searchContract();
                              _searchunt();
                            },
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 20),

            // Contract Card
            if (_showContractCard && _contractData != null)
              _buildContractCard(),

            // Customer Card
            if (_showCustomerCard && _customerData != null)
              _buildCustomerCard(),

            // Settlement Form
            if (_showForm)
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'بيانات محضر استلام',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'رقم المحضر: $nam',
                        style: TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _newPriceController,
                        decoration: InputDecoration(
                          labelText: 'رقم عداد الكهرباء للشقة',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: _moakif,
                        decoration: InputDecoration(
                          labelText: 'رقم الموقف الخاص بالشقة',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitSettlement,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text('حفظ محضر الاستلام'),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isLoading) Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => Fprintastlam(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(
                  begin: begin,
                  end: end,
                ).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(position: offsetAnimation, child: child);
              },
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
          // Animation when pressed
        },
        tooltip: 'وظيفة إضافية',
        child: Icon(Icons.margin),
      ),
    );
  }

  Widget _buildContractCard() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات العقد الأصلي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Divider(),
            _buildInfoRow('رقم المشروع', _contractData!['projectNumber']),
            _buildInfoRow('تاريخ العقد', _contractData!['dateHijri']),
            _buildInfoRow('رقم الشقة', _contractData!['unitNumber']),
            _buildInfoRow('اتجاه الشقة', _contractData!['direction']),
            _buildInfoRow(
              'رقم القطعة',
              _contractData!['unitData']['regionNumber'],
            ),
            _buildInfoRow('اسم العميل', _contractData!['clientName']),
            _buildInfoRow(
              'هوية العميل',
              _contractData!['clientData']['identityNumber'],
            ),
            _buildInfoRow(
              'رقم جوال العميل',
              _contractData!['clientData']['phoneNumber'],
            ),
            _buildInfoRow('رقم الصك', _contractData!['unitData']['deedNumber']),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات العميل ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Divider(),
            _buildInfoRow('اسم', _customerData!['name']),
            _buildInfoRow('هوية العميل', _customerData!['identityNumber']),
            _buildInfoRow('رقم جوال العميل', _customerData!['phoneNumber']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'غير متوفر',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchUnitDirect(String pn) async {
    setState(() {
      _isLoading = true;
      _unetData = null;
      _showContractCard = false;
      _showCustomerCard = false;
      _showForm = false;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('apartments')
              .where('pn', isEqualTo: pn)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _unetData = {...doc.data(), 'docId': doc.id};
          _showContractCard = false; // لا يوجد عقد
          _showCustomerCard = false;
          _showForm = false;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لم يتم العثور على الوحدة')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء جلب الوحدة: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildUnitCard() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات الوحدة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            Divider(),
            _buildInfoRow('رقم الشقة', _unetData!['pn']),
            _buildInfoRow('رقم الصك', _unetData!['deedNumber']),
            _buildInfoRow('رقم القطعة', _unetData!['regionNumber']),
            _buildInfoRow('الاتجاه', _unetData!['direction']),
            _buildInfoRow('الحي', _unetData!['district']),
            _buildInfoRow('الطابق', _unetData!['floor']),
            _buildInfoRow('رقم المخطط', _unetData!['planNumber']),
          ],
        ),
      ),
    );
  }

  // دالة تحويل الأرقام إلى كلمات
  String _convertNumberToWords(double number) {
    if (number == 0) return 'صفر';

    List<String> ones = [
      '',
      'واحد',
      'اثنان',
      'ثلاثة',
      'أربعة',
      'خمسة',
      'ستة',
      'سبعة',
      'ثمانية',
      'تسعة',
    ];
    List<String> tens = [
      '',
      '',
      'عشرون',
      'ثلاثون',
      'أربعون',
      'خمسون',
      'ستون',
      'سبعون',
      'ثمانون',
      'تسعون',
    ];
    List<String> teens = [
      'عشرة',
      'أحد عشر',
      'اثنا عشر',
      'ثلاثة عشر',
      'أربعة عشر',
      'خمسة عشر',
      'ستة عشر',
      'سبعة عشر',
      'ثمانية عشر',
      'تسعة عشر',
    ];
    List<String> hundreds = [
      '',
      'مائة',
      'مائتان',
      'ثلاثمائة',
      'أربعمائة',
      'خمسمائة',
      'ستمائة',
      'سبعمائة',
      'ثمانمائة',
      'تسعمائة',
    ];
    List<String> thousands = ['', 'ألف', 'مليون', 'مليار'];

    int intNumber = number.toInt();
    String result = '';
    int thousandIndex = 0;

    while (intNumber > 0) {
      int chunk = intNumber % 1000;
      if (chunk != 0) {
        String chunkWords = '';

        // المئات
        if (chunk >= 100) {
          chunkWords += hundreds[chunk ~/ 100] + ' ';
          chunk %= 100;
        }

        // العشرات والآحاد
        if (chunk >= 20) {
          chunkWords += tens[chunk ~/ 10] + ' ';
          if (chunk % 10 != 0) {
            chunkWords += ones[chunk % 10] + ' ';
          }
        } else if (chunk >= 10) {
          chunkWords += teens[chunk - 10] + ' ';
        } else if (chunk > 0) {
          chunkWords += ones[chunk] + ' ';
        }

        if (thousandIndex > 0) {
          chunkWords += thousands[thousandIndex] + ' ';
        }

        result = chunkWords + result;
      }

      intNumber ~/= 1000;
      thousandIndex++;
    }

    return result.trim();
  }

  // دالة البحث عن العميل بالهوية
  Future<void> _searchCustomerByIdentity() async {
    if (_identityController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _customerData = null;
      _showCustomerCard = false;
      _showPaymentForm = false;
      _showRequiredAmountForm = false;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: _identityController.text)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _customerData = {...doc.data(), 'docId': doc.id};
          _showCustomerCard = true;
          _showRequiredAmountForm = true; // إظهار نموذج المبلغ المستحق أولاً
        });

        // تحقق من وجود مبلغ مستحق مسبقاً
        await _checkExistingRequiredAmount();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لا يوجد عميل بهذا الرقم')));
      }
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

  // دالة حساب إجمالي المبلغ المدفوع
  Future<void> _calculateTotalPaidAmount() async {
    if (_unetData == null || _customerData == null) return;

    try {
      final querySnapshot =
          await _firestore
              .collection('financialTransactions')
              .where('pn', isEqualTo: _unetData!['pn'])
              .where('customerId', isEqualTo: _customerData!['identityNumber'])
              .get();

      double total = 0.0;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['debitCredit'] == 'له') {
          total += (data['amount'] ?? 0.0).toDouble();
        }
      }

      setState(() {
        _totalPaidAmount = total;
      });
    } catch (e) {
      print('خطأ في حساب المبلغ المدفوع: $e');
    }
  }

  // دالة تحديث النص عند تغيير المبلغ
  void _updateAmountInWords() {
    if (_paymentAmountController.text.isNotEmpty) {
      try {
        double amount = double.parse(_paymentAmountController.text);
        setState(() {
          _amountInWords = _convertNumberToWords(amount);
        });
      } catch (e) {
        setState(() {
          _amountInWords = '';
        });
      }
    } else {
      setState(() {
        _amountInWords = '';
      });
    }
  }

  // دالة إضافة الدفعة المالية
  Future<void> _addPayment() async {
    if (_paymentAmountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يرجى إدخال مبلغ الدفعة')));
      return;
    }

    if (_paymentDescriptionController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يرجى إدخال بيان الدفعة')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_paymentAmountController.text);

      // إنشاء hash للمعاملة
      final transactionHash = _generateTransactionHash(
        _customerData!['identityNumber'],
        amount,
        _paymentSelectedDate.toIso8601String(),
      );

      // إنشاء رقم الكود
      String cod = '';
      if (_contractData != null) {
        cod =
            '${_contractData!['projectNumber']}-${_contractData!['unitNumber']}';
      } else if (_unetData != null) {
        cod = _unetData!['pn'];
      }

      await _firestore.collection('financialTransactions').add({
        'amount': amount,
        'apartmentId': _unetData!['docId'],
        'cod': cod,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'النظام',
        'customerId': _customerData!['identityNumber'],
        'customerName': _customerData!['name'],
        'date': Timestamp.fromDate(_paymentSelectedDate),
        'debitCredit': 'له',
        'description': _paymentDescriptionController.text,
        'idNumber': _customerData!['identityNumber'],
        'independentOperationType': 'عادية',
        'isDeposit': false,
        'isIndependent': false,
        'lastModified': FieldValue.serverTimestamp(),
        'operationType': 'عادية',
        'pn': cod,
        'projectNumber': cod.split('-')[0],
        'transactionHash': transactionHash,
        'transactionType': 'نقدي',
        'unitNumber': cod.contains('-') ? cod.split('-')[1] : '',
        'referenceNumber': _referenceNumberController.text,
      });

      // إعادة حساب المبلغ المدفوع
      await _calculateTotalPaidAmount();

      // إعادة تعيين النموذج
      _paymentAmountController.clear();
      _paymentDescriptionController.clear();
      _referenceNumberController.clear();
      setState(() {
        _amountInWords = '';
        _paymentSelectedDate = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة الدفعة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      // التحقق من اكتمال المبلغ
      if (_totalPaidAmount >= _requiredAmount) {
        setState(() {
          _showPaymentDialog = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم استيفاء المبلغ المطلوب بالكامل'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إضافة الدفعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // دالة إنشاء hash للمعاملة
  String _generateTransactionHash(String idNumber, double amount, String date) {
    final String rawData =
        '$idNumber-$amount-${DateTime.parse(date).millisecondsSinceEpoch}';
    int hash = 0;
    for (int i = 0; i < rawData.length; i++) {
      hash = (hash * 31 + rawData.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toString();
  }
}
