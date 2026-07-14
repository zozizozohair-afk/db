import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinancialTransactionsPage extends StatefulWidget {
  const FinancialTransactionsPage({super.key});

  @override
  _FinancialTransactionsPageState createState() =>
      _FinancialTransactionsPageState();
}

class _FinancialTransactionsPageState extends State<FinancialTransactionsPage> {
  String? _searchPn;
  List<QueryDocumentSnapshot> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingAll = false;
  double _balance = 0.0;
  String _clientName = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String? _currentSearchCode; // لمنع التداخل في عمليات البحث

  // متغيرات الفلاتر الجديدة
  String _selectedFilter = 'الكل'; // الكل، مرتبطة بشقة، غير مرتبطة، مستقلة
  bool _showFilters = false;
  bool _hasLoadedAllTransactions = false;

  @override
  void initState() {
    super.initState();
    // لا نجلب البيانات عند بدء التشغيل لتحسين الأداء
  }

  Future<void> _fetchInitialTransactions() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('financialTransactions')
              .get();
      if (mounted) setState(() => _transactions = querySnapshot.docs);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAllTransactions() async {
    if (mounted) setState(() => _isLoadingAll = true);
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('financialTransactions')
              .orderBy('date', descending: true)
              .get();
      if (mounted) {
        setState(() {
          _transactions = querySnapshot.docs;
          _hasLoadedAllTransactions = true;
          _showFilters = true;
          _clientName = '';
          _searchPn = null;
          _searchController.clear();
        });
      }
      _calculateBalance();
    } catch (e) {
      _showError('حدث خطأ أثناء جلب البيانات: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _fetchFilteredTransactions() async {
    if (_searchPn == null || _searchPn!.isEmpty) {
      _showError('يرجى إدخال كود الشقة');
      return;
    }

    await _fetchCustomerDataByCode(_searchPn!);
  }

  void _calculateBalance() {
    _balance = 0.0;
    for (var transaction in _transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      final amount =
          data['amount'] is int
              ? (data['amount'] as int).toDouble()
              : data['amount'] is double
              ? data['amount'] as double
              : 0.0;
      final type = data['debitCredit'] as String? ?? '';
      _balance += (type == 'له' || type == 'لة') ? amount : -amount;
    }
  }

  List<QueryDocumentSnapshot> _getFilteredTransactions() {
    if (_selectedFilter == 'الكل') {
      return _transactions;
    }

    return _transactions.where((transaction) {
      final data = transaction.data() as Map<String, dynamic>;
      final pn = data['pn'] as String?;
      final isIndependent = data['isIndependent'] == true;

      switch (_selectedFilter) {
        case 'مرتبطة بشقة':
          return pn != null && pn.isNotEmpty && pn != '000-0' && !isIndependent;
        case 'غير مرتبطة':
          return (pn == null || pn.isEmpty || pn == '000-0') && !isIndependent;
        case 'مستقلة':
          return isIndependent;
        default:
          return true;
      }
    }).toList();
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ: $error'), backgroundColor: Colors.red),
    );
  }

  // دالة مساعدة لتحديث المبلغ المدفوع في الوحدات والعقود
  Future<void> _updateUnitPaidAmount(
    String pn,
    double amount,
    String debitCredit,
  ) async {
    try {
      // تحديث في مجموعة الشقق
      final unitQuery =
          await FirebaseFirestore.instance
              .collection('apartments')
              .where('pn', isEqualTo: pn)
              .limit(1)
              .get();

      if (unitQuery.docs.isNotEmpty) {
        final unitDoc = unitQuery.docs.first;
        final unitData = unitDoc.data();
        final double currentPaid =
            unitData['paidAmount'] is int
                ? (unitData['paidAmount'] as int).toDouble()
                : (unitData['paidAmount'] ?? 0.0);

        double newPaidAmount = currentPaid;
        if (debitCredit == 'له' || debitCredit == 'لة') {
          newPaidAmount = currentPaid + amount;
        } else if (debitCredit == 'عليه') {
          newPaidAmount = currentPaid - amount;
        }

        newPaidAmount = newPaidAmount < 0 ? 0 : newPaidAmount;

        await unitDoc.reference.update({'paidAmount': newPaidAmount});
      }

      // تحديث في مجموعة العقود
      final contractQuery =
          await FirebaseFirestore.instance
              .collection('contracts')
              .where('pn', isEqualTo: pn)
              .limit(1)
              .get();

      if (contractQuery.docs.isNotEmpty) {
        final contractDoc = contractQuery.docs.first;
        final contractData = contractDoc.data();
        final double currentPaid =
            contractData['paidAmount'] is int
                ? (contractData['paidAmount'] as int).toDouble()
                : (contractData['paidAmount'] ?? 0.0);

        double newPaidAmount = currentPaid;
        if (debitCredit == 'له' || debitCredit == 'لة') {
          newPaidAmount = currentPaid + amount;
        } else if (debitCredit == 'عليه') {
          newPaidAmount = currentPaid - amount;
        }

        newPaidAmount = newPaidAmount < 0 ? 0 : newPaidAmount;

        await contractDoc.reference.update({'paidAmount': newPaidAmount});
      }
    } catch (e) {
      print('خطأ في تحديث المبلغ المدفوع: $e');
    }
  }

  Future<void> _editTransaction(DocumentSnapshot transaction) async {
    final data = transaction.data() as Map<String, dynamic>;

    final double originalAmount =
        data['amount'] is int
            ? (data['amount'] as int).toDouble()
            : data['amount'] as double;
    final String originalDescription = data['description'] as String? ?? '';
    final String originalDebitCredit = data['debitCredit'] as String? ?? 'له';
    final String rawTransactionType =
        data['transactionType'] as String? ?? 'نقدي';
    final String originalTransactionType =
        ['نقدي', 'شيك', 'حوالة'].contains(rawTransactionType)
            ? rawTransactionType
            : 'نقدي';
    final String? pn = data['pn'];
    final String? idNumber = data['idNumber'];
    final String? customerName = data['customerName'];

    // معالجة التاريخ الأصلي
    DateTime originalDate;
    if (data['date'] is Timestamp) {
      originalDate = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      originalDate =
          DateTime.tryParse(data['date'] as String) ?? DateTime.now();
    } else {
      originalDate = DateTime.now();
    }

    final bool isIndependent =
        data.containsKey('isIndependent')
            ? (data['isIndependent'] == true)
            : false;
    final String? independentOperationType =
        data.containsKey('independentOperationType')
            ? data['independentOperationType']
            : null;
    final bool isDeposit = data['isDeposit'] == true;
    final String? projectNumber = data['projectNumber'];
    final String? unitNumber = data['unitNumber'];

    final amountController = TextEditingController(
      text: originalAmount.toString(),
    );
    final descriptionController = TextEditingController(
      text: originalDescription,
    );
    final unitNumberController = TextEditingController();
    final idNumberController = TextEditingController(text: idNumber ?? '');
    final newUnitController = TextEditingController();

    String selectedDebitCredit = originalDebitCredit;
    String selectedTransactionType = originalTransactionType;
    DateTime selectedDate = originalDate;

    final List<String> transactionTypes = ['نقدي', 'شيك', 'حوالة'];
    final List<String> debitCreditTypes = ['له', 'عليه'];
    final bool isNewUnit = pn == null || pn.isEmpty || pn == '000-0';

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تعديل العملية'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerName != null) ...[
                    Text(
                      'العميل: $customerName',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (pn != null) Text('رقم الوحدة الحالي: $pn'),
                    Divider(),
                  ],
                  Text(
                    'رقم الهوية:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: idNumberController,
                    decoration: InputDecoration(
                      labelText: 'رقم الهوية',
                      border: OutlineInputBorder(),
                      hintText: 'أدخل رقم الهوية الجديد',
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'تاريخ العملية:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (picked != null && picked != selectedDate) {
                        selectedDate = picked;
                      }
                    },
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('yyyy/MM/dd').format(selectedDate),
                            style: TextStyle(fontSize: 16),
                          ),
                          Icon(Icons.calendar_today, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'تحويل إلى شقة أخرى (اختياري):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: newUnitController,
                    decoration: InputDecoration(
                      labelText: 'رقم الوحدة الجديد',
                      border: OutlineInputBorder(),
                      hintText: 'اتركه فارغاً للاحتفاظ بالوحدة الحالية',
                    ),
                  ),
                  SizedBox(height: 12),
                  if (isNewUnit) ...[
                    Text(
                      'رقم الوحدة (للعمليات غير المرتبطة):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: unitNumberController,
                      decoration: InputDecoration(
                        labelText: 'رقم الوحدة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'المبلغ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'نوع العملية:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedDebitCredit,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                    items:
                        debitCreditTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) selectedDebitCredit = value;
                    },
                  ),
                  SizedBox(height: 12),
                  Text(
                    'طريقة الدفع:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedTransactionType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                    ),
                    items:
                        transactionTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) selectedTransactionType = value;
                    },
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
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
                  try {
                    final double? newAmount = double.tryParse(
                      amountController.text,
                    );
                    if (newAmount == null || newAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('الرجاء إدخال مبلغ صحيح أكبر من صفر'),
                        ),
                      );
                      return;
                    }

                    final String newDescription = descriptionController.text;
                    final String newIdNumber = idNumberController.text.trim();
                    final String newUnitNumber = newUnitController.text.trim();

                    String effectivePn;
                    if (newUnitNumber.isNotEmpty) {
                      // تحويل إلى شقة جديدة
                      effectivePn = newUnitNumber;
                    } else if (isNewUnit) {
                      // للعمليات غير المرتبطة
                      effectivePn = unitNumberController.text.trim();
                    } else {
                      // الاحتفاظ بالوحدة الحالية
                      effectivePn = pn ?? '';
                    }

                    // تحديث العملية المالية
                    Map<String, dynamic> updateData = {
                      'amount': newAmount,
                      'description': newDescription,
                      'debitCredit': selectedDebitCredit,
                      'transactionType': selectedTransactionType,
                      'date': Timestamp.fromDate(selectedDate),
                      'lastModified': FieldValue.serverTimestamp(),
                    };

                    // تحديث رقم الهوية إذا تم تغييره
                    if (newIdNumber.isNotEmpty && newIdNumber != idNumber) {
                      updateData['idNumber'] = newIdNumber;
                    }

                    // تحديث رقم الوحدة إذا تم تغييره
                    if (effectivePn.isNotEmpty && effectivePn != '000-0') {
                      updateData['pn'] = effectivePn;
                    }

                    await FirebaseFirestore.instance
                        .collection('financialTransactions')
                        .doc(transaction.id)
                        .update(updateData);

                    // تحديث المبالغ في الوحدات والعقود
                    final bool unitChanged =
                        newUnitNumber.isNotEmpty && newUnitNumber != pn;
                    final bool amountChanged = newAmount != originalAmount;

                    if (amountChanged || unitChanged) {
                      // إذا تم تغيير الوحدة، نحتاج لإزالة المبلغ من الوحدة القديمة
                      if (unitChanged &&
                          pn != null &&
                          pn.isNotEmpty &&
                          pn != '000-0') {
                        await _updateUnitPaidAmount(
                          pn,
                          -originalAmount,
                          originalDebitCredit,
                        );
                      }

                      // تحديث الوحدة الجديدة أو الحالية
                      if (effectivePn.isNotEmpty && effectivePn != '000-0') {
                        if (unitChanged) {
                          // إضافة المبلغ الجديد للوحدة الجديدة
                          await _updateUnitPaidAmount(
                            effectivePn,
                            newAmount,
                            selectedDebitCredit,
                          );
                        } else if (amountChanged) {
                          // تحديث المبلغ في نفس الوحدة
                          final double amountDifference =
                              newAmount - originalAmount;
                          await _updateUnitPaidAmount(
                            effectivePn,
                            amountDifference,
                            selectedDebitCredit,
                          );
                        }
                      }
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم التعديل بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // إعادة تحميل البيانات بناءً على التغييرات
                    if (newIdNumber.isNotEmpty && newIdNumber != idNumber) {
                      // إذا تم تغيير رقم الهوية، ابحث بالرقم الجديد
                      await _fetchCustomerDataByCode(newIdNumber);
                    } else if (_searchPn != null) {
                      await _fetchFilteredTransactions();
                    } else {
                      await _fetchInitialTransactions();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('فشل في التعديل: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
                child: Text('حفظ'),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteTransaction(DocumentSnapshot transaction) async {
    final data = transaction.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف هذه العملية؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteTransaction(transaction.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('حذف'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteTransaction(String documentId) async {
    try {
      final transactionDoc =
          await FirebaseFirestore.instance
              .collection('financialTransactions')
              .doc(documentId)
              .get();

      if (!transactionDoc.exists) {
        throw Exception('العملية غير موجودة');
      }

      final transactionData = transactionDoc.data()!;
      final String? pn = transactionData['pn'];
      final double amount =
          transactionData['amount'] is int
              ? (transactionData['amount'] as int).toDouble()
              : transactionData['amount'] as double? ?? 0.0;
      final String debitCredit = transactionData['debitCredit'] ?? '';

      final bool isIndependent =
          transactionData.containsKey('isIndependent')
              ? (transactionData['isIndependent'] == true)
              : false;
      final String operationType =
          transactionData.containsKey('operationType')
              ? transactionData['operationType']
              : 'عادية';
      final bool isDeposit =
          transactionData.containsKey('isDeposit')
              ? (transactionData['isDeposit'] == true)
              : false;
      final String? apartmentId = transactionData['apartmentId'];

      await FirebaseFirestore.instance
          .collection('financialTransactions')
          .doc(documentId)
          .delete();

      if (isDeposit && operationType == 'عربون' && apartmentId != null) {
        await FirebaseFirestore.instance
            .collection('apartments')
            .doc(apartmentId)
            .update({
              'status': 'متاح',
              'clientName': FieldValue.delete(),
              'depositAmount': FieldValue.delete(),
              'clientIdentity': FieldValue.delete(),
              'depositDate': FieldValue.delete(),
              'reservedAt': FieldValue.delete(),
            });
      }

      if (pn != null && pn.isNotEmpty) {
        final unitQuery =
            await FirebaseFirestore.instance
                .collection('apartments')
                .where('pn', isEqualTo: pn)
                .limit(1)
                .get();

        if (unitQuery.docs.isNotEmpty) {
          final unitDoc = unitQuery.docs.first;
          final unitData = unitDoc.data();
          final double currentPaid =
              unitData['paidAmount'] is int
                  ? (unitData['paidAmount'] as int).toDouble()
                  : (unitData['paidAmount'] ?? 0.0);

          double newPaidAmount = currentPaid;
          if (debitCredit == 'له' || debitCredit == 'لة') {
            newPaidAmount = currentPaid - amount;
          } else if (debitCredit == 'عليه') {
            newPaidAmount = currentPaid + amount;
          }

          newPaidAmount = newPaidAmount < 0 ? 0 : newPaidAmount;

          await unitDoc.reference.update({'paidAmount': newPaidAmount});
        }

        final contractQuery =
            await FirebaseFirestore.instance
                .collection('contracts')
                .where('pn', isEqualTo: pn)
                .limit(1)
                .get();
        if (contractQuery.docs.isNotEmpty) {
          final contractDoc = contractQuery.docs.first;
          final contractData = contractDoc.data();
          final double currentPaid =
              contractData['paidAmount'] is int
                  ? (contractData['paidAmount'] as int).toDouble()
                  : (contractData['paidAmount'] ?? 0.0);

          double newPaidAmount = currentPaid;
          if (debitCredit == 'له' || debitCredit == 'لة') {
            newPaidAmount = currentPaid - amount;
          } else if (debitCredit == 'عليه') {
            newPaidAmount = currentPaid + amount;
          }

          newPaidAmount = newPaidAmount < 0 ? 0 : newPaidAmount;

          await contractDoc.reference.update({'paidAmount': newPaidAmount});
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف العملية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      if (_searchPn != null) {
        await _fetchFilteredTransactions();
      } else {
        await _fetchInitialTransactions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في الحذف: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // وظيفة طباعة سند قبض أو صرف
  Future<void> _printReceipt(DocumentSnapshot transaction) async {
    final pdf = pw.Document();

    // تحميل الخط العربي والصور
    final arabicFont = pw.Font.ttf(
      await rootBundle.load('assets/Tajawal/Tajawal-Medium.ttf'),
    );
    final imageData = await rootBundle.load('images/m.png');
    final imageDaa = await rootBundle.load('images/4.jpg');
    final image = pw.MemoryImage(imageData.buffer.asUint8List());
    final image1 = pw.MemoryImage(imageDaa.buffer.asUint8List());

    final data = transaction.data() as Map<String, dynamic>;

    String formattedDate;
    if (data['date'] is Timestamp) {
      final date = (data['date'] as Timestamp).toDate();
      formattedDate = DateFormat('yyyy/MM/dd').format(date);
    } else if (data['date'] is String) {
      final dateString = data['date'] as String;
      try {
        final date = DateTime.parse(dateString);
        formattedDate = DateFormat('yyyy/MM/dd').format(date);
      } catch (e) {
        formattedDate = dateString;
      }
    } else {
      formattedDate = 'تاريخ غير صحيح';
    }
    final amount =
        data['amount'] is int
            ? (data['amount'] as int).toDouble()
            : data['amount'] as double;
    final debitCredit = data['debitCredit'] as String;
    final transactionType = data['transactionType'] as String? ?? 'نقدي';
    final description = data['description'] ?? '';
    final customerName = data['customerName'] as String? ?? '';

    final bool isIndependent = data['isIndependent'] == true;
    final String? independentOperationType =
        data.containsKey('independentOperationType')
            ? data['independentOperationType']
            : null;

    final pn = data['pn'] as String?;
    final projectNumber = data['projectNumber'] as String?;
    final unitNumber = data['unitNumber'] as String?;

    final receiptType =
        (debitCredit == 'له' || debitCredit == 'لة') ? 'سند قبض' : 'سند صرف';
    final receiptColor =
        (debitCredit == 'له' || debitCredit == 'لة')
            ? PdfColors.green700
            : PdfColors.red700;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                image: pw.DecorationImage(image: image1, fit: pw.BoxFit.cover),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [pw.Image(image, height: 80)],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Container(
                      padding: pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: receiptColor, width: 2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        receiptType,
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 12,
                          color: receiptColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  pw.Divider(thickness: 2, color: receiptColor),
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Text(
                      'رقم السند: ${transaction.id.substring(0, 8)}',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'التاريخ: $formattedDate',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                      pw.Text(
                        'نوع العملية: $transactionType',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'اسم العميل: $customerName',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                      pw.Text(
                        isIndependent ? 'عملية مستقلة' : 'عملية مرتبطة بوحدة',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),

                  if (!isIndependent && pn != null && pn.isNotEmpty) ...[
                    pw.Text(
                      'رقم الكود (PN): $pn',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 5),
                  ],
                  if (!isIndependent &&
                      projectNumber != null &&
                      projectNumber.isNotEmpty) ...[
                    pw.Text(
                      'رقم المشروع: $projectNumber',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 5),
                  ],
                  if (!isIndependent &&
                      unitNumber != null &&
                      unitNumber.isNotEmpty) ...[
                    pw.Text(
                      'رقم الوحدة: $unitNumber',
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 5),
                  ],

                  if (isIndependent) ...[
                    pw.Text(
                      'نوع العملية المستقلة: ${independentOperationType ?? "غير محدد"}',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    if (independentOperationType == 'عربون' &&
                        projectNumber != null &&
                        unitNumber != null) ...[
                      pw.Text(
                        'معلومات العربون:',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'رقم المشروع: $projectNumber - رقم الوحدة: $unitNumber',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                      pw.SizedBox(height: 5),
                    ],
                  ],
                  pw.SizedBox(height: 20),
                  pw.Container(
                    padding: pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: receiptColor),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'المبلغ:',
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${amount.toStringAsFixed(2)} ر.س',
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: receiptColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'الوصف:',
                    style: pw.TextStyle(
                      font: arabicFont,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      description,
                      style: pw.TextStyle(font: arabicFont, fontSize: 14),
                    ),
                  ),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'المستلم',
                            style: pw.TextStyle(font: arabicFont, fontSize: 14),
                          ),
                          pw.SizedBox(height: 40),
                          pw.Container(
                            width: 120,
                            height: 1,
                            color: PdfColors.black,
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'المحاسب',
                            style: pw.TextStyle(font: arabicFont, fontSize: 14),
                          ),
                          pw.SizedBox(height: 40),
                          pw.Container(
                            width: 120,
                            height: 1,
                            color: PdfColors.black,
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'المدير',
                            style: pw.TextStyle(font: arabicFont, fontSize: 14),
                          ),
                          pw.SizedBox(height: 40),
                          pw.Container(
                            width: 120,
                            height: 1,
                            color: PdfColors.black,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _printTransaction(DocumentSnapshot transaction) async {
    try {
      await _printReceipt(transaction);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في طباعة السند: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchCustomerDataByCode(String code) async {
    if (code.isEmpty) return;

    // إلغاء أي عملية بحث سابقة
    _debounceTimer?.cancel();

    // تعيين الكود الحالي للبحث
    _currentSearchCode = code;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // البحث عن بيانات العميل من مجموعة العقود
      final QuerySnapshot contractSnapshot =
          await FirebaseFirestore.instance
              .collection('contracts')
              .where('pn', isEqualTo: code)
              .limit(1)
              .get();

      String clientName = 'غير محدد';
      if (contractSnapshot.docs.isNotEmpty) {
        final contractData =
            contractSnapshot.docs.first.data() as Map<String, dynamic>;
        clientName = contractData['clientName'] ?? 'غير محدد';
      }

      // جلب المعاملات المالية - البحث فقط برقم pn
      List<QueryDocumentSnapshot> transactions = [];
      
      try {
        // محاولة الاستعلام مع الترتيب
        final QuerySnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('financialTransactions')
                .where('pn', isEqualTo: code)
                .orderBy('date', descending: true)
                .get();
        transactions = snapshot.docs;
      } catch (indexError) {
        // في حالة عدم وجود فهرس، استخدم استعلام بسيط بدون ترتيب
        print('Index not found, using simple query: $indexError');
        final QuerySnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('financialTransactions')
                .where('pn', isEqualTo: code)
                .get();

        // ترتيب النتائج محلياً
        transactions = snapshot.docs.toList();
        transactions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData['date'] as Timestamp?;
          final bDate = bData['date'] as Timestamp?;

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;

          return bDate.compareTo(aDate); // ترتيب تنازلي
        });
      }

      // إذا وجدنا معاملات ولم نجد اسم العميل من العقد، نحاول الحصول عليه من أول معاملة
      if (transactions.isNotEmpty && clientName == 'غير محدد') {
        final firstTransaction =
            transactions.first.data() as Map<String, dynamic>;
        clientName = firstTransaction['customerName'] ?? 'غير محدد';
      }

      // التأكد من أن هذا هو البحث الحالي وليس بحث قديم
      if (mounted && _currentSearchCode == code) {
        setState(() {
          _clientName = clientName;
          _searchPn = code;
          _transactions = transactions;
          _isLoading = false;
        });
      }

      if (_transactions.isNotEmpty) {
        _calculateBalance();
      }
    } catch (e) {
      if (mounted && _currentSearchCode == code) {
        setState(() {
          _isLoading = false;
        });
      }
      _showError('حدث خطأ أثناء جلب البيانات: ${e.toString()}');
    }
  }



  void _clearCustomerData() {
    if (mounted) {
      setState(() {
        _clientName = '';
        _searchPn = null;
        _transactions.clear();
        _balance = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'المعاملات المالية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.indigo.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.white]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.blue.shade50],
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
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
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
                              Icons.search,
                              color: Colors.blue.shade700,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'البحث في المعاملات المالية',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
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
                        child: TextField(
                          controller: _searchController,
                          decoration: _buildEnhancedInputDecoration(
                            'كود الشقة',
                            Icons.home,
                          ),
                          onChanged: (v) {
                            _searchPn = v;
                            _debounceTimer?.cancel();

                            if (v.isEmpty) {
                              // مسح البيانات فوراً عند إفراغ النص
                              _currentSearchCode = null;
                              setState(() {
                                _transactions.clear();
                                _clientName = '';
                                _balance = 0.0;
                                _searchPn = null;
                              });
                              return;
                            }

                            _debounceTimer = Timer(
                              Duration(milliseconds: 800),
                              () {
                                if (v.isNotEmpty && v.length >= 3) {
                                  _fetchCustomerDataByCode(v);
                                }
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildSearchButton()),
                          SizedBox(width: 8),
                          Expanded(child: _buildLoadAllButton()),
                          SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.shade400,
                                    Colors.red.shade600,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchPn = null;
                                      _clientName = '';
                                      _transactions = [];
                                      _balance = 0;
                                      _hasLoadedAllTransactions = false;
                                      _showFilters = false;
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.clear,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'مسح',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
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
              SizedBox(height: 10),
              _buildFiltersSection(),
              if (_searchPn != null &&
                  !_isLoading &&
                  _transactions.isNotEmpty) ...[
                Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.blue.shade50],
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
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1,
                    ),
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
                        _buildCustomerInfoRow(
                          Icons.account_circle,
                          'اسم العميل',
                          _clientName,
                        ),
                        SizedBox(height: 12),
                        _buildCustomerInfoRow(
                          Icons.code,
                          'رقم الكود',
                          _searchPn!,
                        ),
                        SizedBox(height: 12),
                        _buildCustomerInfoRow(
                          _balance >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          'الرصيد الحالي',
                          '${_balance.toStringAsFixed(2)} ريال',
                          valueColor:
                              _balance >= 0
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
              Expanded(
                child:
                    (_isLoading || _isLoadingAll)
                        ? Center(child: CircularProgressIndicator())
                        : _getFilteredTransactions().isEmpty
                        ? Center(
                          child: Text(
                            _searchPn == null && !_hasLoadedAllTransactions
                                ? 'أدخل رقم PN لعرض البيانات أو اضغط على "كل العمليات"'
                                : _hasLoadedAllTransactions
                                ? 'لا توجد عمليات تطابق الفلتر المحدد'
                                : 'لا توجد عمليات مسجلة لهذا الرقم',
                          ),
                        )
                        : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Colors.blue[50],
                              ),
                              columns: [
                                DataColumn(label: Text('اسم العميل')),
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('نوع العملية')),
                                DataColumn(label: Text('المبلغ')),
                                DataColumn(label: Text('النوع')),
                                DataColumn(label: Text('الوصف')),
                                DataColumn(label: Text('تفاصيل إضافية')),
                                DataColumn(label: Text('الإجراءات')),
                              ],
                              rows:
                                  _getFilteredTransactions().map((transaction) {
                                    final data =
                                        transaction.data()
                                            as Map<String, dynamic>;
                                    final double amount =
                                        data['amount'] is int
                                            ? (data['amount'] as int).toDouble()
                                            : data['amount'] as double;
                                    final String debitCredit =
                                        data['debitCredit'] as String? ?? '';
                                    final String description =
                                        data['description'] as String? ?? '';
                                    String formattedDate;
                                    if (data['date'] is Timestamp) {
                                      final Timestamp timestamp =
                                          data['date'] as Timestamp;
                                      final DateTime date = timestamp.toDate();
                                      formattedDate = DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(date);
                                    } else if (data['date'] is String) {
                                      formattedDate = data['date'] as String;
                                    } else {
                                      formattedDate = 'تاريخ غير صحيح';
                                    }
                                    final String transactionType =
                                        data['transactionType'] as String? ??
                                        'نقدي';
                                    final String customerName =
                                        data['customerName'] as String? ?? '';

                                    final bool isIndependent =
                                        data['isIndependent'] == true;
                                    final String? independentOperationType =
                                        data.containsKey(
                                              'independentOperationType',
                                            )
                                            ? data['independentOperationType']
                                            : null;
                                    final bool isDeposit =
                                        data['isDeposit'] == true;
                                    final String? projectNumber =
                                        data['projectNumber'];
                                    final String? unitNumber = data['number'];

                                    Color rowColor = Colors.white;
                                    if (isIndependent &&
                                        independentOperationType == 'عربون') {
                                      rowColor = Colors.amber.shade100;
                                    } else if (debitCredit == 'له' ||
                                        debitCredit == 'لة') {
                                      rowColor = Colors.green.shade50;
                                    } else {
                                      rowColor = Colors.red.shade50;
                                    }

                                    String additionalDetails = '';
                                    if (isIndependent) {
                                      additionalDetails += 'عملية مستقلة';
                                      if (independentOperationType != null) {
                                        additionalDetails +=
                                            ' - $independentOperationType';
                                      }
                                      if (independentOperationType == 'عربون' &&
                                          projectNumber != null &&
                                          unitNumber != null) {
                                        additionalDetails +=
                                            '\nمشروع: $projectNumber - وحدة: $unitNumber';
                                      }
                                    }

                                    return DataRow(
                                      color: WidgetStateProperty.all(rowColor),
                                      cells: [
                                        DataCell(Text(customerName)),
                                        DataCell(Text(formattedDate)),
                                        DataCell(Text(transactionType)),
                                        DataCell(
                                          Text(
                                            '${amount.toStringAsFixed(2)} ر.س',
                                            style: TextStyle(
                                              color:
                                                  (debitCredit == 'له' ||
                                                          debitCredit == 'لة')
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            debitCredit,
                                            style: TextStyle(
                                              color:
                                                  (debitCredit == 'له' ||
                                                          debitCredit == 'لة')
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(description)),
                                        DataCell(Text(additionalDetails)),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                ),
                                                onPressed:
                                                    () => _editTransaction(
                                                      transaction,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed:
                                                    () =>
                                                        _confirmDeleteTransaction(
                                                          transaction,
                                                        ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.print,
                                                  color: Colors.green,
                                                ),
                                                onPressed:
                                                    () => _printReceipt(
                                                      transaction,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  InputDecoration _buildEnhancedInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue.shade700, size: 20),
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
        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildCustomerInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey.shade600, size: 18),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    final isEnabled = (_searchPn?.isNotEmpty ?? false);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors:
              _isLoading
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : isEnabled
                  ? [Colors.blue.shade600, Colors.indigo.shade700]
                  : [Colors.grey.shade400, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _isLoading
                    ? Colors.grey.withOpacity(0.3)
                    : isEnabled
                    ? Colors.blue.withOpacity(0.4)
                    : Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (_isLoading || !isEnabled) ? null : _fetchFilteredTransactions,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(Icons.search, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isLoading ? 'جاري البحث...' : 'بحث',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  Widget _buildLoadAllButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors:
              _isLoadingAll
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : [Colors.green.shade600, Colors.teal.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _isLoadingAll
                    ? Colors.grey.withOpacity(0.3)
                    : Colors.green.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoadingAll ? null : _fetchAllTransactions,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoadingAll)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(Icons.list_alt, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isLoadingAll ? 'جاري التحميل...' : 'كل العمليات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  Widget _buildFiltersSection() {
    if (!_showFilters || !_hasLoadedAllTransactions) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: Colors.purple.shade700,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'فلترة العمليات',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.purple.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('الكل'),
                _buildFilterChip('مرتبطة بشقة'),
                _buildFilterChip('غير مرتبطة'),
                _buildFilterChip('مستقلة'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(
        filter,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.purple.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
      backgroundColor: Colors.purple.shade50,
      selectedColor: Colors.purple.shade600,
      checkmarkColor: Colors.white,
      elevation: isSelected ? 4 : 2,
      shadowColor: Colors.purple.withOpacity(0.3),
    );
  }
}
