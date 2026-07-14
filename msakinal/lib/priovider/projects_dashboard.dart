import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:msakinal/priovider/auth_provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import '../brozinshin/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

// تعريف ChartData للمخططات
class ChartData {
  final String x;
  final int y;
  final Color color;

  ChartData(this.x, this.y, this.color);
}

class ProjectsDashboardScreen extends StatefulWidget {
  const ProjectsDashboardScreen({super.key});

  @override
  _ProjectsDashboardScreenState createState() =>
      _ProjectsDashboardScreenState();
}

class _ProjectsDashboardScreenState extends State<ProjectsDashboardScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedTabIndex = 0;
  String? _selectedProjectNumber;
  String? _selectedCustomerProjectFilter;
  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // قوائم البيانات
  List<DocumentSnapshot> _projects = [];
  List<DocumentSnapshot> _allApartments = [];
  List<DocumentSnapshot> _allCustomers = [];
  List<DocumentSnapshot> _allContracts = [];

  bool _isLoading = true;

  // متغيرات للفلترة
  List<String> _projectNumbers = [];

  // ألوان فاخرة للمخططات مع تدرجات
  final List<Color> _chartColors = [
    Color(0xFF1A237E), // Indigo 900
    Color(0xFF0D47A1), // Blue 900
    Color(0xFF1B5E20), // Green 900
    Color(0xFF4A148C), // Purple 900
    Color(0xFFB71C1C), // Red 900
    Color(0xFF004D40), // Teal 900
    Color(0xFFFF6F00), // Orange 900
    Color(0xFF3E2723), // Brown 900
  ];

  // تدرجات لونية فاخرة
  final List<LinearGradient> _luxuryGradients = [
    LinearGradient(
      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFFfc4a1a), Color(0xFFf7b733)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    LinearGradient(
      colors: [Color(0xFF8360c3), Color(0xFF2ebf91)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // إعداد الرسوم المتحركة
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _fetchAllData();

    // بدء الرسوم المتحركة
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // جلب بيانات المشاريع
      final projectsSnapshot = await _firestore.collection('projects').get();

      // جلب بيانات الوحدات
      final apartmentsSnapshot =
          await _firestore.collection('apartments').get();

      // جلب بيانات العملاء
      final customersSnapshot = await _firestore.collection('customers').get();

      // جلب بيانات العقود
      final contractsSnapshot = await _firestore.collection('contracts').get();

      if (mounted) {
        setState(() {
          _projects = projectsSnapshot.docs;
          _allApartments = apartmentsSnapshot.docs;
          _allCustomers = customersSnapshot.docs;
          _allContracts = contractsSnapshot.docs;

          // استخراج أرقام المشاريع
          Set<String> projectNumbersSet = {};
          for (var doc in _allApartments) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['projectNumber'] != null &&
                data['projectNumber'].toString().isNotEmpty) {
              projectNumbersSet.add(data['projectNumber'].toString());
            }
          }
          _projectNumbers = projectNumbersSet.toList();
          _projectNumbers.sort();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في جلب البيانات: $e')));
      }
      print("Error fetching data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3F51B5), Color(0xFF5C6BC0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: AppBar(
            title: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.dashboard_customize,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لوحة معلومات المشاريع',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: Offset(1, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'نظام إدارة شامل ومتطور',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              Container(
                margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53E3E), Color(0xFFFC8181)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFE53E3E).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _logout,
                  icon: Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'تسجيل الخروج',
                ),
              ),
            ],
          ),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل البيانات...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  // شريط التبويبات الفاخر
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Color(0xFFF8F9FA)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                        // إضافة رسوم متحركة عند تغيير التبويب
                        _slideController.reset();
                        _slideController.forward();
                      },
                      tabs: [
                        _buildLuxuryTab(Icons.dashboard_customize, 'نظرة عامة'),
                        _buildLuxuryTab(Icons.business_center, 'المشاريع'),
                        _buildLuxuryTab(Icons.people_alt, 'العملاء'),
                        _buildLuxuryTab(Icons.home_work, 'الوحدات'),
                      ],
                      labelColor: Color(0xFF1A237E),
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1A237E).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // محتوى التبويبات مع الرسوم المتحركة
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _slideAnimation,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildTabContent(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildProjectsTab();
      case 2:
        return _buildCustomersTab();
      case 3:
        return _buildUnitsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    // حساب الإحصائيات العامة
    int totalProjects = _projectNumbers.length;
    int totalUnits = _allApartments.length;
    int totalCustomers = _allCustomers.length;
    int soldUnits =
        _allApartments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'مباع' || data['status'] == 'مباعة';
        }).length;
    int availableUnits =
        _allApartments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'متاح' || data['status'] == 'متاحة';
        }).length;
    int reservedUnits =
        _allApartments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'محجوز' || data['status'] == 'محجوزة';
        }).length;

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان الرئيسي
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade700, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'نظرة عامة على المشاريع',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // بطاقات الإحصائيات الرئيسية الفاخرة
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return GridView.count(
                        crossAxisCount: isMobile ? 2 : 4,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        childAspectRatio: isMobile ? 1.0 : 1.2,
                        children: [
                          _buildEnhancedKPICard(
                            title: 'إجمالي المشاريع',
                            value: totalProjects.toString(),
                            icon: Icons.business_center,
                            gradient: _luxuryGradients[0],
                            subtitle: 'مشروع نشط',
                          ),
                          _buildEnhancedKPICard(
                            title: 'إجمالي الوحدات',
                            value: totalUnits.toString(),
                            icon: Icons.home_work,
                            gradient: _luxuryGradients[1],
                            subtitle: 'وحدة سكنية',
                          ),
                          _buildEnhancedKPICard(
                            title: 'إجمالي العملاء',
                            value: totalCustomers.toString(),
                            icon: Icons.people_alt,
                            gradient: _luxuryGradients[2],
                            subtitle: 'عميل مسجل',
                          ),
                          _buildEnhancedKPICard(
                            title: 'الوحدات المباعة',
                            value: soldUnits.toString(),
                            icon: Icons.check_circle_outline,
                            gradient: _luxuryGradients[3],
                            progressValue:
                                totalUnits > 0 ? soldUnits / totalUnits : 0,
                            subtitle:
                                '${((totalUnits > 0 ? soldUnits / totalUnits : 0) * 100).toStringAsFixed(1)}% مباع',
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),

            SizedBox(height: 32),

            // مخطط توزيع حالة الوحدات
            _buildChartCard('توزيع حالة الوحدات', [
              ChartData('متاحة', availableUnits, Colors.green),
              ChartData('مباعة', soldUnits, Colors.red),
              ChartData('محجوزة', reservedUnits, Colors.orange),
            ]),

            SizedBox(height: 16),

            // مخطط توزيع الوحدات حسب المشاريع
            _buildProjectUnitsChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsTab() {
    if (_projectNumbers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'لا توجد مشاريع لعرضها',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: ListView.builder(
        padding: EdgeInsets.all(16.0),
        itemCount: _projectNumbers.length,
        itemBuilder: (context, index) {
          final projectNumber = _projectNumbers[index];

          // حساب إحصائيات المشروع
          final projectUnits =
              _allApartments.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['projectNumber'] == projectNumber;
              }).toList();

          final soldUnits =
              projectUnits.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'مباع' || data['status'] == 'مباعة';
              }).length;

          final availableUnits =
              projectUnits.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'متاح' || data['status'] == 'متاحة';
              }).length;

          final reservedUnits =
              projectUnits.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'محجوز' || data['status'] == 'محجوزة';
              }).length;

          return Container(
            margin: EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF8F9FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 10,
                  spreadRadius: -5,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1A237E).withOpacity(0.3),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.business_center,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مشروع رقم $projectNumber',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.1),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF1A237E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Color(0xFF1A237E).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'إجمالي الوحدات: ${projectUnits.length}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A237E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // إحصائيات المشروع الفاخرة
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إحصائيات الوحدات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildLuxuryProjectStatCard(
                                'متاحة',
                                availableUnits.toString(),
                                LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF66BB6A),
                                  ],
                                ),
                                Icons.check_circle_outline,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildLuxuryProjectStatCard(
                                'مباعة',
                                soldUnits.toString(),
                                LinearGradient(
                                  colors: [
                                    Color(0xFFE53935),
                                    Color(0xFFEF5350),
                                  ],
                                ),
                                Icons.verified_outlined,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _buildLuxuryProjectStatCard(
                                'محجوزة',
                                reservedUnits.toString(),
                                LinearGradient(
                                  colors: [
                                    Color(0xFFFF9800),
                                    Color(0xFFFFB74D),
                                  ],
                                ),
                                Icons.schedule_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // شريط التقدم الفاخر
                  if (projectUnits.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1A237E).withOpacity(0.1),
                            Color(0xFF3F51B5).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF1A237E).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'نسبة المبيعات',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF1A237E),
                                      Color(0xFF3F51B5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${((soldUnits / projectUnits.length) * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.shade200,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: soldUnits / projectUnits.length,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1A237E),
                                ),
                                minHeight: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomersTab() {
    if (_allCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'لا توجد بيانات عملاء لعرضها',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // فلترة العملاء حسب المشروع
    List<DocumentSnapshot> filteredCustomers = _allCustomers;
    if (_selectedCustomerProjectFilter != null &&
        _selectedCustomerProjectFilter != 'الكل') {
      filteredCustomers =
          _allCustomers.where((customerDoc) {
            final customerData = customerDoc.data() as Map<String, dynamic>;
            List<dynamic> contractNumbers =
                customerData['contractNumbers'] ?? [];

            // التحقق من وجود وحدة في المشروع المحدد
            for (var contractNumber in contractNumbers) {
              final contractNumberStr = contractNumber.toString();
              final unit = _allApartments.where((unitDoc) {
                final unitData = unitDoc.data() as Map<String, dynamic>;
                return unitData['pn'] == contractNumberStr &&
                    unitData['projectNumber'] == _selectedCustomerProjectFilter;
              });
              if (unit.isNotEmpty) return true;
            }
            return false;
          }).toList();
    }

    return Column(
      children: [
        // شريط الفلترة
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text(
                'فلترة حسب المشروع:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCustomerProjectFilter,
                      hint: Text('جميع المشاريع'),
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCustomerProjectFilter = newValue;
                        });
                      },
                      items: [
                        DropdownMenuItem<String>(
                          value: 'الكل',
                          child: Text('جميع المشاريع'),
                        ),
                        ..._projectNumbers.map((String projectNumber) {
                          return DropdownMenuItem<String>(
                            value: projectNumber,
                            child: Text('مشروع $projectNumber'),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // قائمة العملاء
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAllData,
            child: ListView.builder(
              padding: EdgeInsets.all(16.0),
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final doc = filteredCustomers[index];
                final data = doc.data() as Map<String, dynamic>;

                String name = data['name'] ?? 'غير متوفر';
                String identityNumber = data['identityNumber'] ?? 'غير متوفر';
                String phoneNumber = data['phoneNumber'] ?? 'غير متوفر';
                List<dynamic> contractNumbers = data['contractNumbers'] ?? [];

                // البحث عن الوحدات المرتبطة بهذا العميل
                List<Map<String, dynamic>> customerUnits = [];
                for (var contractNumber in contractNumbers) {
                  final contractNumberStr = contractNumber.toString();
                  try {
                    final unit = _allApartments.firstWhere((unitDoc) {
                      final unitData = unitDoc.data() as Map<String, dynamic>;
                      return unitData['pn'] == contractNumberStr;
                    });
                    final unitData = unit.data() as Map<String, dynamic>;
                    customerUnits.add(unitData);
                  } catch (e) {
                    // إذا لم توجد الوحدة، تجاهل
                  }
                }

                return Container(
                  margin: EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Color(0xFFF8F9FA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Color(0xFF1A237E).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1A237E).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Text(phoneNumber, style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.home_work,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Text(
                              'عدد الوحدات: ${customerUnits.length}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.assignment,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Text(
                              'أرقام العقود: ${contractNumbers.map((e) => e.toString()).join(', ')}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // زر الاتصال الفاخر
                        Container(
                          margin: EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF4CAF50).withOpacity(0.3),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.phone,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _makePhoneCall(phoneNumber),
                            tooltip: 'اتصال',
                          ),
                        ),
                        // زر الواتساب الفاخر
                        Container(
                          margin: EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF25D366).withOpacity(0.3),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chat,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _sendWhatsAppMessage(phoneNumber, name),
                            tooltip: 'واتساب',
                          ),
                        ),
                      ],
                    ),
                    children: [
                      if (customerUnits.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الوحدات المرتبطة:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              ...customerUnits
                                  .map((unit) => _buildUnitCard(unit))
                                  .toList(),
                            ],
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'لا توجد وحدات مرتبطة بهذا العميل',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsTab() {
    if (_allApartments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'لا توجد وحدات لعرضها',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // متغير لتخزين الوحدات المفلترة
    List<DocumentSnapshot> filteredApartments = _allApartments;

    // إذا كان هناك مشروع محدد، قم بفلترة الوحدات
    if (_selectedProjectNumber != null && _selectedProjectNumber != 'الكل') {
      filteredApartments =
          _allApartments.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['projectNumber'] == _selectedProjectNumber;
          }).toList();
    }

    return Column(
      children: [
        // شريط الفلترة الفاخر
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A237E).withOpacity(0.05),
                Color(0xFF3F51B5).withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF1A237E).withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.filter_list, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'فلترة حسب المشروع:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Color(0xFFF8F9FA)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF1A237E).withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProjectNumber,
                      hint: Text(
                        'اختر مشروع',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF1A237E),
                      ),
                      style: TextStyle(
                        color: Color(0xFF1A237E),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('عرض الكل'),
                        ),
                        ..._projectNumbers.map((projectNumber) {
                          return DropdownMenuItem<String>(
                            value: projectNumber,
                            child: Text('مشروع $projectNumber'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedProjectNumber = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // عرض عدد الوحدات المفلترة بتصميم فاخر
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF1A237E).withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_work, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'عدد الوحدات: ${filteredApartments.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // قائمة الوحدات
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAllData,
            child: ListView.builder(
              padding: EdgeInsets.all(8.0),
              itemCount: filteredApartments.length,
              itemBuilder: (context, index) {
                final doc = filteredApartments[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildDetailedUnitCard(data);
              },
            ),
          ),
        ),
      ],
    );
  }

  // دالة لبناء تبويب فاخر
  Widget _buildLuxuryTab(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // دالة لبناء بطاقة KPI محسنة وفاخرة
  Widget _buildEnhancedKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    String? subtitle,
    double? progressValue,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 3,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(
            children: [
              // خلفية زخرفية
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // المحتوى الرئيسي
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'إحصائية',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (progressValue != null) ...[
                      SizedBox(height: 16),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withOpacity(0.3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.9),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    double? progressValue,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: Colors.white, size: 32),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'عدد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (progressValue != null) ...[
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // دالة لبناء بطاقة إحصائيات مشروع فاخرة
  Widget _buildLuxuryProjectStatCard(
    String title,
    String value,
    Gradient gradient,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> unit) {
    String pn = unit['pn'] ?? 'غير متوفر';
    String direction = unit['direction'] ?? 'غير متوفر';
    String area = unit['area']?.toString() ?? 'غير متوفر';
    String projectNumber = unit['projectNumber'] ?? 'غير متوفر';
    String description = unit['description'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3E5F5), Color(0xFFE8EAF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1A237E).withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(color: Color(0xFF1A237E).withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الوحدة رقم $pn في مشروع $projectNumber',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.indigo.shade700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'الاتجاه: $direction • المساحة: $area م²',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (description.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              'الوصف: $description',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedUnitCard(Map<String, dynamic> data) {
    String pn = data['pn'] ?? 'غير متوفر';
    String direction = data['direction'] ?? 'غير متوفر';
    String area = data['area']?.toString() ?? 'غير متوفر';
    String status = data['status'] ?? 'غير متوفر';
    String projectNumber = data['projectNumber'] ?? 'غير متوفر';
    String number = data['number']?.toString() ?? 'غير متوفر';
    String description = data['description'] ?? '';
    String floor = data['floor']?.toString() ?? 'غير متوفر';
    String city = data['city'] ?? 'غير متوفر';
    String district = data['district'] ?? 'غير متوفر';
    String clientName = data['clientName'] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFF8F9FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Color(0xFF1A237E).withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'الوحدة: $pn',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColorDark,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status,
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  backgroundColor:
                      status == 'متاح'
                          ? Colors.green
                          : (status == 'مباع' || status == 'مباعة'
                              ? Colors.red
                              : Colors.orange),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'المشروع: $projectNumber',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            if (clientName.isNotEmpty) ...[
              Text(
                'العميل: $clientName',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.indigo.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            Divider(height: 12, thickness: 0.5),
            Row(
              children: [
                Icon(Icons.square_foot, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text('مساحة: $area م²', style: TextStyle(fontSize: 12)),
                SizedBox(width: 10),
                Icon(Icons.layers, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text('دور: $floor', style: TextStyle(fontSize: 12)),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.explore_outlined, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text('اتجاه: $direction', style: TextStyle(fontSize: 12)),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_city, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'المدينة: $city, الحي: $district',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              SizedBox(height: 6),
              Text(
                'الوصف: $description',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, List<ChartData> data) {
    if (data.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text('لا توجد بيانات لعرض الرسم البياني لـ "$title"'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: data,
                    xValueMapper: (ChartData sales, _) => sales.x,
                    yValueMapper: (ChartData sales, _) => sales.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      connectorLineSettings: ConnectorLineSettings(
                        type: ConnectorType.curve,
                        length: '10%',
                      ),
                    ),
                    enableTooltip: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectUnitsChart() {
    Map<String, int> projectUnitsCount = {};

    for (var doc in _allApartments) {
      final data = doc.data() as Map<String, dynamic>;
      final projectNumber = data['projectNumber']?.toString() ?? 'غير محدد';
      projectUnitsCount[projectNumber] =
          (projectUnitsCount[projectNumber] ?? 0) + 1;
    }

    List<ChartData> chartData = [];
    int colorIndex = 0;

    projectUnitsCount.forEach((project, count) {
      chartData.add(
        ChartData(
          'مشروع $project',
          count,
          _chartColors[colorIndex % _chartColors.length],
        ),
      );
      colorIndex++;
    });

    return _buildChartCard('توزيع الوحدات حسب المشاريع', chartData);
  }

  // دالة للاتصال
  void _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('لا يمكن إجراء المكالمة')));
    }
  }

  // دالة لإرسال رسالة واتساب
  void _sendWhatsAppMessage(String phoneNumber, [String? customerName, double? amount]) async {
    // تنظيف رقم الهاتف من الرموز الإضافية
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    // إضافة رمز الدولة إذا لم يكن موجوداً
    if (!cleanNumber.startsWith('+')) {
      if (cleanNumber.startsWith('966')) {
        cleanNumber = '+$cleanNumber';
      } else if (cleanNumber.startsWith('05')) {
        cleanNumber = '+966${cleanNumber.substring(1)}';
      } else {
        cleanNumber = '+966$cleanNumber';
      }
    }

    // إنشاء رسالة احترافية
    String message = '🌟 السلام عليكم ورحمة الله وبركاته\n';
    
    if (customerName != null && customerName.isNotEmpty) {
      message += 'الأستاذ الكريم/ $customerName\n\n';
    } else {
      message += 'عميلنا الكريم\n\n';
    }
    
    message += '🏢 نتشرف بالتواصل معكم من شركة مساكن الأمل\n\n';
    
    if (amount != null && amount > 0) {
      message += '📋 نود إحاطتكم علماً بوجود مستحقات مالية قدرها:\n';
      message += '💰 ${amount.toStringAsFixed(2)} ريال سعودي\n\n';
      message += '🤝 نقدر ظروفكم ونتفهم التزاماتكم، ونرجو منكم التكرم بالتواصل معنا لمناقشة أفضل الحلول المناسبة لكم\n\n';
    } else {
      message += '🤝 نود التواصل معكم لمتابعة أموركم وتقديم أفضل الخدمات\n\n';
    }
    
    message += '📞 فريق خدمة العملاء في خدمتكم دائماً\n\n';
    message += '🙏 نشكركم لثقتكم الغالية وتعاونكم المستمر\n';
    message += 'مع أطيب التحيات 🌹';

    final Uri launchUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: cleanNumber,
      queryParameters: {'text': message},
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('لا يمكن فتح واتساب')));
    }
  }

  // دالة تسجيل الخروج
  Future<void> _logout() async {
    try {
      // إظهار مربع حوار للتأكيد
      bool? shouldLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE53E3E), Color(0xFFFC8181)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
            content: Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53E3E), Color(0xFFFC8181)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'تسجيل الخروج',
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

      if (shouldLogout == true) {
        // تسجيل الخروج من Firebase Auth
        await FirebaseAuth.instance.signOut();
        
        // تسجيل الخروج من AppAuthProvider
        await Provider.of<AppAuthProvider>(context, listen: false).logout();
        
        // التوجه إلى صفحة تسجيل الدخول
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginScreen1()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      // إظهار رسالة خطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الخروج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
