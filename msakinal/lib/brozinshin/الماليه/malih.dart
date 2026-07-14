import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../login_page.dart';
import '1.dart';
import 'arth.dart';
import 'العرض.dart';
import 'العمليات_المستقلة.dart';

class FinancialOperationsPage extends StatefulWidget {
  const FinancialOperationsPage({super.key});

  @override
  _FinancialOperationsPageState createState() =>
      _FinancialOperationsPageState();
}

class _FinancialOperationsPageState extends State<FinancialOperationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _pnController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _cod = TextEditingController();

  List<Map<String, dynamic>> _customerApartments = [];
  Map<String, dynamic>? _selectedApartment;

  String? _customerName;
  String? _projectNumber;
  String? _transactionType = 'نقدى';
  String? _debitCredit = 'له';
  DateTime _selectedDate = DateTime.now();
  double _balance = 0.0;
  var amount;
  final List<String> _transactionTypes = ['نقدى', 'شيك', 'حوالة'];
  final List<String> _debitCreditTypes = ['له', 'عليه'];
  String _operationType = 'وحدة'; // 'وحدة' أو 'مستقلة'
  final List<String> _operationTypes = ['وحدة', 'مستقلة'];

  // إضافة متغيرات جديدة للعربون
  String _independentOperationType = 'دفعة عادية'; // 'دفعة عادية' أو 'عربون'
  final List<String> _independentOperationTypes = ['دفعة عادية', 'عربون'];
  String? _selectedProject;
  String? _selectedUnit;
  List<String> _availableProjects = [];
  List<Map<String, dynamic>> _availableUnits = [];

  // متغيرات حالة الحفظ
  bool isSaving = false;
  bool formSaved = false;
  bool isSaveHovered = false;
  bool isSearching = false;
  bool isSearchHovered = false;
  bool isButtonHovered = false;

  @override
  void dispose() {
    _pnController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _toggleOperationType(String type) {
    setState(() {
      _operationType = type;
      // إعادة تعيين قيم العربون عند تغيير نوع العملية
      if (type == 'مستقلة') {
        _independentOperationType = 'دفعة عادية';
        _selectedProject = null;
        _selectedUnit = null;
        _availableUnits = [];
      }
    });
  }

  // دالة جديدة لجلب المشاريع المتاحة
  Future<void> _fetchAvailableProjects() async {
    try {
      final projectsQuery =
          await FirebaseFirestore.instance.collection('apartments').get();

      Set<String> uniqueProjects = {};
      for (var doc in projectsQuery.docs) {
        if (doc.data().containsKey('projectNumber')) {
          uniqueProjects.add(doc['projectNumber']);
        }
      }

      if (mounted) {
        setState(() {
          _availableProjects = uniqueProjects.toList();
        });
      }
    } catch (e) {
      print('خطأ في جلب المشاريع: $e');
    }
  }

  // دالة جديدة لجلب الوحدات المتاحة في المشروع المحدد
  Future<void> _fetchAvailableUnits(String projectNumber) async {
    try {
      final unitsQuery =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .get();

      List<Map<String, dynamic>> units = [];
      for (var doc in unitsQuery.docs) {
        units.add({
          'number': doc['number'],
          'pn': doc['pn'],
          'projectNumber': doc['projectNumber'],
        });
      }

      if (mounted) {
        setState(() {
          _availableUnits = units;
          _selectedUnit = null; // إعادة تعيين الوحدة المحددة
        });
      }
    } catch (e) {
      print('خطأ في جلب الوحدات: $e');
    }
  }

  // دالة لعرض ديالوج العمليات المستقلة
  Future<void> _showIndependentOperationDialog() async {
    // جلب المشاريع المتاحة
    await _fetchAvailableProjects();

    // إعادة تعيين القيم
    if (mounted) {
      setState(() {
        _independentOperationType = 'دفعة عادية';
        _selectedProject = null;
        _selectedUnit = null;
        _availableUnits = [];
      });
    }

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('إضافة عملية مالية مستقلة'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نوع العملية المستقلة
                      Text(
                        'نوع العملية:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  _independentOperationType = 'دفعة عادية';
                                });
                                if (mounted) {
                                  setState(() {
                                    _independentOperationType = 'دفعة عادية';
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color:
                                      _independentOperationType == 'دفعة عادية'
                                          ? Colors.blue
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'دفعة عادية',
                                    style: TextStyle(
                                      color:
                                          _independentOperationType ==
                                                  'دفعة عادية'
                                              ? Colors.white
                                              : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  _independentOperationType = 'عربون';
                                });
                                if (mounted) {
                                  setState(() {
                                    _independentOperationType = 'عربون';
                                  });
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color:
                                      _independentOperationType == 'عربون'
                                          ? Colors.green
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    'عربون',
                                    style: TextStyle(
                                      color:
                                          _independentOperationType == 'عربون'
                                              ? Colors.white
                                              : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // حقول إضافية للعربون
                      if (_independentOperationType == 'عربون') ...[
                        Text(
                          'اختر المشروع:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        DropdownButton<String>(
                          value: _selectedProject,
                          isExpanded: true,
                          hint: Text('اختر المشروع'),
                          items:
                              _availableProjects.map((project) {
                                return DropdownMenuItem<String>(
                                  value: project,
                                  child: Text('مشروع $project'),
                                );
                              }).toList(),
                          onChanged: (selected) {
                            if (selected != null) {
                              setDialogState(() {
                                _selectedProject = selected;
                              });
                              if (mounted) {
                                setState(() {
                                  _selectedProject = selected;
                                });
                              }
                              _fetchAvailableUnits(selected);
                            }
                          },
                        ),
                        SizedBox(height: 16),

                        if (_selectedProject != null) ...[
                          Text(
                            'اختر الوحدة:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          DropdownButton<String>(
                            value: _selectedUnit,
                            isExpanded: true,
                            hint: Text('اختر الوحدة'),
                            items:
                                _availableUnits.map((unit) {
                                  return DropdownMenuItem<String>(
                                    value: unit['pn'],
                                    child: Text('وحدة ${unit['number']}'),
                                  );
                                }).toList(),
                            onChanged: (selected) {
                              if (selected != null) {
                                setDialogState(() {
                                  _selectedUnit = selected;
                                });
                                if (mounted) {
                                  setState(() {
                                    _selectedUnit = selected;
                                  });
                                }
                              }
                            },
                          ),
                        ],
                      ],

                      SizedBox(height: 16),
                      Text(
                        'المبلغ:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'المبلغ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'الوصف:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'الوصف',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // التحقق من صحة البيانات
                      if (_amountController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('الرجاء إدخال المبلغ')),
                        );
                        return;
                      }

                      final double? amount = double.tryParse(
                        _amountController.text,
                      );
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('الرجاء إدخال مبلغ صحيح أكبر من صفر'),
                          ),
                        );
                        return;
                      }

                      if (_independentOperationType == 'عربون' &&
                          (_selectedProject == null || _selectedUnit == null)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('الرجاء اختيار المشروع والوحدة'),
                          ),
                        );
                        return;
                      }

                      // إنشاء معرف فريد للعملية
                      String transactionId =
                          FirebaseFirestore.instance
                              .collection('financialTransactions')
                              .doc()
                              .id;

                      // إعداد بيانات العملية
                      var transactionData = {
                        'transactionId': transactionId,
                        'date': _selectedDate,
                        'customerName': _customerName,
                        'amount': amount,
                        'debitCredit': _debitCredit,
                        'idNumber': _idNumberController.text.trim(),
                        'description': _descriptionController.text.trim(),
                        'transactionType': _transactionType,
                        'operationType': 'مستقلة',
                        'independentOperationType': _independentOperationType,
                        'isIndependent': true,
                        'createdAt': FieldValue.serverTimestamp(),
                        'createdBy':
                            FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                        'lastModified': FieldValue.serverTimestamp(),
                      };

                      // إضافة بيانات العربون إذا كان نوع العملية عربون
                      if (_independentOperationType == 'عربون') {
                        // البحث عن الوحدة المحددة
                        Map<String, dynamic>? selectedUnitData;
                        for (var unit in _availableUnits) {
                          if (unit['pn'] == _selectedUnit) {
                            selectedUnitData = unit;
                            break;
                          }
                        }

                        if (selectedUnitData != null) {
                          transactionData.addAll({
                            'projectNumber': _selectedProject,
                            'pn': _selectedUnit,
                            'unitNumber': selectedUnitData['number'],
                            'isDeposit': true,
                          });

                          // تحديث حالة الوحدة إلى محجوزة
                          try {
                            final unitQuery =
                                await FirebaseFirestore.instance
                                    .collection('apartments')
                                    .where('pn', isEqualTo: _selectedUnit)
                                    .limit(1)
                                    .get();

                            if (unitQuery.docs.isNotEmpty) {
                              await unitQuery.docs.first.reference.update({
                                'status': 'محجوز',
                                'clientIdentity':
                                    _idNumberController.text.trim(),
                                'clientName': _customerName,
                              });
                            }
                          } catch (e) {
                            print('خطأ في تحديث حالة الوحدة: $e');
                          }
                        }
                      } else {
                        // إذا كانت دفعة عادية، نضيف pn افتراضي
                        transactionData['pn'] = '000-0';
                      }

                      // إضافة العملية المالية إلى قاعدة البيانات
                      await FirebaseFirestore.instance
                          .collection('financialTransactions')
                          .add(transactionData);

                      // مسح حقول الإدخال
                      _amountController.clear();
                      _descriptionController.clear();

                      // إغلاق الديالوج
                      Navigator.pop(context);

                      // إظهار رسالة نجاح للمستخدم
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم حفظ العملية بنجاح')),
                      );
                    },
                    child: Text('حفظ'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _searchByIdentityNumber() async {
    if (_idNumberController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يرجى إدخال رقم الهوية للبحث')));
      return;
    }

    final idNumber = _idNumberController.text.trim();

    try {
      bool foundCustomer = false;
      bool foundApartments = false;
      bool foundApartments1 = false;
      String pn;

      // البحث في جدول العملاء
      final customerQuery =
          await FirebaseFirestore.instance
              .collection('customers')
              .where('identityNumber', isEqualTo: idNumber)
              .get();

      if (customerQuery.docs.isNotEmpty) {
        setState(() {
          _customerName = customerQuery.docs.first['name'];
        });
        foundCustomer = true;
      }

      // البحث عن الوحدات المرتبطة بنفس رقم الهوية
      final apartmentQuery =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('clientIdentity', isEqualTo: idNumber)
              .get();

      if (apartmentQuery.docs.isNotEmpty) {
        setState(() {
          _customerApartments =
              apartmentQuery.docs.map((doc) {
                return {
                  'pn': doc['pn'],
                  'projectNumber': doc['projectNumber'],
                  'unitNumber': doc['number'],
                };
              }).toList();
          _selectedApartment =
              _customerApartments.first; // اختيار أول وحدة افتراضيًا
          _pnController.text = _selectedApartment?['pn'] ?? '';
          _projectNumber = _selectedApartment?['projectNumber'] ?? '';
        });
        foundApartments = true;
      }
      _cod.value = TextEditingValue(
        text:
            "${_selectedApartment!['projectNumber'] + _selectedApartment!['pn']}",
      );
      setState(() {});
      pn =
          apartmentQuery.docs.isNotEmpty
              ? apartmentQuery.docs.first['pn']
              : '115';
      final transactionsQuery =
          await FirebaseFirestore.instance
              .collection('financialTransactions')
              .where('pn', isEqualTo: pn)
              .get();

      if (transactionsQuery.docs.isNotEmpty) {
        double balance = 0.0;
        for (var doc in transactionsQuery.docs) {
          final amount =
              doc['amount'] is int
                  ? (doc['amount'] as int).toDouble()
                  : doc['amount'] as double;
          final type = doc['debitCredit'] as String;
          balance += type == 'له' ? amount : -amount;
        }
        setState(() {
          _balance = balance;
        });
        foundApartments1 = true;
      } else {
        setState(() {
          _balance = 0.0;
        });
      }

      if (!foundCustomer || !foundApartments) {
        String msg = '';
        if (!foundCustomer) msg += 'لم يتم العثور على العميل. ';
        if (!foundApartments) msg += 'لم يتم العثور على وحدات مرتبطة. ';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text(msg)),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم جلب البيانات بنجاح! ✨'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('حدث خطأ أثناء جلب البيانات: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // التحقق من إدخال البيانات المطلوبة حسب نوع العملية
    if (_operationType == 'وحدة' &&
        (_idNumberController.text.isEmpty ||
            _customerName == null ||
            _selectedApartment == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء البحث وتحديد الوحدة أولاً')),
      );
      return;
    } else if (_operationType == 'مستقلة' &&
        (_idNumberController.text.isEmpty || _customerName == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('الرجاء البحث عن العميل أولاً')));
      return;
    }

    // إذا كانت العملية مستقلة، نعرض ديالوج العمليات المستقلة
    if (_operationType == 'مستقلة') {
      await _showIndependentOperationDialog();
      return;
    }

    // التحقق من صحة المبلغ
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('الرجاء إدخال المبلغ')));
      return;
    }

    // بدء عملية الحفظ
    if (mounted) {
      setState(() {
        isSaving = true;
        formSaved = false;
      });
    }

    try {
      // التحقق من أن المبلغ رقم صحيح
      amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('الرجاء إدخال مبلغ صحيح أكبر من صفر')),
        );
        return;
      }

      // إنشاء معرف فريد للعملية
      String transactionId =
          FirebaseFirestore.instance
              .collection('financialTransactions')
              .doc()
              .id;

      // إعداد بيانات العملية مع تحسين الأمان
      var transactionData = {
        'transactionId': transactionId,
        'date': _selectedDate,
        'customerName': _customerName,
        'amount': amount,
        'cod': _cod.text.trim(),
        'debitCredit': _debitCredit,
        'idNumber': _idNumberController.text.trim(),
        'description': _descriptionController.text.trim(),
        'transactionType': _transactionType,
        'operationType': _operationType,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'lastModified': FieldValue.serverTimestamp(),
      };
      setState(() {});

      if (_operationType == 'وحدة' && _selectedApartment != null) {
        // إضافة بيانات الوحدة للعملية المالية
        transactionData.addAll({
          'pn': _selectedApartment?['pn'],
          'projectNumber': _selectedApartment?['projectNumber'],
          'unitNumber': _selectedApartment?['unitNumber'],
          'customerId':
              _idNumberController.text.trim(), // إضافة رقم هوية العميل للربط
        });

        // تحديث بيانات الوحدة والعقد إذا كانت العملية له
        if (_debitCredit == 'له' || _debitCredit == 'لة') {
          try {
            final unitQuery =
                await FirebaseFirestore.instance
                    .collection('apartments')
                    .where('pn', isEqualTo: _selectedApartment?['pn'])
                    .limit(1)
                    .get();

            if (unitQuery.docs.isNotEmpty) {
              final unitDoc = unitQuery.docs.first;
              final unitData = unitDoc.data();
              final double currentPaid =
                  unitData['paidAmount'] is int
                      ? (unitData['paidAmount'] as int).toDouble()
                      : (unitData['paidAmount'] ?? 0.0);

              await unitDoc.reference.update({
                'paidAmount': currentPaid + amount,
              });
            }
          } catch (e) {
            print('خطأ في تحديث بيانات الوحدة: $e');
          }

          try {
            final contractQuery =
                await FirebaseFirestore.instance
                    .collection('contracts')
                    .where('pn', isEqualTo: _selectedApartment?['pn'])
                    .limit(1)
                    .get();

            if (contractQuery.docs.isNotEmpty) {
              final contractDoc = contractQuery.docs.first;
              final contractData = contractDoc.data();
              final double currentPaid =
                  contractData['paidAmount'] is int
                      ? (contractData['paidAmount'] as int).toDouble()
                      : (contractData['paidAmount'] ?? 0.0);
              await contractDoc.reference.update({
                'paidAmount': currentPaid + amount,
              });
            }
          } catch (e) {
            print('خطأ في تحديث بيانات العقد: $e');
          }
        }

        // إضافة العملية المالية إلى قاعدة البيانات
        await FirebaseFirestore.instance
            .collection('financialTransactions')
            .add(transactionData);
      } else if (_operationType == 'مستقلة') {
        // إضافة معلومات إضافية للعملية المستقلة
        transactionData.addAll({
          'isIndependent': true,
          'customerId':
              _idNumberController.text.trim(), // إضافة رقم هوية العميل للربط
        });

        // إضافة العملية المالية للعميل مباشرة دون ارتباط بوحدة
        await FirebaseFirestore.instance
            .collection('financialTransactions')
            .add(transactionData);
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

      // إنهاء عملية الحفظ وإظهار النجاح
      if (mounted) {
        setState(() {
          isSaving = false;
          formSaved = true;
        });
      }

      // إظهار رسالة نجاح للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('تم حفظ العملية بنجاح! 🎉'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // إعادة تعيين حالة النجاح بعد 3 ثوان
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            formSaved = false;
          });
        }
      });
    } catch (e) {
      print('خطأ في حفظ العملية المالية: $e');

      // إنهاء عملية الحفظ في حالة الخطأ
      if (mounted) {
        setState(() {
          isSaving = false;
          formSaved = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('حدث خطأ أثناء حفظ العملية'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Future<void> selectDate(BuildContext context) async {
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

    double saveButtonElevation = 4;
    String? searchPn;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn1",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FinancialTransactionsPage1(),
                ),
              );
            },
            tooltip: 'كشف حساب العميل',
            backgroundColor: Colors.blue,
            child: Icon(Icons.attach_money, color: Colors.white),
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btn2",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ContractsScreenl()),
              );
            },
            tooltip: 'العقود',
            backgroundColor: Colors.green,
            child: Icon(Icons.account_balance_wallet, color: Colors.white),
          ),
        ],
      ),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              try {
                // تسجيل الخروج من Firebase
                await FirebaseAuth.instance.signOut();

                // إعادة ضبط حالة المستخدم إن كنت تستخدم Provider (اختياري)
                // context.read<UserProvider>().logout();  // إذا كان عندك UserProvider

                // الانتقال إلى صفحة تسجيل الدخول واستبدال كل الصفحات السابقة
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen1()),
                );
              } catch (e) {
                print('خطأ أثناء تسجيل الخروج: $e');
              }
            },
          ),
        ],
        title: Text('سجل العمليات المالية'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اختيار نوع العملية المالية
                Container(
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.indigo.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'نوع العملية المالية',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _toggleOperationType('وحدة'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient:
                                            _operationType == 'وحدة'
                                                ? LinearGradient(
                                                  colors: [
                                                    Colors.blue.shade600,
                                                    Colors.blue.shade800,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                                : null,
                                        color:
                                            _operationType != 'وحدة'
                                                ? Colors.white
                                                : null,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              _operationType == 'وحدة'
                                                  ? Colors.blue.shade600
                                                  : Colors.grey.shade300,
                                          width: 2,
                                        ),
                                        boxShadow:
                                            _operationType == 'وحدة'
                                                ? [
                                                  BoxShadow(
                                                    color: Colors.blue
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                    offset: Offset(0, 3),
                                                  ),
                                                ]
                                                : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.home_work,
                                            color:
                                                _operationType == 'وحدة'
                                                    ? Colors.white
                                                    : Colors.blue.shade600,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'مرتبطة بوحدة',
                                            style: TextStyle(
                                              color:
                                                  _operationType == 'وحدة'
                                                      ? Colors.white
                                                      : Colors.blue.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _toggleOperationType('مستقلة'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient:
                                            _operationType == 'مستقلة'
                                                ? LinearGradient(
                                                  colors: [
                                                    Colors.green.shade600,
                                                    Colors.green.shade800,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                                : null,
                                        color:
                                            _operationType != 'مستقلة'
                                                ? Colors.white
                                                : null,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              _operationType == 'مستقلة'
                                                  ? Colors.green.shade600
                                                  : Colors.grey.shade300,
                                          width: 2,
                                        ),
                                        boxShadow:
                                            _operationType == 'مستقلة'
                                                ? [
                                                  BoxShadow(
                                                    color: Colors.green
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                    offset: Offset(0, 3),
                                                  ),
                                                ]
                                                : [],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.account_tree,
                                            color:
                                                _operationType == 'مستقلة'
                                                    ? Colors.white
                                                    : Colors.green.shade600,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'مستقلة',
                                            style: TextStyle(
                                              color:
                                                  _operationType == 'مستقلة'
                                                      ? Colors.white
                                                      : Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // أولاً: أضف هذا المتغير أعلى كلاس State

                // ثم استخدم هذا الويدجت بدلاً من ElevatedButton
                MouseRegion(
                  onEnter: (_) {
                    if (mounted) setState(() => isButtonHovered = true);
                  },
                  onExit: (_) {
                    if (mounted) setState(() => isButtonHovered = false);
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 400),
                    curve: Curves.fastOutSlowIn,
                    height: 56,
                    width: isButtonHovered ? 220 : 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.indigo.shade600,
                          Colors.blueAccent.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow:
                          isButtonHovered
                              ? [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.6),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: Offset(0, 5),
                                ),
                              ]
                              : [
                                BoxShadow(
                                  color: Colors.indigo.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          // تأثير اهتزاز عند الضغط
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration: Duration(milliseconds: 800),
                              pageBuilder:
                                  (_, __, ___) => FinancialTransactionsPage(),
                              transitionsBuilder: (_, animation, __, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        splashColor: Colors.white.withOpacity(0.2),
                        highlightColor: Colors.transparent,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_tree_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                child:
                                    isButtonHovered
                                        ? Text(
                                          'انتقل إلى العمليات المالية',
                                          key: ValueKey('long-text'),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 2,
                                                offset: Offset(1, 1),
                                              ),
                                            ],
                                          ),
                                        )
                                        : Text(
                                          'العمليات المالية',
                                          key: ValueKey('short-text'),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                              SizedBox(width: isButtonHovered ? 8 : 0),
                              AnimatedOpacity(
                                duration: Duration(milliseconds: 300),
                                opacity: isButtonHovered ? 1.0 : 0.0,
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // حقل البحث بـ PN
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _idNumberController,
                          onFieldSubmitted: (value) async {
                            if (value.isNotEmpty && !isSearching) {
                              if (mounted) setState(() => isSearching = true);
                              await _searchByIdentityNumber();
                              if (mounted) setState(() => isSearching = false);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'رقم الهويه',
                            labelStyle: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person_search,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                            ),
                            suffixIcon:
                                isSearching
                                    ? Container(
                                      margin: EdgeInsets.all(12),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue.shade600,
                                            ),
                                      ),
                                    )
                                    : (_customerName != null &&
                                        _customerName!.isNotEmpty)
                                    ? Container(
                                      margin: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade600,
                                        size: 20,
                                      ),
                                    )
                                    : Container(
                                      margin: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.search,
                                        color: Colors.grey.shade600,
                                        size: 20,
                                      ),
                                    ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade600,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'اضغط Enter للبحث',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال رقم الهويه';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    // أضف هذه المتغيرات في أعلى State

                    // استبدل ElevatedButton بهذا الكود
                    MouseRegion(
                      onEnter: (_) {
                        if (mounted) setState(() => isSearchHovered = true);
                      },
                      onExit: (_) {
                        if (mounted) setState(() => isSearchHovered = false);
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 400),
                        curve: Curves.easeInOutBack,
                        width: isSearching ? 50 : (isSearchHovered ? 120 : 100),
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            isSearching ? 25 : 12,
                          ),
                          gradient: LinearGradient(
                            colors:
                                isSearching
                                    ? [
                                      Colors.blue.shade700,
                                      Colors.blue.shade900,
                                    ]
                                    : [
                                      Colors.tealAccent.shade400,
                                      Colors.blue.shade600,
                                    ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(
                                isSearchHovered ? 0.6 : 0.3,
                              ),
                              blurRadius: isSearchHovered ? 15 : 8,
                              spreadRadius: isSearchHovered ? 2 : 1,
                              offset: Offset(0, isSearchHovered ? 4 : 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              isSearching ? 25 : 12,
                            ),
                            onTap: () async {
                              if (isSearching) return;

                              if (mounted) setState(() => isSearching = true);
                              await _searchByIdentityNumber();
                              if (mounted) setState(() => isSearching = false);
                            },
                            splashColor: Colors.white.withOpacity(0.3),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // نص البحث (يختفي عند البحث)
                                AnimatedOpacity(
                                  duration: Duration(milliseconds: 200),
                                  opacity: isSearching ? 0 : 1,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.search,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'بحث',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // مؤشر التحميل (يظهر أثناء البحث)
                                if (isSearching)
                                  CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),

                                // أيقونة النجاح (تظهر بعد البحث)
                                if (!isSearching &&
                                    searchPn != null &&
                                    searchPn.isNotEmpty)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade600,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                if (_customerApartments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اختر الوحدة:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        DropdownButton<Map<String, dynamic>>(
                          value: _selectedApartment,
                          isExpanded: true,
                          hint: Text('اختر وحدة'),
                          items:
                              _customerApartments.map((apartment) {
                                final unit =
                                    apartment['unitNumber'] ?? 'غير معروف';
                                final project =
                                    apartment['projectNumber'] ?? 'غير معروف';
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: apartment,
                                  child: Text('مشروع $project - وحدة $unit'),
                                );
                              }).toList(),
                          onChanged: (selected) {
                            if (mounted) {
                              setState(() {
                                _selectedApartment = selected;
                                _pnController.text = selected?['pn'] ?? '';
                                _projectNumber =
                                    selected?['projectNumber'] ?? '';
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 20),

                // معلومات العميل
                if (_customerName != null) ...[
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.indigo.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'معلومات العميل',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.person_outline,
                            'اسم العميل',
                            _customerName!,
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.credit_card,
                            'رقم الهوية',
                            _idNumberController.text,
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.business,
                            'مركز التكلفة',
                            _projectNumber ?? 'غير محدد',
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.account_balance_wallet,
                            'الرصيد الحالي',
                            '${_balance.toStringAsFixed(2)} ريال',
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _cod,
                    decoration: InputDecoration(
                      labelText: 'المرجع',
                      labelStyle: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.confirmation_number,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال المرجع';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),
                // تاريخ العملية
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'تاريخ العملية',
                        labelStyle: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Container(
                          margin: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade600,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('yyyy-MM-dd').format(_selectedDate),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.blue.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // نوع العملية
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _debitCredit,
                    decoration: InputDecoration(
                      labelText: 'نوع العملية',
                      labelStyle: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.swap_horiz,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items:
                        _debitCreditTypes.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (newValue) {
                      if (mounted) {
                        setState(() {
                          _debitCredit = newValue;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(height: 20),

                // المبلغ
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'المبلغ',
                      labelStyle: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.attach_money,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال المبلغ';
                      }
                      if (double.tryParse(value) == null) {
                        return 'الرجاء إدخال رقم صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),

                // طريقة الدفع
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _transactionType,
                    decoration: InputDecoration(
                      labelText: 'طريقة الدفع',
                      labelStyle: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.payment,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items:
                        _transactionTypes.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (newValue) {
                      if (mounted) {
                        setState(() {
                          _transactionType = newValue;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(height: 20),

                // الوصف
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'الوصف / البيان',
                      labelStyle: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.description,
                          color: Colors.purple.shade600,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.blue.shade600,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال وصف العملية';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 30),

                // زر الحفظ المحسن
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors:
                            isSaving
                                ? [Colors.grey.shade500, Colors.grey.shade700]
                                : formSaved
                                ? [Colors.green.shade500, Colors.green.shade700]
                                : isSaveHovered
                                ? [Colors.blue.shade700, Colors.indigo.shade800]
                                : [Colors.blue.shade600, Colors.blue.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isSaving
                                  ? Colors.grey.withOpacity(0.3)
                                  : formSaved
                                  ? Colors.green.withOpacity(0.4)
                                  : Colors.blue.withOpacity(0.4),
                          blurRadius: isSaveHovered ? 15 : 10,
                          spreadRadius: isSaveHovered ? 3 : 2,
                          offset: Offset(0, isSaveHovered ? 6 : 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: isSaving ? null : _submitForm,
                        onHover: (hovering) {
                          if (mounted) {
                            setState(() {
                              isSaveHovered = hovering;
                            });
                          }
                        },
                        splashColor: Colors.white.withOpacity(0.3),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: Container(
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            transitionBuilder: (
                              Widget child,
                              Animation<double> animation,
                            ) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child:
                                isSaving
                                    ? Row(
                                      key: ValueKey('saving'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          'جاري الحفظ...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    )
                                    : formSaved
                                    ? Row(
                                      key: ValueKey('saved'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.25,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          'تم الحفظ بنجاح',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Row(
                                      key: ValueKey('save'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.25,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.save_alt_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          'حفظ العملية',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 3,
                                                offset: Offset(1, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600, size: 20),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
