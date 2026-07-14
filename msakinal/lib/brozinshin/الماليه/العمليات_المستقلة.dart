import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IndependentFinancialOperationsPage extends StatefulWidget {
  const IndependentFinancialOperationsPage({super.key});

  @override
  _IndependentFinancialOperationsPageState createState() =>
      _IndependentFinancialOperationsPageState();
}

class _IndependentFinancialOperationsPageState
    extends State<IndependentFinancialOperationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _apartmentSearchController = TextEditingController();

  String? _customerName;
  String? _transactionType = 'نقدي';
  String? _debitCredit = 'له';
  String? _operationType = 'عادية'; // جديد
  String? _selectedApartmentPn; // جديد
  String? _selectedApartmentId; // جديد
  DateTime _selectedDate = DateTime.now();
  double _balance = 0.0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableApartments = []; // جديد
  List<Map<String, dynamic>> _filteredApartments = []; // جديد

  final List<String> _transactionTypes = ['نقدي', 'شيك', 'حوالة'];
  final List<String> _debitCreditTypes = ['له', 'عليه'];
  final List<String> _operationTypes = ['عادية', 'عربون']; // جديد

  @override
  void initState() {
    super.initState();
    _loadAvailableApartments(); // تحميل الشقق المتاحة
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _idNumberController.dispose();
    _apartmentSearchController.dispose();
    super.dispose();
  }

  // تحميل الشقق المتاحة
  Future<void> _loadAvailableApartments() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('apartments') // اسم الجدول الصحيح للوحدات
              .where('status', isEqualTo: 'متاح')
              .get();

      if (mounted) {
        setState(() {
          _availableApartments =
              querySnapshot.docs
                  .map(
                    (doc) => {
                      'pn': doc['pn'],
                      'number': doc['number'],
                      'projectNumber': doc['projectNumber'],
                      'id': doc.id, // تخزين معرف الوثيقة
                      'data': doc.data(),
                    },
                  )
                  .toList();
          _filteredApartments = _availableApartments;
        });
      }
    } catch (e) {
      print('خطأ في تحميل الشقق: $e');
    }
  }

  // البحث في الشقق المتاحة
  void _searchApartments(String query) {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _filteredApartments = _availableApartments;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _filteredApartments =
            _availableApartments
                .where(
                  (apartment) =>
                      apartment['pn'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      apartment['number'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      apartment['projectNumber']
                          .toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                )
                .toList();
      });
    }
  }

  Future<void> _searchByIdentityNumber() async {
    if (_idNumberController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يرجى إدخال رقم الهوية للبحث')));
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final idNumber = _idNumberController.text.trim();

    try {
      // البحث في جدول العملاء
      final customerQuery =
          await FirebaseFirestore.instance
              .collection('customers')
              .where('identityNumber', isEqualTo: idNumber)
              .get();

      if (customerQuery.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _customerName = customerQuery.docs.first['name'];
          });
        }

        // حساب الرصيد من العمليات المالية المستقلة
        List<QueryDocumentSnapshot> allTransactions = [];

        // البحث باستخدام idNumber
        final transactionsQuery1 =
            await FirebaseFirestore.instance
                .collection('financialTransactions')
                .where('idNumber', isEqualTo: idNumber)
                .where('isIndependent', isEqualTo: true)
                .orderBy('date', descending: true)
                .get();
        allTransactions.addAll(transactionsQuery1.docs);

        // البحث باستخدام customerId
        final transactionsQuery2 =
            await FirebaseFirestore.instance
                .collection('financialTransactions')
                .where('customerId', isEqualTo: idNumber)
                .where('isIndependent', isEqualTo: true)
                .orderBy('date', descending: true)
                .get();

        // إضافة النتائج مع تجنب التكرار
        for (var doc in transactionsQuery2.docs) {
          if (!allTransactions.any((existing) => existing.id == doc.id)) {
            allTransactions.add(doc);
          }
        }

        if (allTransactions.isNotEmpty) {
          double balance = 0.0;
          for (var doc in allTransactions) {
            final amount =
                doc['amount'] is int
                    ? (doc['amount'] as int).toDouble()
                    : doc['amount'] as double;
            final type = doc['debitCredit'] as String;
            balance += (type == 'له' || type == 'لة') ? amount : -amount;
          }
          if (mounted) {
            setState(() {
              _balance = balance;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _balance = 0.0;
            });
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم العثور على العميل: $_customerName')),
        );
      } else {
        if (mounted) {
          setState(() {
            _customerName = null;
            _balance = 0.0;
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لم يتم العثور على العميل')));
      }
    } catch (e) {
      print('خطأ في البحث: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء البحث: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idNumberController.text.isEmpty || _customerName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('الرجاء البحث عن العميل أولاً')));
      return;
    }

    // التحقق من اختيار الشقة في حالة العربون
    if (_operationType == 'عربون' && _selectedApartmentPn == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('الرجاء اختيار الشقة للعربون')));
      return;
    }

    // التحقق من صحة المبلغ
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('الرجاء إدخال المبلغ')));
      return;
    }

    // التحقق من أن المبلغ رقم صحيح وأكبر من صفر
    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من صفر')),
      );
      return;
    }

    // طلب تأكيد من المستخدم قبل إجراء العملية
    bool confirmOperation =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('تأكيد العملية المالية'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('هل أنت متأكد من إجراء هذه العملية؟'),
                    SizedBox(height: 10),
                    Text(
                      'العميل: $_customerName',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('المبلغ: ${amount.toStringAsFixed(2)} ر.س'),
                    Text('نوع العملية: $_debitCredit'),
                    Text('طريقة الدفع: $_transactionType'),
                    Text(
                      'نوع العملية: $_operationType',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_operationType == 'عربون' &&
                        _selectedApartmentPn != null)
                      Text(
                        'رقم الشقة: $_selectedApartmentPn',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text('تأكيد'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmOperation) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // إنشاء معرف فريد للعملية
      String transactionId =
          FirebaseFirestore.instance
              .collection('financialTransactions')
              .doc()
              .id;

      // إعداد بيانات العملية مع تحسين الأمان
      final transactionData = {
        'transactionId': transactionId,
        'date': _selectedDate,
        'customerName': _customerName,
        'amount': amount,
        'debitCredit': _debitCredit,
        'idNumber': _idNumberController.text.trim(),
        'customerId': _idNumberController.text.trim(),
        'description': _descriptionController.text.trim(),
        'transactionType': _transactionType,
        'operationType': _operationType, // جديد
        'independentOperationType': _operationType, // إضافة هذا الحقل للطباعة
        'isIndependent': true,
        'isDeposit': _operationType == 'عربون', // جديد
        'apartmentPn':
            _operationType == 'عربون' ? _selectedApartmentPn : null, // جديد
        'apartmentId':
            _operationType == 'عربون' ? _selectedApartmentId : null, // جديد
        'projectNumber':
            _operationType == 'عربون'
                ? _selectedApartmentPn?.split('-')[0]
                : null, // استخراج رقم المشروع
        'unitNumber':
            _operationType == 'عربون'
                ? _selectedApartmentPn?.split('-')[1]
                : null, // استخراج رقم الوحدة
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseFirestore.instance.app.options.projectId,
        'lastModified': FieldValue.serverTimestamp(),
        'transactionHash': _generateTransactionHash(
          _idNumberController.text.trim(),
          amount,
          _selectedDate,
        ),
      };

      // إضافة العملية المالية إلى قاعدة البيانات
      await FirebaseFirestore.instance
          .collection('financialTransactions')
          .doc(transactionId)
          .set(transactionData);

      // في حالة العربون، تحديث بيانات الشقة
      if (_operationType == 'عربون' && _selectedApartmentId != null) {
        await FirebaseFirestore.instance
            .collection('apartments') // اسم الجدول الصحيح
            .doc(_selectedApartmentId)
            .update({
              'status': 'محجوز',
              'clientName': _customerName,
              'depositAmount': amount,
              'clientIdentity': _idNumberController.text.trim(),
              'depositDate': _selectedDate,
              'reservedAt': FieldValue.serverTimestamp(),
            });
      }

      // تحديث الرصيد في واجهة المستخدم
      if (mounted) {
        setState(() {
          _balance +=
              (_debitCredit == 'له' || _debitCredit == 'لة') ? amount : -amount;
        });
      }

      // مسح حقول الإدخال
      _amountController.clear();
      _descriptionController.clear();
      if (_operationType == 'عربون') {
        _apartmentSearchController.clear();
        _selectedApartmentPn = null;
        _selectedApartmentId = null;
        _loadAvailableApartments(); // إعادة تحميل الشقق المتاحة
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _operationType == 'عربون'
                ? 'تم حفظ العربون وحجز الشقة بنجاح'
                : 'تم حفظ العملية بنجاح',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('خطأ في حفظ العملية: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ العملية: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  String _generateTransactionHash(
    String idNumber,
    double amount,
    DateTime date,
  ) {
    final String rawData = '$idNumber-$amount-${date.millisecondsSinceEpoch}';
    int hash = 0;
    for (int i = 0; i < rawData.length; i++) {
      hash = (hash * 31 + rawData.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('العمليات المالية المستقلة'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.blue.shade800, Colors.blue.shade600],
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // اختيار نوع العملية
                        Card(
                          elevation: 3,
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'نوع العملية:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  children:
                                      _operationTypes.map((type) {
                                        return Expanded(
                                          child: RadioListTile<String>(
                                            title: Text(type),
                                            value: type,
                                            groupValue: _operationType,
                                            onChanged: (value) {
                                              if (mounted) {
                                                setState(() {
                                                  _operationType = value;
                                                  // مسح بيانات الشقة عند تغيير النوع
                                                  if (value != 'عربون') {
                                                    _selectedApartmentPn = null;
                                                    _selectedApartmentId = null;
                                                    _apartmentSearchController
                                                        .clear();
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // اختيار الشقة (في حالة العربون فقط)
                        if (_operationType == 'عربون')
                          Card(
                            elevation: 3,
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'اختيار الشقة:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  TextFormField(
                                    controller: _apartmentSearchController,
                                    decoration: InputDecoration(
                                      labelText:
                                          'بحث برقم الشقة أو رقم الوحدة أو رقم المشروع',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.search),
                                      suffixIcon:
                                          _selectedApartmentPn != null
                                              ? Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                              )
                                              : null,
                                      hintText:
                                          'اكتب للبحث وعرض قائمة الشقق المتاحة',
                                    ),
                                    onChanged: _searchApartments,
                                  ),
                                  if ((_filteredApartments.isNotEmpty ||
                                          _apartmentSearchController
                                              .text
                                              .isNotEmpty) &&
                                      _selectedApartmentPn == null)
                                    Container(
                                      margin: EdgeInsets.only(top: 8),
                                      height: 200,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        itemCount: _filteredApartments.length,
                                        itemBuilder: (context, index) {
                                          final apartment =
                                              _filteredApartments[index];
                                          return ListTile(
                                            title: Text(
                                              'وحدة ${apartment['number']} - مشروع ${apartment['projectNumber']}',
                                            ),
                                            subtitle: Text(
                                              'رقم الوحدة: ${apartment['pn']}',
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _selectedApartmentPn =
                                                    apartment['pn'].toString();
                                                _selectedApartmentId =
                                                    apartment['id'];
                                                _apartmentSearchController
                                                        .text =
                                                    apartment['pn'].toString();
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  if (_selectedApartmentPn != null)
                                    Container(
                                      margin: EdgeInsets.only(top: 8),
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.apartment,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'الشقة المختارة: $_selectedApartmentPn',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // بحث العميل
                        Card(
                          elevation: 3,
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'بحث عن العميل:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _idNumberController,
                                        decoration: InputDecoration(
                                          labelText: 'رقم الهوية',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: _searchByIdentityNumber,
                                      icon: Icon(Icons.search),
                                      label: Text('بحث'),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_customerName != null) ...[
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              color: Colors.blue,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'اسم العميل: $_customerName',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              color: Colors.green,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'الرصيد الحالي: ${_balance.toStringAsFixed(2)} ريال',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // تفاصيل العملية المالية
                        if (_customerName != null)
                          Card(
                            elevation: 3,
                            margin: EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تفاصيل العملية المالية:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // التاريخ
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _selectDate(context),
                                          child: InputDecorator(
                                            decoration: InputDecoration(
                                              labelText: 'التاريخ',
                                              border: OutlineInputBorder(),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  DateFormat(
                                                    'yyyy/MM/dd',
                                                  ).format(_selectedDate),
                                                ),
                                                Icon(Icons.calendar_today),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  // المبلغ
                                  TextFormField(
                                    controller: _amountController,
                                    decoration: InputDecoration(
                                      labelText:
                                          _operationType == 'عربون'
                                              ? 'مبلغ العربون'
                                              : 'المبلغ',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.attach_money),
                                    ),
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال المبلغ';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'يرجى إدخال رقم صحيح';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  // الوصف
                                  TextFormField(
                                    controller: _descriptionController,
                                    decoration: InputDecoration(
                                      labelText: 'الوصف',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.description),
                                    ),
                                    maxLines: 2,
                                  ),
                                  SizedBox(height: 16),
                                  // نوع العملية
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('نوع العملية:'),
                                            SizedBox(height: 8),
                                            DropdownButtonFormField<String>(
                                              value: _transactionType,
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                              ),
                                              items:
                                                  _transactionTypes
                                                      .map(
                                                        (type) =>
                                                            DropdownMenuItem(
                                                              value: type,
                                                              child: Text(type),
                                                            ),
                                                      )
                                                      .toList(),
                                              onChanged: (value) {
                                                if (mounted) {
                                                  setState(() {
                                                    _transactionType = value;
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('له/عليه:'),
                                            SizedBox(height: 8),
                                            DropdownButtonFormField<String>(
                                              value: _debitCredit,
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                              ),
                                              items:
                                                  _debitCreditTypes
                                                      .map(
                                                        (type) =>
                                                            DropdownMenuItem(
                                                              value: type,
                                                              child: Text(type),
                                                            ),
                                                      )
                                                      .toList(),
                                              onChanged: (value) {
                                                if (mounted) {
                                                  setState(() {
                                                    _debitCredit = value;
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 24),
                                  // زر الحفظ
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: _submitForm,
                                      icon: Icon(
                                        _operationType == 'عربون'
                                            ? Icons.home
                                            : Icons.save,
                                      ),
                                      label: Text(
                                        _operationType == 'عربون'
                                            ? 'حفظ العربون وحجز الشقة'
                                            : 'حفظ العملية',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            _operationType == 'عربون'
                                                ? Colors.orange
                                                : Colors.blue,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 32,
                                        ),
                                        textStyle: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
