import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'brozinshin/admin/عرض التسويات1.dart';

class FinancialSettlementContract extends StatefulWidget {
  String progect;
  FinancialSettlementContract({super.key, required this.progect});
  @override
  _FinancialSettlementContractState createState() =>
      _FinancialSettlementContractState();
}

class _FinancialSettlementContractState
    extends State<FinancialSettlementContract> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _contractSearchController =
      TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _newPriceController = TextEditingController();
  final Map<String, dynamic> _originalContract = {};

  Map<String, dynamic>? _contractData;
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _untedata;
  bool _isLoading = false;
  bool _showForm = false;
  bool _showContractCard = false;
  bool _showCustomerCard = false;
  bool _isIdentityFromContract = false; // لتتبع ما إذا كانت الهوية مجلبة من العقد
  bool _showIdentityNote = false; // لإظهار ملاحظة الهوية
  final String _newContractNumber = '';
  String nam = '';

  @override
  void initState() {
    _contractSearchController.text = widget.progect;
    super.initState();
    _generateNewContractNumber();
  }

  void _generateNewContractNumber() {
    final now = DateTime.now();
    setState(() {});
  }

  Future<void> _searchContract() async {
    if (_contractSearchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _contractData = null;
      _showContractCard = false;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('contracts')
              .where('pn', isEqualTo: _contractSearchController.text)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _contractData = querySnapshot.docs.first.data();
          _showContractCard = true;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لا يوجد عقد بهذا الرقم')));
      }
      final doc = querySnapshot.docs.first;
      setState(() {
        _contractData = {
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
      });
    }

    // جلب هوية العميل من العقد وإظهار ملاحظة
    _customerSearchController.text =
        _contractData!['clientData']['identityNumber'];
    nam = '${_contractData!['pn']}';
    
    setState(() {
      _isIdentityFromContract = true;
      _showIdentityNote = true;
    });
    
    // إظهار رسالة للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم جلب هوية العميل من العقد السابق تلقائياً',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
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
          _untedata = querySnapshot.docs.first.data();
          _showCustomerCard = true;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('لم يتم جلب الوحدة')));
      }
      final doc = querySnapshot.docs.first;
      setState(() {
        _untedata = {
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

  // دالة للتعامل مع النقر على زر البحث
  Future<void> _handleCustomerSearch() async {
    if (_customerSearchController.text.isEmpty) return;

    // إذا كانت الهوية مجلبة من العقد، اعرض رسالة تأكيد
    if (_isIdentityFromContract && 
        _customerSearchController.text == _contractData?['clientData']['identityNumber']) {
      
      bool? shouldSearch = await _showSearchConfirmationDialog();
      if (shouldSearch != true) return;
    }

    // إذا تم تغيير الهوية، قم بالبحث مباشرة
    _searchCustomer();
  }

  // دالة لإظهار رسالة التأكيد
  Future<bool?> _showSearchConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.help_outline,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'تأكيد البحث',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          content: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'هل تود البحث عن العميل السابق الذي تم جلب هويته من العقد؟',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  'نعم، ابحث',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchCustomer() async {
    if (_customerSearchController.text.isEmpty) return;

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
        final doc = querySnapshot.docs.first;
        setState(() {
          _customerData = {
            ...doc.data(),
            'docId': doc.id, // حفظ معرف المستند
          };
          _showCustomerCard = true;
        });

        // إظهار رسالة نجاح مع تمييز نوع البحث
        String searchType = _isIdentityFromContract ? 'المجلب من العقد' : 'الجديد';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تم العثور على العميل $searchType بنجاح',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.green[50],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // إظهار رسالة عدم وجود عميل مع تمييز نوع البحث
        String searchType = _isIdentityFromContract ? 'المجلب من العقد' : 'المدخل';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.warning_amber,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا يوجد عميل بالرقم $searchType',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.orange[50],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red[700],
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'حدث خطأ أثناء البحث: $e',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.red[50],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _showForm = _showContractCard && _showCustomerCard;
        // إعادة تعيين حالة الهوية المجلبة بعد البحث
        if (_isIdentityFromContract) {
          _isIdentityFromContract = false;
          _showIdentityNote = false;
        }
      });
    }
  }

  Future<void> _submitSettlement() async {
    if (_newPriceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('يرجى إدخال السعر الجديد')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final docId = _contractData!['docId'];
    final docId1 = _customerData!['docId'];
    final docId2 = _untedata!['docId'];

    try {
      // Add to settlements collection
      await _firestore.collection('financialSettlements').add({
        'newContractNumber': nam,
        'originalContractNumber': _contractData!['contractNumber'],
        'projectNumber': _contractData!['projectNumber'],
        'apartmentNumber': _contractData!['unitNumber'], // رقم الشقة
        'nameNow': _customerData!['name'], // العميل
        'newCustomerId': _customerData!['identityNumber'], // هوية العميل الجديد
        'newPrice': double.parse(_newPriceController.text), // السعر الجديد
        'settlementDate': formattedDate, // تاريخ التسوية
        'createdAt': FieldValue.serverTimestamp(), // تاريخ الإنشاء
        'customerName': _contractData!['clientName'], // اسم العميل في العقد
        'clientIdentityNumber':
            _contractData!['clientData']['identityNumber'], // هوية العميل في العقد
        'clientPhoneNumber':
            _contractData!['clientData']['phoneNumber'], // رقم جوال العميل في العقد
        'deedNumber': _contractData!['unitData']['deedNumber'], // رقم الصك
        'regionNumber':
            _contractData!['unitData']['regionNumber'], // رقم القطعة
        'unitDirection': _contractData!['direction'], // اتجاه الشقة
        'contractDateHijri': _contractData!['dateHijri'], // تاريخ العقد بالهجري
      });

      // Update original contract status
      await _firestore.collection('contracts').doc(docId).update({
        'status': 'تمت إعادة البيع',
        'settlementContractNumber': nam,
      });

      // Update new customer with contract number
      await _firestore.collection('customers').doc(docId1).update({
        'contractNumber': _untedata!['pn'],
        'contractNumbers': FieldValue.arrayUnion([nam]),
      });
      await _firestore.collection('apartments').doc(docId2).update({
        'contractNumbers1': FieldValue.arrayUnion([nam]),
        'clientName': _customerData!['name'],
        'status': 'تحت الاجراء',
        'totalAmount': double.parse(_newPriceController.text),
        'clientIdentity': _customerData!['identityNumber'],
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حفظ تسوية المالية بنجاح')));

      // Reset form
      _resetForm();
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'جيد تم حفظ البيانات ولاكن لم يتم التعديل على جدول العملاء ',
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _contractSearchController.clear();
    _customerSearchController.clear();
    _newPriceController.clear();
    setState(() {
      _contractData = null;
      _customerData = null;
      _showContractCard = false;
      _showCustomerCard = false;
      _showForm = false;
      _generateNewContractNumber();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'تسوية مالية',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo[700],
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo[700]!, Colors.indigo[500]!],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.indigo[50]!, Colors.blue[50]!],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo[100]!, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance,
                      color: Colors.indigo[700],
                      size: isSmallScreen ? 24 : 32,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نظام التسوية المالية',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'إدارة وتسوية العقود العقارية',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Search for contract
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.description,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'بحث عن العقد الأصلي',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _contractSearchController,
                        decoration: InputDecoration(
                          labelText: 'رقم العقد',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          suffixIcon: Container(
                            margin: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[700]!],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.search, color: Colors.white),
                              onPressed: () {
                                _searchunt();
                                _searchContract();
                              },
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Search for customer
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_add,
                            color: Colors.green[700],
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'بحث عن العميل الجديد',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _customerSearchController,
                        onChanged: (value) {
                          // إذا تم تغيير النص، قم بإعادة تعيين حالة الهوية المجلبة
                          if (_isIdentityFromContract && 
                              value != _contractData?['clientData']['identityNumber']) {
                            setState(() {
                              _isIdentityFromContract = false;
                              _showIdentityNote = false;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'رقم هوية العميل',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          suffixIcon: Container(
                            margin: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green[600]!, Colors.green[700]!],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.search, color: Colors.white),
                              onPressed: _handleCustomerSearch,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.assignment,
                              color: Colors.orange[700],
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'بيانات التسوية المالية',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[50]!, Colors.indigo[50]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.numbers, color: Colors.blue[700], size: 20),
                            SizedBox(width: 8),
                            Text(
                              'رقم العقد الجديد: ',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              nam,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _newPriceController,
                          decoration: InputDecoration(
                            labelText: 'السعر الجديد للشقة',
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isSmallScreen ? 12 : 16,
                            ),
                            prefixIcon: Container(
                              margin: EdgeInsets.all(8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.attach_money,
                                color: Colors.green[700],
                                size: 20,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        height: isSmallScreen ? 48 : 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.green[600]!, Colors.green[700]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _submitSettlement,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.save,
                                color: Colors.white,
                                size: isSmallScreen ? 20 : 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'حفظ التسوية المالية',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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

            if (_isLoading) 
              Container(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo[700]!),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'جاري المعالجة...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    FinancialSettlementsPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;

                  var tween = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: curve));

                  return SlideTransition(
                    position: animation.drive(tween),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                transitionDuration: Duration(milliseconds: 400),
              ),
            );
          },
          label: Text(
            'عرض التسويات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          icon: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.list_alt, size: 20),
          ),
          backgroundColor: Colors.indigo[600],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildContractCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue[100]!, width: 1),
      ),
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.description,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'بيانات العقد الأصلي',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[50]!, Colors.indigo[50]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
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
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.green[100]!, width: 1),
      ),
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400]!, Colors.green[600]!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'بيانات العميل الجديد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[50]!, Colors.teal[50]!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('اسم', _customerData!['name']),
                  _buildInfoRow('هوية العميل', _customerData!['identityNumber']),
                  _buildInfoRow('رقم جوال العميل', _customerData!['phoneNumber']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, [IconData? icon]) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(width: 10),
          ],
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'غير متوفر',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
