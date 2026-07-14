import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class DebtDisplayPage extends StatefulWidget {
  @override
  _DebtDisplayPageState createState() => _DebtDisplayPageState();
}

class _DebtDisplayPageState extends State<DebtDisplayPage> {
  List<Map<String, dynamic>> _debtData = [];
  List<Map<String, dynamic>> _filteredDebtData = [];
  bool _isLoading = false;
  String _selectedProject = 'الكل';
  String _selectedDebtType = 'الكل'; // له، عليه، الكل
  String _searchQuery = '';
  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();
  List<String> _projects = ['الكل'];

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadDebtData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('apartments')
          .get();
      
      Set<String> projectSet = {'الكل'};
      for (var doc in projectsSnapshot.docs) {
        final data = doc.data();
        final projectNumber = data['projectNumber']?.toString();
        if (projectNumber != null && projectNumber.isNotEmpty) {
          projectSet.add(projectNumber);
        }
      }
      
      if (mounted) {
        setState(() {
          _projects = projectSet.toList();
        });
      }
    } catch (e) {
      print('خطأ في تحميل المشاريع: $e');
    }
  }

  Future<void> _loadDebtData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // جلب بيانات الشقق مع العقود
      final apartmentsSnapshot = await FirebaseFirestore.instance
          .collection('apartments')
          .get();
      
      List<Map<String, dynamic>> debtList = [];
      
      for (var apartmentDoc in apartmentsSnapshot.docs) {
        final apartmentData = apartmentDoc.data();
        final pn = apartmentData['pn']?.toString() ?? '';
        final projectNumber = apartmentData['projectNumber']?.toString() ?? '';
        final clientIdentity = apartmentData['clientIdentity']?.toString() ?? '';
        
        if (pn.isEmpty) continue;
        
        // البحث عن العقد المرتبط
        String clientName = 'غير محدد';
        String clientPhone = '';
        
        try {
          final contractSnapshot = await FirebaseFirestore.instance
              .collection('contracts')
              .where('pn', isEqualTo: pn)
              .limit(1)
              .get();
          
          if (contractSnapshot.docs.isNotEmpty) {
            final contractData = contractSnapshot.docs.first.data();
            clientName = contractData['clientName']?.toString() ?? 'غير محدد';
            // محاولة التقاط رقم الجوال من عدة حقول محتملة
            clientPhone = contractData['clientData']?['phoneNumber']?.toString() ??
                          contractData['phoneNumber']?.toString() ??
                          contractData['clientPhoneNumber']?.toString() ?? '';
          }
        } catch (e) {
          print('خطأ في جلب بيانات العقد للشقة $pn: $e');
        }

        // إذا لم يوجد في العقد، جرّب حقول الشقة نفسها
        if (clientPhone.isEmpty) {
          clientPhone = apartmentData['clientPhone']?.toString() ??
                        apartmentData['clientMobile']?.toString() ?? '';
        }
        
        // حساب الرصيد الفعلي من المعاملات المالية (نفس طريقة صفحة العرض)
        double balance = await _calculateBalanceFromTransactions(pn);
        
        // إضافة البيانات إلى القائمة
        debtList.add({
          'pn': pn,
          'projectNumber': projectNumber,
          'clientName': clientName,
          'clientIdentity': clientIdentity,
          'clientPhone': clientPhone,
          'balance': balance,
          'debtType': balance > 0 ? 'له' : balance < 0 ? 'عليه' : 'متوازن',
        });
      }
      
      if (mounted) {
        setState(() {
          _debtData = debtList;
          _filteredDebtData = debtList;
          _isLoading = false;
        });
      }
      
      _applyFilters();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showError('حدث خطأ أثناء تحميل البيانات: ${e.toString()}');
    }
  }
  
  // حساب الرصيد من المعاملات المالية (نفس طريقة صفحة العرض)
  Future<double> _calculateBalanceFromTransactions(String pn) async {
    double balance = 0.0;
    
    try {
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('financialTransactions')
          .where('pn', isEqualTo: pn)
          .get();
      
      for (var transaction in transactionsSnapshot.docs) {
        final data = transaction.data();
        final amount = data['amount'] is int
            ? (data['amount'] as int).toDouble()
            : data['amount'] is double
            ? data['amount'] as double
            : 0.0;
        final type = data['debitCredit'] as String? ?? '';
        
        // له = دائن (موجب), عليه = مدين (سالب)
        balance += (type == 'له' || type == 'لة') ? amount : -amount;
      }
    } catch (e) {
      print('خطأ في حساب الرصيد للشقة $pn: $e');
    }
    
    return balance;
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_debtData);
    
    // فلتر المشروع
    if (_selectedProject != 'الكل') {
      filtered = filtered.where((item) => 
          item['projectNumber'] == _selectedProject).toList();
    }
    
    // فلتر نوع المديونية
    if (_selectedDebtType != 'الكل') {
      filtered = filtered.where((item) => 
          item['debtType'] == _selectedDebtType).toList();
    }
    
    // فلتر البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final clientName = item['clientName'].toString().toLowerCase();
        final clientIdentity = item['clientIdentity'].toString().toLowerCase();
        final pn = item['pn'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        return clientName.contains(query) || 
               clientIdentity.contains(query) || 
               pn.contains(query);
      }).toList();
    }
    
    if (mounted) {
      setState(() {
        _filteredDebtData = filtered;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _applyFilters();
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // يبني نص رسالة التذكير ويستبدل * باسم العميل و # برقم العقد
  String _buildReminderMessage({required String clientName, required String pn}) {
    final template = "عزيزي العميل/ة : * نود تذكيرك بضرورة سداد المبالغ المالية المتبقية لشركة مساكن الرفاهية على العقد : # في اقرب وقت ممكن , للاستفسار التواصل على 0509996115 شركة مساكن الرفاهية.";
    final displayName = clientName.isNotEmpty ? clientName : 'العميل الكريم';
    return template.replaceFirst('*', displayName).replaceFirst('#', pn);
  }

  // يفتح واتساب أولاً؛ وإن تعذر، يحاول فتح SMS
  Future<void> _launchWhatsAppOrSms(String? phone, String message) async {
    final encodedMessage = Uri.encodeComponent(message);

    // تحويل رقم الهاتف لشكل مناسب وإزالة الفراغات
    final normalizedPhone = (phone ?? '').replaceAll(RegExp(r'\s+'), '');

    final waUri = normalizedPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$normalizedPhone?text=$encodedMessage')
        : Uri.parse('https://wa.me/?text=$encodedMessage');

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // fallback إلى الرسائل القصيرة
    if (normalizedPhone.isNotEmpty) {
      final smsUri = Uri(scheme: 'sms', path: normalizedPhone, queryParameters: {'body': message});
      try {
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          return;
        }
      } catch (_) {}
    }

    _showError('تعذر فتح واتساب أو الرسائل القصيرة.');
  }

  // ينسّق بيانات العميل ويرسل رسالة التذكير عبر واتساب/SMS
  Future<void> _contactClient(Map<String, dynamic> item) async {
    final name = item['clientName']?.toString() ?? '';
    final pn = item['pn']?.toString() ?? '';
    final phone = item['clientPhone']?.toString();
    final message = _buildReminderMessage(clientName: name, pn: pn);

    await _launchWhatsAppOrSms(phone, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('عرض المديونية'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDebtData,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلاتر
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // شريط البحث
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'البحث باسم العميل أو رقم الهوية أو كود الشقة',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _onSearchChanged,
                ),
                SizedBox(height: 12),
                // الفلاتر
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedProject,
                        decoration: InputDecoration(
                          labelText: 'المشروع',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _projects.map((project) {
                          return DropdownMenuItem(
                            value: project,
                            child: Text(project),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProject = value!;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDebtType,
                        decoration: InputDecoration(
                          labelText: 'نوع المديونية',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: ['الكل', 'له', 'عليه', 'متوازن'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDebtType = value!;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // عرض النتائج
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredDebtData.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد بيانات مديونية',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                              DataColumn(label: Text('كود الشقة')),
                              DataColumn(label: Text('رقم المشروع')),
                              DataColumn(label: Text('اسم العميل')),
                              DataColumn(label: Text('رقم الهوية')),
                              DataColumn(label: Text('الرصيد')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('تواصل')),
                            ],
                            rows: _filteredDebtData.map((item) {
                              final balance = item['balance'] as double;
                              final debtType = item['debtType'] as String;
                              
                              Color balanceColor = Colors.black;
                              if (debtType == 'له') {
                                balanceColor = Colors.green;
                              } else if (debtType == 'عليه') {
                                balanceColor = Colors.red;
                              }

                              final canContact = debtType == 'عليه';
                              
                              return DataRow(
                                cells: [
                                  DataCell(Text(item['pn'] ?? '')),
                                  DataCell(Text(item['projectNumber'] ?? '')),
                                  DataCell(Text(item['clientName'] ?? '')),
                                  DataCell(Text(item['clientIdentity'] ?? '')),
                                  DataCell(
                                    Text(
                                      '${balance.abs().toStringAsFixed(2)} ريال',
                                      style: TextStyle(
                                        color: balanceColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: balanceColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: balanceColor),
                                      ),
                                      child: Text(
                                        debtType,
                                        style: TextStyle(
                                          color: balanceColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    canContact
                                        ? ElevatedButton.icon(
                                            onPressed: () => _contactClient(item),
                                            icon: Icon(Icons.chat),
                                            label: Text('تواصل'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          )
                                        : const Text('—'),
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
    );
  }
}