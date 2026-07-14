import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ContractsScreenl extends StatefulWidget {
  @override
  _ContractsScreenState createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreenl> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedProject = 'الكل';
  String _selectedSort = 'dateHijri_desc';
  String _selectedFilter = 'الكل';
  List<ContractData> _allContracts = [];
  List<ContractData> _filteredContracts = [];
  List<String> _availableProjects = ['الكل'];
  bool _isLoading = true;
  bool _isLoadingProjects = true;
  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchContracts();
    _searchController.addListener(_filterContracts);
  }

  Future<void> _fetchProjects() async {
    try {
      setState(() {
        _isLoadingProjects = true;
      });

      // جلب المشاريع المتاحة من جدول الوحدات
      QuerySnapshot apartmentsSnapshot =
          await FirebaseFirestore.instance.collection('apartments').get();

      Set<String> projectsSet = {'الكل'};

      for (QueryDocumentSnapshot doc in apartmentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String pn = data['pn'] ?? '';
        if (pn.isNotEmpty) {
          // استخراج رقم المشروع من PN (أول 3 أرقام)
          String projectNumber = pn.length >= 3 ? pn.substring(0, 3) : pn;
          projectsSet.add(projectNumber);
        }
      }

      if (mounted) {
        setState(() {
          _availableProjects = projectsSet.toList()..sort();
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      print('خطأ في جلب المشاريع: $e');
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  Future<void> _fetchContracts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // جلب جميع العقود
      QuerySnapshot contractsSnapshot =
          await FirebaseFirestore.instance.collection('contracts').get();

      List<ContractData> contracts = [];

      for (QueryDocumentSnapshot contractDoc in contractsSnapshot.docs) {
        Map<String, dynamic> contractData =
            contractDoc.data() as Map<String, dynamic>;
        String pn = contractData['pn'] ?? '';

        if (pn.isEmpty) continue;

        // جلب بيانات الشقة
        QuerySnapshot apartmentSnapshot =
            await FirebaseFirestore.instance
                .collection('apartments')
                .where('pn', isEqualTo: pn)
                .get();

        // جلب العمليات المالية
        QuerySnapshot financialSnapshot =
            await FirebaseFirestore.instance
                .collection('financialTransactions')
                .where('pn', isEqualTo: pn)
                .get();

        ContractData contract = ContractData(
          pn: pn,
          clientName: contractData['clientName'] ?? '',
          phoneNumber: contractData['clientData']?['phoneNumber'] ?? '',
          status: contractData['status'] ?? '',
          dateHijri: contractData['dateHijri'] ?? '',
          deliveryDays: contractData['deliveryDays']?.toInt() ?? 0,
          apartmentData:
              apartmentSnapshot.docs.isNotEmpty
                  ? apartmentSnapshot.docs.first.data() as Map<String, dynamic>
                  : {},
          financialTransactions:
              financialSnapshot.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList(),
        );

        contracts.add(contract);
      }

      if (mounted) {
        setState(() {
          _allContracts = contracts;
          _filteredContracts = contracts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('خطأ في جلب البيانات: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterContracts() {
    List<ContractData> filtered =
        _allContracts.where((contract) {
          // فلتر البحث
          bool matchSearch =
              _searchController.text.isEmpty ||
              contract.clientName.toLowerCase().contains(
                _searchController.text.toLowerCase(),
              ) ||
              contract.pn.contains(_searchController.text);

          // فلتر المشروع
          bool matchProject =
              _selectedProject == 'الكل' ||
              contract.pn.startsWith(_selectedProject);

          // فلتر المبلغ المتبقي
          bool matchFilter = true;
          if (_selectedFilter == 'متبقي') {
            matchFilter = contract.getRemainingAmount() > 0;
          } else if (_selectedFilter == 'مكتمل') {
            matchFilter = contract.getRemainingAmount() <= 0;
          }

          return matchSearch && matchProject && matchFilter;
        }).toList();

    // الترتيب
    filtered.sort((a, b) {
      switch (_selectedSort) {
        case 'dateHijri_asc':
          return a.dateHijri.compareTo(b.dateHijri);
        case 'dateHijri_desc':
          return b.dateHijri.compareTo(a.dateHijri);
        case 'remaining_asc':
          return a.getRemainingAmount().compareTo(b.getRemainingAmount());
        case 'remaining_desc':
          return b.getRemainingAmount().compareTo(a.getRemainingAmount());
        default:
          return 0;
      }
    });

    if (mounted) {
      setState(() {
        _filteredContracts = filtered;
      });
    }
  }

  Future<void> _launchWhatsApp(String phone, String name, String pn) async {
    String message =
        '🌟 السلام عليكم ورحمة الله وبركاته\n'
        'الأستاذ الكريم/ $name\n\n'
        '🏢 نتشرف بالتواصل معكم من شركة مساكن الرفاهية\n\n'
        '📋 بخصوص العقد رقم: $pn\n\n'
        '🤝 نود التواصل معكم لمتابعة أمور العقد وتقديم أفضل الخدمات\n\n'
        '📞 فريق خدمة العملاء في خدمتكم دائماً\n\n'
        '🙏 نشكركم لثقتكم الغالية وتعاونكم المستمر\n'
        'مع أطيب التحيات 🌹';
    String url =
        'https://wa.me/966${phone.replaceFirst('0', '')}?text=${Uri.encodeComponent(message)}';

    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,###', 'ar').format(amount) + ' ر.س';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مباع':
        return Colors.green;
      case 'تحت الإنشاء':
        return Colors.orange;
      case 'متاح':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'إدارة العقود العقارية',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // شريط الإحصائيات
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'إجمالي العقود',
                    _filteredContracts.length.toString(),
                    Icons.home,
                    Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'مكتملة السداد',
                    _filteredContracts
                        .where((c) => c.getRemainingAmount() <= 0)
                        .length
                        .toString(),
                    Icons.check_circle,
                    Colors.green[100]!,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'قيد التنفيذ',
                    _filteredContracts
                        .where((c) => c.status == 'تحت الإنشاء')
                        .length
                        .toString(),
                    Icons.construction,
                    Colors.orange[100]!,
                  ),
                ),
              ],
            ),
          ),

          // شريط الفلاتر
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // شريط البحث
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'البحث بالاسم أو رقم العقد...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.search,
                          color: Colors.indigo,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.indigo, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // فلاتر الخيارات
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedProject,
                        decoration: _buildDropdownDecoration('المشروع'),
                        items:
                            _isLoadingProjects
                                ? [
                                  DropdownMenuItem(
                                    value: 'الكل',
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.indigo,
                                                ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('جاري التحميل...'),
                                      ],
                                    ),
                                  ),
                                ]
                                : _availableProjects.map((project) {
                                  return DropdownMenuItem(
                                    value: project,
                                    child: Text(project),
                                  );
                                }).toList(),
                        onChanged:
                            _isLoadingProjects
                                ? null
                                : (value) {
                                  if (mounted) {
                                    setState(() {
                                      _selectedProject = value!;
                                    });
                                    _filterContracts();
                                  }
                                },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        decoration: _buildDropdownDecoration('الحالة'),
                        items:
                            ['الكل', 'متبقي', 'مكتمل'].map((filter) {
                              return DropdownMenuItem(
                                value: filter,
                                child: Text(filter),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _selectedFilter = value!;
                            });
                            _filterContracts();
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSort,
                        decoration: _buildDropdownDecoration('الترتيب'),
                        items: [
                          DropdownMenuItem(
                            value: 'dateHijri_desc',
                            child: Text('الأحدث أولاً'),
                          ),
                          DropdownMenuItem(
                            value: 'dateHijri_asc',
                            child: Text('الأقدم أولاً'),
                          ),
                          DropdownMenuItem(
                            value: 'remaining_desc',
                            child: Text('المتبقي (الأعلى)'),
                          ),
                          DropdownMenuItem(
                            value: 'remaining_asc',
                            child: Text('المتبقي (الأقل)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              _selectedSort = value!;
                            });
                            _filterContracts();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // قائمة العقود
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Container(
                        padding: EdgeInsets.all(20),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.indigo,
                              ),
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'جاري تحميل العقود...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'يرجى الانتظار',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : _filteredContracts.isEmpty
                    ? Center(
                      child: Container(
                        padding: EdgeInsets.all(24),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد عقود',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'لم يتم العثور على عقود تطابق معايير البحث',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: () async {
                        await _fetchProjects();
                        await _fetchContracts();
                      },
                      color: Colors.indigo,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredContracts.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap:
                                () => _showContractDetails(
                                  _filteredContracts[index],
                                ),
                            child: _buildContractCard(
                              _filteredContracts[index],
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            color == Colors.white
                ? Colors.white.withOpacity(0.95)
                : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              color == Colors.white
                  ? Colors.white.withOpacity(0.8)
                  : color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (color == Colors.white ? Colors.indigo : color).withOpacity(
              0.1,
            ),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color == Colors.white ? Colors.indigo : color)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color == Colors.white ? Colors.indigo : color,
              size: 28,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  color == Colors.white
                      ? Colors.indigo[800]
                      : Colors.indigo[800],
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  color == Colors.white
                      ? Colors.indigo[600]
                      : Colors.indigo[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.indigo[600],
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.indigo, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildContractCard(ContractData contract) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 6,
        shadowColor: Colors.indigo.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.indigo.withOpacity(0.1), width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصف الأول: رقم العقد والحالة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          contract.status,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(
                            contract.status,
                          ).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        contract.status,
                        style: TextStyle(
                          color: _getStatusColor(contract.status),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      contract.pn,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // اسم العميل
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        contract.clientName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // معلومات الشقة والاتصال
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.square_foot,
                            'المساحة',
                            '${contract.apartmentData['area'] ?? 'غير محدد'}م²',
                          ),
                          SizedBox(height: 4),
                          _buildInfoRow(
                            Icons.layers,
                            'الطابق',
                            contract.apartmentData['floor'] ?? 'غير محدد',
                          ),
                          SizedBox(height: 4),
                          _buildInfoRow(
                            Icons.explore,
                            'الاتجاه',
                            contract.apartmentData['direction'] ?? 'غير محدد',
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap:
                            () => _launchWhatsApp(
                              contract.phoneNumber,
                              contract.clientName,
                              contract.pn,
                            ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              contract.phoneNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // المعلومات المالية
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'الإجمالي',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatCurrency(contract.getTotalAmount()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'المدفوع',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatCurrency(contract.getPaidAmount()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'المتبقي',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatCurrency(contract.getRemainingAmount()),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    contract.getRemainingAmount() > 0
                                        ? Colors.red[700]
                                        : Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // مدة التسليم المتبقية (إذا كان هناك متبقي)
                if (contract.getRemainingAmount() > 0 &&
                    contract.deliveryDays > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                          SizedBox(width: 4),
                          Text(
                            'مدة التسليم: ${contract.getRemainingDeliveryDays()} يوم',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
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

  Widget _buildInfoRow(dynamic iconOrLabel, String label, [String? value]) {
    // Handle both the old 3-parameter version and new 2-parameter version
    if (iconOrLabel is IconData && value != null) {
      // Old version with icon
      return Row(
        children: [
          Icon(iconOrLabel, size: 14, color: Colors.grey[600]),
          SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      // New version for modal details
      String labelText = iconOrLabel.toString();
      String valueText = label; // In this case, label is actually the value
      return Container(
        margin: EdgeInsets.symmetric(vertical: 6),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                labelText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo[700],
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                valueText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showContractDetails(ContractData contract) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'تفاصيل العقد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.confirmation_number,
                    'رقم العقد',
                    contract.pn,
                  ),
                  _buildInfoRow(
                    Icons.person,
                    'اسم العميل',
                    contract.clientName,
                  ),
                  _buildInfoRow(
                    Icons.phone,
                    'رقم الجوال',
                    contract.phoneNumber,
                  ),
                  _buildInfoRow(Icons.info, 'الحالة', contract.status),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'تاريخ العقد (هجري)',
                    contract.dateHijri,
                  ),
                  _buildInfoRow(
                    Icons.timer,
                    'مدة التسليم',
                    '${contract.deliveryDays} يوم',
                  ),
                  Divider(height: 24),
                  Text(
                    'بيانات الشقة:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildInfoRow(
                    Icons.square_foot,
                    'المساحة',
                    '${contract.apartmentData['area'] ?? 'غير محدد'}م²',
                  ),
                  _buildInfoRow(
                    Icons.layers,
                    'الطابق',
                    contract.apartmentData['floor'] ?? 'غير محدد',
                  ),
                  _buildInfoRow(
                    Icons.explore,
                    'الاتجاه',
                    contract.apartmentData['direction'] ?? 'غير محدد',
                  ),
                  Divider(height: 24),
                  Text(
                    'العمليات المالية:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...contract.financialTransactions.map(
                    (t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(
                            t['debitCredit'] == 'عليه'
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color:
                                t['debitCredit'] == 'عليه'
                                    ? Colors.red
                                    : Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${t['description'] ?? ''}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            '${t['amount'] ?? 0} ر.س',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // زر مراسلة بالواتساب
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF25D366).withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          Icons.message,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          'مراسلة بالواتساب',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () {
                          _launchWhatsApp(
                            contract.phoneNumber,
                            contract.clientName,
                            contract.pn,
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ContractData {
  final String pn;
  final String clientName;
  final String phoneNumber;
  final String status;
  final String dateHijri;
  final int deliveryDays;
  final Map<String, dynamic> apartmentData;
  final List<Map<String, dynamic>> financialTransactions;
  ContractData({
    required this.pn,
    required this.clientName,
    required this.phoneNumber,
    required this.status,
    required this.dateHijri,
    required this.deliveryDays,
    required this.apartmentData,
    required this.financialTransactions,
  });
  double getTotalAmount() {
    return financialTransactions
        .where((t) => t['debitCredit'] == 'عليه')
        .fold(0.0, (sum, t) => sum + (t['amount']?.toDouble() ?? 0.0));
  }

  double getPaidAmount() {
    return financialTransactions
        .where((t) => t['debitCredit'] == 'له')
        .fold(0.0, (sum, t) => sum + (t['amount']?.toDouble() ?? 0.0));
  }

  double getRemainingAmount() {
    return getTotalAmount() - getPaidAmount();
  }

  int getRemainingDeliveryDays() {
    try {
      List<String> dateParts = dateHijri.split('-');
      if (dateParts.length == 3) {
        DateTime contractDate = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
        );
        DateTime deliveryDate = contractDate.add(Duration(days: deliveryDays));
        DateTime now = DateTime.now();
        return deliveryDate.difference(now).inDays;
      }
    } catch (e) {
      print('خطأ في حساب المدة المتبقية: $e');
    }
    return 0;
  }
}
