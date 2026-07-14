import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinancialTransactionsPage1 extends StatefulWidget {
  const FinancialTransactionsPage1({super.key});

  @override
  _FinancialTransactionsPageState createState() =>
      _FinancialTransactionsPageState();
}

class _FinancialTransactionsPageState
    extends State<FinancialTransactionsPage1> {
  String? _searchCustomerId;
  List<DocumentSnapshot> _transactions = [];
  double _balance = 0.0;
  bool _isLoading = false;
  String _clientName = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerIdController = TextEditingController();

  // متغيرات البحث التلقائي
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showDropdown = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchInitialTransactions(); // جلب جميع البيانات عند التهيئة

    // إضافة مستمع للبحث التلقائي
    _customerIdController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        if (mounted) {
          setState(() {
            _showDropdown = false;
          });
        }
      }
    });
  }

  void _onSearchChanged() {
    final query = _customerIdController.text.trim();

    if (query.length >= 1) {
      if (mounted) {
        setState(() {
          _showDropdown = true;
          _isSearching = true;
        });
      }
      _searchCustomers(query);
    } else {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showDropdown = false;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _searchCustomers(String query) async {
    List<Map<String, dynamic>> results = [];
    Set<String> addedIds = {};

    try {
      // إضافة بيانات تجريبية للاختبار - تظهر مع أي حرف
      if (query.isNotEmpty) {
        // عملاء تجريبيون يظهرون مع أي بحث
        results.addAll([
          {
            'id': '1234567890',
            'name': 'أحمد محمد علي',
            'phone': '0501234567',
            'source': 'test',
          },
          {
            'id': '4567890123',
            'name': 'فاطمة أحمد',
            'phone': '0507654321',
            'source': 'test',
          },
          {
            'id': '7890123456',
            'name': 'سارة أحمد محمد',
            'phone': '0509876543',
            'source': 'test',
          },
          {
            'id': '9876543210',
            'name': 'محمد عبدالله',
            'phone': '0551234567',
            'source': 'test',
          },
          {
            'id': '5555555555',
            'name': 'نورا خالد',
            'phone': '0567890123',
            'source': 'test',
          },
        ]);
      }

      // البحث في مجموعة العملاء
      QuerySnapshot customersSnapshot =
          await FirebaseFirestore.instance.collection('customers').get();

      for (var doc in customersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final identityNumber =
            (data['identityNumber'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString();

        if (name.contains(query.toLowerCase()) ||
            identityNumber.contains(query.toLowerCase())) {
          final customerId =
              identityNumber.isNotEmpty ? identityNumber : doc.id;
          if (!addedIds.contains(customerId)) {
            results.add({
              'id': customerId,
              'name': data['name'] ?? 'غير محدد',
              'phone': phone,
              'source': 'customers',
            });
            addedIds.add(customerId);
          }
        }
      }

      // البحث في المعاملات المالية
      if (results.length < 10) {
        QuerySnapshot transactionsSnapshot =
            await FirebaseFirestore.instance
                .collection('financialTransactions')
                .get();

        for (var doc in transactionsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final customerName =
              (data['customerName'] ?? '').toString().toLowerCase();
          final idNumber = (data['idNumber'] ?? '').toString().toLowerCase();

          if (customerName.contains(query.toLowerCase()) ||
              idNumber.contains(query.toLowerCase())) {
            final customerId =
                idNumber.isNotEmpty
                    ? idNumber
                    : data['customerName'] ?? 'غير محدد';
            if (!addedIds.contains(customerId)) {
              results.add({
                'id': customerId,
                'name': data['customerName'] ?? 'غير محدد',
                'phone': data['phone'] ?? '',
                'source': 'transactions',
              });
              addedIds.add(customerId);
            }
          }
        }
      }
    } catch (e) {
      // معالجة الأخطاء بصمت
    }

    if (mounted) {
      setState(() {
        _searchResults = results.take(10).toList();
        _showDropdown = true;
        _isSearching = false;
      });
    }
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    if (mounted) {
      setState(() {
        _customerIdController.text = customer['id'];
        _searchCustomerId = customer['id'];
        _showDropdown = false;
        _clientName = customer['name'];
      });
    }
    _searchFocusNode.unfocus();
    if (mounted) {
      _fetchFilteredTransactions();
    }
  }

  Future<void> _fetchInitialTransactions() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('financialTransactions')
              .get();
      if (mounted) {
        setState(() => _transactions = querySnapshot.docs);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchFilteredTransactions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _balance = 0.0;
        _clientName = '';
      });
    }

    try {
      if (_searchCustomerId == null || _searchCustomerId!.isEmpty) {
        _showError('يرجى إدخال رقم هوية العميل');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // البحث عن العميل أولاً للحصول على اسمه
      final customerQuery =
          await FirebaseFirestore.instance
              .collection('customers')
              .where('identityNumber', isEqualTo: _searchCustomerId)
              .get();

      if (customerQuery.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _clientName = customerQuery.docs.first['name'] ?? '';
          });
        }
      }

      // البحث عن العمليات المالية المرتبطة برقم الهوية
      List<QueryDocumentSnapshot> allTransactions = [];

      // البحث باستخدام idNumber
      Query query1 = FirebaseFirestore.instance
          .collection('financialTransactions')
          .where('idNumber', isEqualTo: _searchCustomerId);
      final querySnapshot1 = await query1.get();
      allTransactions.addAll(querySnapshot1.docs);

      // البحث باستخدام customerId
      Query query2 = FirebaseFirestore.instance
          .collection('financialTransactions')
          .where('customerId', isEqualTo: _searchCustomerId);
      final querySnapshot2 = await query2.get();

      // إضافة النتائج مع تجنب التكرار
      for (var doc in querySnapshot2.docs) {
        if (!allTransactions.any((existing) => existing.id == doc.id)) {
          allTransactions.add(doc);
        }
      }

      _transactions = allTransactions;

      if (_transactions.isNotEmpty) {
        _clientName = _transactions.first['customerName'] ?? '';
        _calculateBalance();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateBalance() {
    for (var transaction in _transactions) {
      final amount = transaction['amount'] as double;
      final type = transaction['debitCredit'] as String;
      _balance += (type == 'له' || type == 'لة') ? amount : -amount;
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ: $error'), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerIdController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('العمليات المالية'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
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
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          TextField(
                            controller: _customerIdController,
                            focusNode: _searchFocusNode,
                            decoration: _buildInputDecoration(
                              'رقم هوية العميل',
                            ).copyWith(
                              suffixIcon:
                                  _isSearching
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                      : Icon(Icons.search),
                            ),
                            onChanged: (v) {
                              if (mounted) {
                                setState(() => _searchCustomerId = v);
                              }
                              _onSearchChanged();
                            },
                          ),
                          // القائمة المنسدلة للبحث
                          if (_showDropdown)
                            Positioned(
                              top: 65,
                              left: 0,
                              right: 0,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(12),
                                shadowColor: Colors.black26,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 300,
                                    minHeight: 60,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue.shade300,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child:
                                      _isSearching
                                          ? Container(
                                            height: 100,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.blue),
                                                  ),
                                                  SizedBox(height: 12),
                                                  Text(
                                                    'جاري البحث عن العملاء...',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          : _searchResults.isEmpty
                                          ? Container(
                                            height: 80,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.search_off,
                                                    color: Colors.grey.shade400,
                                                    size: 24,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'لا توجد نتائج للبحث',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          : ListView.separated(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            itemCount: _searchResults.length,
                                            separatorBuilder:
                                                (context, index) => Divider(
                                                  height: 1,
                                                  color: Colors.grey.shade200,
                                                  indent: 16,
                                                  endIndent: 16,
                                                ),
                                            itemBuilder: (context, index) {
                                              final customer =
                                                  _searchResults[index];
                                              return InkWell(
                                                onTap:
                                                    () => _selectCustomer(
                                                      customer,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 45,
                                                        height: 45,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors
                                                                  .blue
                                                                  .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                22.5,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Colors
                                                                    .blue
                                                                    .shade200,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.person,
                                                          color:
                                                              Colors
                                                                  .blue
                                                                  .shade700,
                                                          size: 22,
                                                        ),
                                                      ),
                                                      SizedBox(width: 14),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              customer['name'] ??
                                                                  'غير محدد',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 15,
                                                                color:
                                                                    Colors
                                                                        .black87,
                                                              ),
                                                            ),
                                                            SizedBox(height: 4),
                                                            Text(
                                                              'رقم الهوية: ${customer['id'] ?? 'غير محدد'}',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade600,
                                                              ),
                                                            ),
                                                            if (customer['phone'] !=
                                                                    null &&
                                                                customer['phone']
                                                                    .toString()
                                                                    .isNotEmpty)
                                                              Padding(
                                                                padding:
                                                                    EdgeInsets.only(
                                                                      top: 2,
                                                                    ),
                                                                child: Text(
                                                                  'الهاتف: ${customer['phone']}',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        Colors
                                                                            .grey
                                                                            .shade600,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: EdgeInsets.all(
                                                          8,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors
                                                                  .blue
                                                                  .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons
                                                              .arrow_forward_ios,
                                                          size: 14,
                                                          color:
                                                              Colors
                                                                  .blue
                                                                  .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12),
                      SizedBox(height: 12),
                      _buildSearchButton(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              // Client Info and Balance
              if (!_isLoading && _transactions.isNotEmpty) ...[
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اسم العميل: $_clientName'),
                        SizedBox(height: 6),
                        Text(
                          'الرصيد الحالي: ${_balance.toStringAsFixed(2)} ر.س',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                _balance >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
              ],
              // زر طباعة كشف الحساب
              if (!_isLoading && _transactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _printStatement,
                    icon: Icon(Icons.print),
                    label: Text('طباعة كشف الحساب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 10),
              // Transaction List
              Expanded(
                child:
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _transactions.isEmpty
                        ? Center(child: Text('لا توجد معاملات لهذا العميل'))
                        : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Colors.blue[50],
                              ),
                              columns: [
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('نوع العملية')),
                                DataColumn(label: Text('المبلغ')),
                                DataColumn(label: Text('النوع')),
                                DataColumn(label: Text('الوصف')),
                              ],
                              rows:
                                  _transactions.map((transaction) {
                                    // معالجة التاريخ بطريقة آمنة
                                    DateTime date;
                                    if (transaction['date'] is Timestamp) {
                                      date =
                                          (transaction['date'] as Timestamp)
                                              .toDate();
                                    } else if (transaction['date'] is String) {
                                      date =
                                          DateTime.tryParse(
                                            transaction['date'] as String,
                                          ) ??
                                          DateTime.now();
                                    } else {
                                      date = DateTime.now();
                                    }
                                    final formattedDate = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(date);
                                    final amount =
                                        transaction['amount'] as double;
                                    final debitCredit =
                                        transaction['debitCredit'] as String;
                                    final transactionType =
                                        transaction['transactionType']
                                            as String;
                                    final description =
                                        transaction['description'] as String;

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(formattedDate)),
                                        DataCell(Text(transactionType)),
                                        DataCell(
                                          Text(
                                            amount.toStringAsFixed(2),
                                            style: TextStyle(
                                              color:
                                                  (debitCredit == 'له' ||
                                                          debitCredit == 'لة')
                                                      ? Colors.green
                                                      : Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Chip(
                                            label: Text(
                                              debitCredit,
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor:
                                                (debitCredit == 'له' ||
                                                        debitCredit == 'لة')
                                                    ? Colors.green
                                                    : Colors.red,
                                          ),
                                        ),
                                        DataCell(Text(description)),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
              ),
              // ... (بقية العناصر كما هي)
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.blue.shade50,
    );
  }

  Future<void> _printStatement() async {
    try {
      final pdf = pw.Document();

      // تحميل الخط العربي والصور
      final arabicFont = pw.Font.ttf(
        await rootBundle.load('assets/Tajawal/Tajawal-Medium.ttf'),
      );

      // تنسيق التاريخ والوقت
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final timeFormatter = DateFormat('HH:mm:ss');
      final now = DateTime.now();

      try {
        final imageData = await rootBundle.load('images/m.png');
        final imageDaa = await rootBundle.load('images/4.jpg');
        final image = pw.MemoryImage(imageData.buffer.asUint8List());
        final image1 = pw.MemoryImage(imageDaa.buffer.asUint8List());

        // إضافة صفحة للمستند
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    image: pw.DecorationImage(
                      image: image1,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                  padding: pw.EdgeInsets.all(20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // الترويسة
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Image(image, height: 60),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'تاريخ الطباعة: ${dateFormatter.format(now)}',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 10,
                                ),
                              ),
                              pw.Text(
                                'وقت الطباعة: ${timeFormatter.format(now)}',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 10,
                                ),
                              ),
                              pw.Text(
                                'رقم التقرير: ${now.millisecondsSinceEpoch.toString().substring(5, 13)}',
                                style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.Divider(thickness: 2),
                      pw.SizedBox(height: 10),

                      // العنوان
                      pw.Center(
                        child: pw.Container(
                          padding: pw.EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue700,
                            borderRadius: pw.BorderRadius.circular(5),
                          ),
                          child: pw.Text(
                            'كشف حساب العميل',
                            style: pw.TextStyle(
                              font: arabicFont,
                              fontSize: 18,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 20),

                      // معلومات العميل
                      pw.Container(
                        padding: pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(),
                          borderRadius: pw.BorderRadius.circular(5),
                          color: PdfColors.grey100,
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'اسم العميل: $_clientName',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  'رقم الهوية: ${_searchCustomerId ?? "غير محدد"}',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'الرصيد الحالي: ${_balance.toStringAsFixed(2)} ر.س',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    color:
                                        _balance >= 0
                                            ? PdfColors.green700
                                            : PdfColors.red700,
                                  ),
                                ),
                                pw.Text(
                                  'عدد العمليات: ${_transactions.length}',
                                  style: pw.TextStyle(
                                    font: arabicFont,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 20),

                      // جدول العمليات
                      _buildTransactionsTable(arabicFont),
                      pw.SizedBox(height: 20),

                      // ملخص الحساب
                      pw.Container(
                        padding: pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blue700),
                          borderRadius: pw.BorderRadius.circular(5),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'إجمالي الله: ${_calculateTotalDebit().toStringAsFixed(2)} ر.س',
                              style: pw.TextStyle(font: arabicFont),
                            ),
                            pw.Text(
                              'إجمالي العليه: ${_calculateTotalCredit().toStringAsFixed(2)} ر.س',
                              style: pw.TextStyle(font: arabicFont),
                            ),
                            pw.Text(
                              'الرصيد النهائي: ${_balance.toStringAsFixed(2)} ر.س',
                              style: pw.TextStyle(
                                font: arabicFont,
                                fontWeight: pw.FontWeight.bold,
                                color:
                                    _balance >= 0
                                        ? PdfColors.green700
                                        : PdfColors.red700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 30),

                      // توقيعات
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'توقيع المحاسب',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                              pw.SizedBox(height: 20),
                              pw.Container(
                                width: 100,
                                height: 1,
                                color: PdfColors.black,
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'توقيع المدير',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                              pw.SizedBox(height: 20),
                              pw.Container(
                                width: 100,
                                height: 1,
                                color: PdfColors.black,
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'توقيع العميل',
                                style: pw.TextStyle(font: arabicFont),
                              ),
                              pw.SizedBox(height: 20),
                              pw.Container(
                                width: 100,
                                height: 1,
                                color: PdfColors.black,
                              ),
                            ],
                          ),
                        ],
                      ),

                      // رقم الصفحة
                      pw.Spacer(),
                      pw.Center(
                        child: pw.Text(
                          'صفحة ${context.pageNumber} من ${context.pagesCount}',
                          style: pw.TextStyle(font: arabicFont, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      } catch (imageError) {
        // في حالة عدم وجود الصور، إنشاء مستند بدون صور
        print('خطأ في تحميل الصور: $imageError');

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Container(
                  padding: pw.EdgeInsets.all(20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Center(
                        child: pw.Text(
                          'شركة مساكن الرفاهية',
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Center(
                        child: pw.Text(
                          'كشف حساب العميل',
                          style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Divider(),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'اسم العميل: $_clientName',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'رقم الهوية: $_searchCustomerId',
                        style: pw.TextStyle(font: arabicFont, fontSize: 14),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'الرصيد الحالي: ${_balance.toStringAsFixed(2)} ر.س',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 20),
                      _buildTransactionsTable(arabicFont),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }

      // طباعة المستند
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      print('خطأ في الطباعة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الطباعة: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // حساب إجمالي الله
  double _calculateTotalDebit() {
    double total = 0.0;
    for (var transaction in _transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      if (data['debitCredit'] == 'له') {
        final amount =
            data['amount'] is int
                ? (data['amount'] as int).toDouble()
                : (data['amount'] as double?);
        if (amount != null) {
          total += amount;
        }
      }
    }
    return total;
  }

  // حساب إجمالي العليه
  double _calculateTotalCredit() {
    double total = 0.0;
    for (var transaction in _transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      if (data['debitCredit'] == 'عليه') {
        final amount =
            data['amount'] is int
                ? (data['amount'] as int).toDouble()
                : (data['amount'] as double?);
        if (amount != null) {
          total += amount;
        }
      }
    }
    return total;
  }

  pw.Table _buildTransactionsTable(pw.Font arabicFont) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(2),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(5),
              child: pw.Text(
                'التاريخ',
                style: pw.TextStyle(font: arabicFont),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(5),
              child: pw.Text(
                'الوصف',
                style: pw.TextStyle(font: arabicFont),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(5),
              child: pw.Text(
                'المبلغ',
                style: pw.TextStyle(font: arabicFont),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(5),
              child: pw.Text(
                'النوع',
                style: pw.TextStyle(font: arabicFont),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(5),
              child: pw.Text(
                'ملاحظات',
                style: pw.TextStyle(font: arabicFont),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
        // Data rows
        ..._transactions.map((transaction) {
          final date = (transaction['date'] as Timestamp).toDate();
          final formattedDate = DateFormat('yyyy/MM/dd').format(date);
          final description = transaction['description'] ?? '';
          final amount =
              transaction['amount'] != null
                  ? '${transaction['amount'].toStringAsFixed(2)} ر.س'
                  : '0.00 ر.س';
          final type = transaction['debitCredit'] ?? '';
          // إضافة نوع العملية (عربون/عادية) في عمود الملاحظات
          final data = transaction.data() as Map<String, dynamic>;
          final operationType =
              data.containsKey('operationType')
                  ? data['operationType'] ?? 'عادية'
                  : 'عادية';
          final transactionType = data['transactionType'] ?? '';
          final notes =
              transactionType +
              (operationType != 'عادية' ? ' - ' + operationType : '');

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.all(5),
                child: pw.Text(
                  formattedDate,
                  style: pw.TextStyle(font: arabicFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(5),
                child: pw.Text(
                  description,
                  style: pw.TextStyle(font: arabicFont),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(5),
                child: pw.Text(
                  amount,
                  style: pw.TextStyle(font: arabicFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(5),
                child: pw.Text(
                  type,
                  style: pw.TextStyle(font: arabicFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(5),
                child: pw.Text(
                  notes,
                  style: pw.TextStyle(font: arabicFont),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildSearchButton() {
    final isEnabled = (_searchCustomerId?.isNotEmpty ?? false);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient:
            isEnabled
                ? LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                )
                : LinearGradient(colors: [Colors.grey, Colors.grey.shade600]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              isEnabled
                  ? () {
                    _searchFocusNode.unfocus();
                    if (mounted) {
                      setState(() => _showDropdown = false);
                    }
                    _fetchFilteredTransactions();
                  }
                  : null,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, color: Colors.white),
                SizedBox(width: 8),
                Text('بحث', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
