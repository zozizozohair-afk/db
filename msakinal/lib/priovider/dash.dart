import 'dart:ui';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../brozinshin/dash/dashboard_service.dart';
import '../brozinshin/mapyat/2222.dart';
import '../brozinshin/mapyat/mshro.dart';
import '../brozinshin/الماليه/arth.dart';
import '../class/التحديثات.dart';
import 'projects_dashboard.dart';

// تعريف ChartData في بداية الملف أو في ملف منفصل
class ChartData {
  final String x;
  final int y;
  final Color color;

  ChartData(this.x, this.y, this.color);
}

class NewProfessionalDashboardScreen extends StatefulWidget {
  const NewProfessionalDashboardScreen({super.key});

  @override
  _NewProfessionalDashboardScreenState createState() =>
      _NewProfessionalDashboardScreenState();
}

class _NewProfessionalDashboardScreenState
    extends State<NewProfessionalDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedTabIndex = 0;
  // ignore: prefer_typing_uninitialized_variables
  double amount = 0.0;
  String? _selectedProjectNumber;
  List<DocumentSnapshot> _projects = [];
  List<DocumentSnapshot> _units = [];
  List<DocumentSnapshot> _financialTransactions = [];
  bool _isLoading = true; // للبيانات الحالية (المشاريع والوحدات)

  // متغيرات جديدة للبيانات المطلوبة
  List<DocumentSnapshot> _allApartments = [];
  List<DocumentSnapshot> _allContracts = [];
  List<DocumentSnapshot> _allCustomers = [];
  List<DocumentSnapshot> _allFinancialTransactions = [];
  bool _isLoadingData = true; // لبيانات الوحدات والعقود والعملاء الجديدة

  // متغيرات للعملاء المدينين
  List<Map<String, dynamic>> _topDebtorCustomers = [];
  bool _isLoadingDebtors = false;

  // متغيرات لشقق إعادة البيع
  List<DocumentSnapshot> _resaleApartments = [];
  bool _isLoadingResaleApartments = false;

  // متغيرات للفلترة
  List<String> _projectNumbers = [];
  Map<String, dynamic> _dashboardData = {};

  final Map<String, List<ChartData>> _projectUnitStatusData = {};

  // ألوان جذابة للمخططات
  final List<Color> _chartColors = [
    Colors.blue.shade700,
    Colors.green.shade600,
    Colors.orange.shade700,
    Colors.purple.shade600,
    Colors.red.shade600,
    Colors.teal.shade600,
    Colors.amber.shade700,
    Colors.indigo.shade600,
  ];
  final Map<String, List<ChartData>> _projectFinancialData = {};

  @override
  void initState() {
    super.initState();
    _fetchProjectData(); // الحفاظ على جلب البيانات الحالي
    _fetchAllCollectionsData(); // إضافة جلب البيانات الجديدة
    _loadDashboardData();
    _loadProjectNumbers();
    _loadTopDebtorCustomers(); // تحميل العملاء المدينين
    _loadResaleApartments(); // تحميل شقق إعادة البيع
  }

  Future<void> _fetchProjectData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final projectsSnapshot = await _firestore.collection('projects').get();
      if (mounted) {
        setState(() {
          _projects = projectsSnapshot.docs;
          if (_projects.isNotEmpty && _selectedProjectNumber == null) {
            _selectedProjectNumber = _projects.first.id;
            _fetchUnitData(_selectedProjectNumber!);
            _fetchFinancialData(_selectedProjectNumber!);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب بيانات المشاريع: $e')),
        );
      }
      print("Error fetching project data: $e");
    }
  }

  Future<void> _fetchUnitData(String projectNumber) async {
    if (!mounted) return;
    try {
      final unitsSnapshot =
          await _firestore
              .collection('apartments')
              .where('projectNumber', isEqualTo: projectNumber)
              .get();
      if (mounted) {
        setState(() {
          _units = unitsSnapshot.docs;
          _projectUnitStatusData[projectNumber] = _getUnitStatusChartData(
            _units,
          );
        });
      }
    } catch (e) {
      print("Error fetching unit data: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب بيانات الوحدات: $e')),
        );
      }
    }
  }

  Future<void> _fetchFinancialData(String projectNumber) async {
    if (!mounted) return;
    try {
      final financialSnapshot =
          await _firestore
              .collection('financialTransactions')
              .where('projectNumber', isEqualTo: projectNumber)
              .get();
      if (mounted) {
        setState(() {
          _financialTransactions = financialSnapshot.docs;
          _projectFinancialData[projectNumber] = _getFinancialChartData(
            _financialTransactions,
          );
        });
      }
    } catch (e) {
      print("Error fetching financial data: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب البيانات المالية: $e')),
        );
      }
    }
  }

  // دالة جديدة لجلب جميع العمليات المالية
  Future<void> _fetchAllFinancialData() async {
    if (!mounted) return;
    try {
      final financialSnapshot =
          await _firestore.collection('financialTransactions').get();
      if (mounted) {
        setState(() {
          _allFinancialTransactions = financialSnapshot.docs;
        });
      }
    } catch (e) {
      print("Error fetching all financial data: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب جميع البيانات المالية: $e')),
        );
      }
    }
  }

  // دالة جديدة لجلب بيانات الوحدات، العقود، والعملاء
  Future<void> _fetchAllCollectionsData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
    });
    try {
      final apartmentsSnapshot =
          await _firestore.collection('apartments').get();
      final contractsSnapshot = await _firestore.collection('contracts').get();
      // افترض أن اسم مجموعة العملاء هو 'customers' بناءً على طلبك
      final customersSnapshot = await _firestore.collection('customers').get();

      // جلب جميع العمليات المالية
      await _fetchAllFinancialData();

      if (mounted) {
        setState(() {
          _allApartments = apartmentsSnapshot.docs;
          _allContracts = contractsSnapshot.docs;
          _allCustomers = customersSnapshot.docs;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
      print("Error fetching all collections data: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء جلب البيانات: $e')),
        );
      }
    }
  }

  // تحميل أرقام المشاريع للفلترة
  Future<void> _loadProjectNumbers() async {
    try {
      final projectsSnapshot = await _firestore.collection('apartments').get();
      Set<String> projectNumbersSet = {};

      for (var doc in projectsSnapshot.docs) {
        final data = doc.data();
        if (data['projectNumber'] != null &&
            data['projectNumber'].toString().isNotEmpty) {
          projectNumbersSet.add(data['projectNumber'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _projectNumbers = projectNumbersSet.toList();
          _projectNumbers.sort(); // ترتيب أرقام المشاريع
        });
      }
    } catch (e) {
      print('Error loading project numbers: $e');
    }
  }

  // تحميل بيانات لوحة المعلومات
  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() {
        _isLoadingData = true;
      });
    }

    try {
      // استخدام خدمة لوحة المعلومات
      final dashboardService = DashboardService();
      final data = await dashboardService.fetchDashboardData(
        projectFilter: _selectedProjectNumber,
      );

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  } // إنشاء بطاقات مؤشرات الأداء الرئيسية

  Widget _buildKPICards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 2 : 4;
        final cardHeight = isMobile ? 180.0 : 220.0;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isMobile ? 0.9 : 1.1,
          children: [
            _buildLuxuryKPICard(
              context,
              title: 'إجمالي الوحدات',
              value: _dashboardData['totalUnits']?.toString() ?? '0',
              icon: Icons.apartment_outlined,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade800, Colors.blueAccent.shade400],
              ),
              badgeText: 'المجموع الكلي',
              height: cardHeight,
            ),
            _buildLuxuryKPICard(
              context,
              title: 'الوحدات المباعة',
              value: _dashboardData['soldUnits']?.toString() ?? '0',
              icon: Icons.verified_user_outlined,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade800, Colors.tealAccent.shade400],
              ),
              badgeText: 'تم البيع',
              height: cardHeight,
              progressValue:
                  _dashboardData['totalUnits'] != null &&
                          _dashboardData['totalUnits'] != 0
                      ? (_dashboardData['soldUnits'] /
                          _dashboardData['totalUnits'])
                      : 0,
            ),
            _buildLuxuryKPICard(
              context,
              title: 'الوحدات المتاحة',
              value: _dashboardData['availableUnits']?.toString() ?? '0',
              icon: Icons.event_available_outlined,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade800, Colors.amber.shade400],
              ),
              badgeText: 'جاهزة',
              height: cardHeight,
            ),
            _buildLuxuryKPICard(
              context,
              title: 'الوحدات المحجوزة',
              value: _dashboardData['reservedUnits']?.toString() ?? '0',
              icon: Icons.bookmark_added_outlined,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade800, Colors.purpleAccent.shade400],
              ),
              badgeText: 'محجوز',
              height: cardHeight,
            ),
            if (!isMobile) ...[
              _buildLuxuryKPICard(
                context,
                title: 'تحت الإجراء',
                value: _dashboardData['activeContracts']?.toString() ?? '0',
                icon: Icons.description_outlined,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.teal.shade800, Colors.cyanAccent.shade400],
                ),
                badgeText: 'قيد التنفيذ',
                height: cardHeight,
              ),
              _buildLuxuryKPICard(
                context,
                title: 'مستلمة',
                value: '${_dashboardData['deliveredUnits'] ?? '0'}',
                icon: Icons.home_work_outlined,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.indigo.shade800,
                    Colors.indigoAccent.shade400,
                  ],
                ),
                badgeText: 'تم التسليم',
                height: cardHeight,
                subtitle: '${_dashboardData['percentDelivered']}% من الإجمالي',
              ),
              _buildLuxuryKPICard(
                context,
                title: 'تحت الإنشاء',
                value: '${_dashboardData['underConstructionUnits'] ?? '0'}',
                icon: Icons.construction_outlined,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.amber.shade800, Colors.amberAccent.shade400],
                ),
                badgeText: 'قيد الإنشاء',
                height: cardHeight,
              ),
              _buildLuxuryKPICard(
                context,
                title: 'إعادة بيع',
                value: '${_dashboardData['resaleUnits'] ?? '0'}',
                icon: Icons.repeat_outlined,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.cyan.shade800, Colors.cyanAccent.shade400],
                ),
                badgeText: 'إعادة بيع',
                height: cardHeight,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLuxuryKPICard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    required String badgeText,
    double? progressValue,
    String? subtitle,
    required double height,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          // الظل الخارجي العلوي الأيسر (فاتح)
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF4A5568).withOpacity(0.5)
                    : Colors.white.withOpacity(0.7),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(-8, -8),
          ),
          // الظل الخارجي السفلي الأيمن (غامق)
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Colors.grey.shade400.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(8, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // الخلفية المزخرفة
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                child: Opacity(
                  opacity: 0.05,
                  child: Icon(
                    icon,
                    size: 120,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),

          // محتوى البطاقة
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الشارة العلوية
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF4A5568) : Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF1A202C).withOpacity(0.5)
                                : Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF4A5568).withOpacity(0.5)
                                : Colors.white,
                        blurRadius: 4,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(),

                // القيمة الرئيسية
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                    height: 1,
                  ),
                ),

                // العنوان
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Color(0xFFCBD5E0) : Color(0xFF4A5568),
                  ),
                ),

                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Color(0xFFA0AEC0) : Color(0xFF718096),
                    ),
                  ),
                ],

                const Spacer(),

                // شريط التقدم (إذا وجد)
                if (progressValue != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isDark ? Color(0xFF4A5568) : Color(0xFFD1D5DB),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDark
                                  ? Color(0xFF1A202C).withOpacity(0.8)
                                  : Colors.grey.shade300,
                          blurRadius: 3,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Color(0xFF68D391) : Color(0xFF38A169),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],

                // أيقونة دائرية
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDark
                                  ? Color(0xFF4A5568).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.7),
                          blurRadius: 8,
                          offset: const Offset(-4, -4),
                        ),
                        BoxShadow(
                          color:
                              isDark
                                  ? Color(0xFF1A202C).withOpacity(0.8)
                                  : Colors.grey.shade400.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // إنشاء بطاقة مؤشر أداء رئيسي واحدة
  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double iconSize = 40,
    double titleSize = 16,
    double valueSize = 22,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.8), color],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: Colors.white),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: titleSize,
                ),
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // إنشاء مخططات توزيع الوحدات
  Widget _buildUnitDistributionCharts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            'توزيع الوحدات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade800,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildPieChart(
                'توزيع حالات الوحدات',
                _getChartDataFromMap(
                  _dashboardData['statusDistribution'] ?? {},
                ),
              ),
            ),
            Expanded(
              child: _buildPieChart(
                'توزيع الوحدات حسب الطابق',
                _getChartDataFromMap(_dashboardData['floorDistribution'] ?? {}),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildPieChart(
          'توزيع الوحدات حسب المشروع',
          _getChartDataFromMap(_dashboardData['projectDistribution'] ?? {}),
        ),
      ],
    );
  }

  // إنشاء مخطط دائري
  Widget _buildPieChart(String title, List<ChartData> data) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                series: <CircularSeries>[
                  DoughnutSeries<ChartData, String>(
                    dataSource: data,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      connectorLineSettings: ConnectorLineSettings(
                        type: ConnectorType.curve,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تحويل البيانات من Map إلى قائمة ChartData
  List<ChartData> _getChartDataFromMap(Map<String, dynamic> map) {
    List<ChartData> result = [];
    int colorIndex = 0;

    map.forEach((key, value) {
      result.add(
        ChartData(
          key,
          value is int ? value : int.tryParse(value.toString()) ?? 0,
          _chartColors[colorIndex % _chartColors.length],
        ),
      );
      colorIndex++;
    });

    return result;
  }

  List<ChartData> _getUnitStatusChartData(List<DocumentSnapshot> units) {
    Map<String, int> statusCounts = {};

    for (var unit in units) {
      final data = unit.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'غير محدد';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    List<ChartData> chartData = [];

    // تعيين ألوان مختلفة لكل حالة من قائمة الألوان المحددة مسبقًا
    Map<String, Color> statusColors = {
      'متاح': Colors.green,
      'مباع': Colors.red,
      'محجوز': Colors.orange,
      'معروضة للبيع': Colors.blue,
      'تم الإفراغ': Colors.purple,
      'تحت الاجراء': Colors.teal,
      'تم الافراغ': Colors.purple,
      'متاحة': Colors.green,
      'تحت الإنشاء': Colors.amber,
      'إعادة بيع': Colors.cyan,
      'معاد بيعها': Colors.cyan,
      'تمت إعادة البيع': Colors.cyan,
      'محجوزة': Colors.orange,
      'تم التنازل': Colors.indigo,
      'جديد': Colors.lightGreen,
      'تم الإنشاء': Colors.deepPurple,
      'مباعة': Colors.red,
      'غير محدد': Colors.grey,
    };

    statusCounts.forEach((status, count) {
      chartData.add(
        ChartData(status, count, statusColors[status] ?? Colors.blue),
      );
    });

    return chartData;
  }

  List<ChartData> _getFinancialChartData(List<DocumentSnapshot> transactions) {
    Map<String, int> typeCounts = {};

    for (var transaction in transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      final type = data['type'] ?? 'غير محدد';
      final amount =
          data['amount'] is num
              ? (data['amount'] as num).toDouble()
              : double.tryParse(data['amount'].toString()) ?? 0.0;

      typeCounts[type] = ((typeCounts[type] ?? 0) + amount) as int;
    }

    List<ChartData> chartData = [];

    // تعيين ألوان مختلفة لكل نوع معاملة
    Map<String, Color> typeColors = {
      'إيراد': Colors.green,
      'مصروف': Colors.red,
      'دفعة': Colors.blue,
      'غير محدد': Colors.grey,
    };

    typeCounts.forEach((type, amount) {
      chartData.add(ChartData(type, amount, typeColors[type] ?? Colors.purple));
    });

    return chartData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildCustomAppBar(context),
          Expanded(
            child:
                _isLoading || _isLoadingData
                    ? Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: () async {
                        await _loadDashboardData();
                        await _loadProjectNumbers();
                      },
                      child: _buildDashboardContent(),
                    ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.95), Colors.grey.shade50],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 1,
              offset: Offset(0, -5),
            ),
            BoxShadow(
              color: Colors.blue.withOpacity(0.05),
              blurRadius: 15,
              spreadRadius: 0,
              offset: Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedTabIndex,
            onTap: (index) {
              setState(() {
                _selectedTabIndex = index;
                if (index == 1 && _projects.isNotEmpty) {
                  // Project Specific Tab
                  _selectedProjectNumber = _projects.first.id;
                  _fetchUnitData(_selectedProjectNumber!);
                  _fetchFinancialData(_selectedProjectNumber!);
                } else if (index == 1 && _projects.isEmpty) {
                  // Handle case where projects are not loaded yet for project specific tab
                  print("Projects not loaded yet for project specific tab.");
                }
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Color(0xFF1565C0), // أزرق أكثر حيوية
            unselectedItemColor: Color(0xFF9E9E9E),
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
            items: [
              BottomNavigationBarItem(
                icon: _buildNavIcon(
                  Icons.dashboard_outlined,
                  Icons.dashboard,
                  0,
                ),
                label: 'نظرة عامة',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.business_outlined, Icons.business, 1),
                label: 'المشاريع',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(
                  Icons.attach_money_outlined,
                  Icons.attach_money,
                  2,
                ),
                label: 'المالية',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(
                  Icons.home_work_outlined,
                  Icons.home_work,
                  3,
                ),
                label: 'الوحدات',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.article_outlined, Icons.article, 4),
                label: 'العقود',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.people_outline, Icons.people, 5),
                label: 'العملاء',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.update_outlined, Icons.update, 6),
                label: 'التحديثات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _isLoading || _isLoadingData
            ? Center(child: CircularProgressIndicator())
            : _buildOverviewTab();
      case 1:
        return ProjectsPage11();
      case 2:
        return _isLoading || _isLoadingData
            ? Center(child: CircularProgressIndicator())
            : _buildFinancialSummaryTab();
      case 3:
        return _buildApartmentsTab();
      case 4:
        return ContractsPage();
      case 5:
        return _buildCustomersTab();
      case 6:
        return LuxuryLogsPage();
      default:
        return Center(child: Text('صفحة غير موجودة'));
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان لوحة المعلومات

          // ملخص سريع لآخر الأحداث
          _buildRecentEventsSection(),

          SizedBox(height: 24),

          // بطاقات مؤشرات الأداء الرئيسية
          _buildKPICards(),

          SizedBox(height: 24),

          // قسم العملاء المدينين
          _buildTopDebtorsSection(),

          SizedBox(height: 24),

          // قسم شقق إعادة البيع
          _buildResaleApartmentsSection(),

          SizedBox(height: 24),

          // مخططات توزيع الوحدات
          _buildUnitDistributionCharts(),

          SizedBox(height: 24),

          // مخططات العقود والإيرادات
        ],
      ),
    );
  }

  Widget _buildProjectSpecificTab() {
    if (_selectedProjectNumber == null) {
      return Center(child: Text('الرجاء اختيار مشروع لعرض تفاصيله.'));
    }

    // البحث عن المشروع المحدد
    DocumentSnapshot? selectedProject;
    for (var project in _projects) {
      if (project.id == _selectedProjectNumber) {
        selectedProject = project;
        break;
      }
    }

    if (selectedProject == null) {
      return Center(child: Text('لم يتم العثور على المشروع المحدد.'));
    }

    final projectData = selectedProject.data() as Map<String, dynamic>;
    final projectName = projectData['name'] ?? 'مشروع بدون اسم';
    final projectLocation = projectData['location'] ?? 'موقع غير محدد';

    // الوحدات الخاصة بهذا المشروع
    final projectUnits =
        _allApartments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['projectNumber'] == _selectedProjectNumber;
        }).toList();

    // العقود الخاصة بهذا المشروع
    final projectContracts =
        _allContracts.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['projectNumber'] == _selectedProjectNumber;
        }).toList();

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'تفاصيل المشروع: $projectName',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم المشروع: $_selectedProjectNumber',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 5),
                Text(
                  'الموقع: $projectLocation',
                  style: TextStyle(fontSize: 16),
                ),
                // يمكن إضافة المزيد من تفاصيل المشروع هنا
              ],
            ),
          ),
        ),
        SizedBox(height: 20),

        // إحصائيات الوحدات في هذا المشروع
        Text(
          'إحصائيات الوحدات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'إجمالي الوحدات',
                projectUnits.length.toString(),
                Icons.home_work,
                color: Colors.teal,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildInfoCard(
                'إجمالي العقود',
                projectContracts.length.toString(),
                Icons.article,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        // رسم بياني لحالة الوحدات في هذا المشروع
        _buildChartCard(
          'توزيع حالة الوحدات',
          _getUnitStatusChartData(projectUnits),
        ),

        SizedBox(height: 20),
        // رسم بياني للبيانات المالية لهذا المشروع
        _buildChartCard(
          'ملخص البيانات المالية',
          _projectFinancialData[_selectedProjectNumber] ?? [],
        ),
      ],
    );
  }

  Widget _buildFinancialSummaryTab() {
    if (_allContracts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'لا توجد بيانات مالية لعرضها',
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

    // حساب الإحصائيات المالية
    double totalOwedAmount = 0; // إجمالي المبالغ المطلوبة (عليه)
    double totalPaidAmount = 0; // إجمالي المبالغ المدفوعة (له)
    double totalRemainingAmount = 0;
    Map<String, Map<String, double>> projectFinancials = {};

    // حساب إجمالي المبالغ من العمليات المالية
    print(
      'DEBUG: _allFinancialTransactions count: ${_allFinancialTransactions.length}',
    );

    if (_allFinancialTransactions.isNotEmpty) {
      for (var transaction in _allFinancialTransactions) {
        final data = transaction.data() as Map<String, dynamic>;
        final debitCredit = data['debitCredit'] ?? '';
        final amount =
            data['amount'] != null
                ? (data['amount'] is double
                    ? data['amount']
                    : double.tryParse(data['amount'].toString()) ?? 0)
                : 0;

        final projectNumber = data['projectNumber'] ?? 'غير محدد';

        // تهيئة بيانات المشروع
        if (projectFinancials[projectNumber] == null) {
          projectFinancials[projectNumber] = {
            'total': 0,
            'paid': 0,
            'remaining': 0,
          };
        }

        print(
          'DEBUG Transaction: debitCredit=$debitCredit, amount=$amount, project=$projectNumber',
        );

        if (debitCredit == 'عليه') {
          // المبالغ المطلوبة من العميل
          totalOwedAmount += amount;
          projectFinancials[projectNumber]!['total'] =
              (projectFinancials[projectNumber]!['total'] ?? 0) + amount;
          print(
            'DEBUG: Adding owed amount: $amount for project: $projectNumber',
          );
        } else if (debitCredit == 'له' || debitCredit == 'لة') {
          // المبالغ المدفوعة من العميل
          totalPaidAmount += amount;
          projectFinancials[projectNumber]!['paid'] =
              (projectFinancials[projectNumber]!['paid'] ?? 0) + amount;
          print('DEBUG: Adding payment: $amount for project: $projectNumber');
        }
      }
    } else {
      print('DEBUG: No financial transactions found or empty list');
    }

    print('DEBUG: Total owed amount calculated: $totalOwedAmount');
    print('DEBUG: Total paid amount calculated: $totalPaidAmount');

    // حساب المبالغ المتبقية (المديونية الفعلية)
    totalRemainingAmount = totalOwedAmount - totalPaidAmount;

    // تحديث المبالغ المتبقية لكل مشروع
    projectFinancials.forEach((projectNumber, amounts) {
      final total = amounts['total'] ?? 0;
      final paid = amounts['paid'] ?? 0;
      amounts['remaining'] = total - paid;
      // إذا كان المتبقي سالب (مدفوعات أكثر من قيمة العقد)، اجعله صفر
      if (amounts['remaining']! < 0) {
        amounts['remaining'] = 0;
      }
    });

    print('DEBUG: Total paid amount: $totalPaidAmount');
    print('DEBUG: Total owed amount: $totalOwedAmount');
    print('DEBUG: Total remaining: $totalRemainingAmount');
    print('DEBUG: Project financials: $projectFinancials');

    // حساب النسب المئوية
    double paymentPercentage =
        totalOwedAmount > 0 ? (totalPaidAmount / totalOwedAmount) * 100 : 0;
    double remainingPercentage = 100 - paymentPercentage;

    // تحويل بيانات المشاريع إلى مخططات
    List<ChartData> totalValueChart = [];
    List<ChartData> paidAmountChart = [];
    List<ChartData> remainingAmountChart = [];

    int colorIndex = 0;
    projectFinancials.forEach((projectNumber, amounts) {
      Color projectColor = _chartColors[colorIndex % _chartColors.length];

      totalValueChart.add(
        ChartData(
          'مشروع $projectNumber',
          amounts['total']!.toInt(),
          projectColor,
        ),
      );

      paidAmountChart.add(
        ChartData(
          'مشروع $projectNumber',
          amounts['paid']!.toInt(),
          projectColor,
        ),
      );

      if (amounts['remaining']! > 0) {
        remainingAmountChart.add(
          ChartData(
            'مشروع $projectNumber',
            amounts['remaining']!.toInt(),
            projectColor,
          ),
        );
      }

      colorIndex++;
    });

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchAllCollectionsData();
      },
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
                    colors: [Colors.green.shade700, Colors.teal.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_money, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'الملخص المالي الشامل',
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

            // بطاقات الإحصائيات الرئيسية
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return GridView.count(
                  crossAxisCount: isMobile ? 1 : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  childAspectRatio: isMobile ? 2.5 : 1.2,
                  children: [
                    _buildFinancialKPICard(
                      title: 'إجمالي المبالغ المطلوبة',
                      value: '${totalOwedAmount.toStringAsFixed(0)}',
                      subtitle: 'ريال سعودي',
                      icon: Icons.account_balance_wallet,
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade800, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      iconColor: Colors.white,
                    ),
                    _buildFinancialKPICard(
                      title: 'المبلغ المدفوع',
                      value: '${totalPaidAmount.toStringAsFixed(0)}',
                      subtitle:
                          '${paymentPercentage.toStringAsFixed(1)}% من الإجمالي',
                      icon: Icons.monetization_on,
                      gradient: LinearGradient(
                        colors: [Colors.green.shade800, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      iconColor: Colors.white,
                      progressValue: paymentPercentage / 100,
                    ),
                    _buildFinancialKPICard(
                      title: 'المبلغ المتبقي',
                      value: '${totalRemainingAmount.toStringAsFixed(0)}',
                      subtitle:
                          '${remainingPercentage.toStringAsFixed(1)}% من الإجمالي',
                      icon: Icons.schedule,
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade800,
                          Colors.orange.shade600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      iconColor: Colors.white,
                      progressValue: remainingPercentage / 100,
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 32),

            // مخطط دائري للنظرة العامة
            _buildFinancialOverviewChart(totalPaidAmount, totalRemainingAmount),

            SizedBox(height: 32),

            // مخططات التوزيع حسب المشاريع
            if (projectFinancials.isNotEmpty) ...[
              Text(
                'التوزيع المالي حسب المشاريع',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
              SizedBox(height: 16),

              // مخطط القيمة الإجمالية
              _buildProjectFinancialChart(
                'إجمالي قيمة العقود بالمشاريع',
                totalValueChart,
              ),

              SizedBox(height: 16),

              // مخطط المبالغ المدفوعة
              if (paidAmountChart.any((data) => data.y > 0))
                _buildProjectFinancialChart(
                  'المبالغ المدفوعة بالمشاريع',
                  paidAmountChart.where((data) => data.y > 0).toList(),
                ),

              SizedBox(height: 16),

              // مخطط المبالغ المتبقية
              if (remainingAmountChart.isNotEmpty)
                _buildProjectFinancialChart(
                  'المبالغ المتبقية بالمشاريع',
                  remainingAmountChart,
                ),
            ],

            SizedBox(height: 32),

            // جدول تفصيلي للمشاريع
            _buildProjectFinancialTable(projectFinancials),

            SizedBox(height: 24),

            // إضافة معلومات إضافية حول مصدر البيانات
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'البيانات المالية: قيم العقود من جدول العقود، والمدفوعات من العمليات المالية (نوع "له" فقط)',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required Color iconColor,
    double? progressValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF4A5568).withOpacity(0.5)
                    : Colors.white.withOpacity(0.7),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(-8, -8),
          ),
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Colors.grey.shade400.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(8, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF4A5568).withOpacity(0.5)
                                : Colors.white.withOpacity(0.7),
                        blurRadius: 8,
                        offset: const Offset(-4, -4),
                      ),
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF1A202C).withOpacity(0.8)
                                : Colors.grey.shade400.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(4, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                    size: 32,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF4A5568) : Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF1A202C).withOpacity(0.5)
                                : Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF4A5568).withOpacity(0.5)
                                : Colors.white,
                        blurRadius: 4,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: Text(
                    'ريال',
                    style: TextStyle(
                      color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
              ),
            ),

            SizedBox(height: 4),

            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Color(0xFFCBD5E0) : Color(0xFF4A5568),
                fontWeight: FontWeight.w500,
              ),
            ),

            SizedBox(height: 8),

            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Color(0xFFA0AEC0) : Color(0xFF718096),
              ),
            ),

            if (progressValue != null) ...[
              SizedBox(height: 12),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isDark ? Color(0xFF4A5568) : Color(0xFFD1D5DB),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? Color(0xFF1A202C).withOpacity(0.8)
                              : Colors.grey.shade300,
                      blurRadius: 3,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Color(0xFF68D391) : Color(0xFF38A169),
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialOverviewChart(
    double paidAmount,
    double remainingAmount,
  ) {
    List<ChartData> overviewData = [];

    if (paidAmount > 0) {
      overviewData.add(
        ChartData('المدفوع', paidAmount.toInt(), Colors.green.shade600),
      );
    }

    if (remainingAmount > 0) {
      overviewData.add(
        ChartData('المتبقي', remainingAmount.toInt(), Colors.orange.shade600),
      );
    }

    if (overviewData.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'نظرة عامة على الحالة المالية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: SfCircularChart(
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  series: <CircularSeries>[
                    DoughnutSeries<ChartData, String>(
                      dataSource: overviewData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      pointColorMapper: (ChartData data, _) => data.color,
                      radius: '80%',
                      innerRadius: '50%',
                      dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                        textStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        connectorLineSettings: ConnectorLineSettings(
                          type: ConnectorType.curve,
                        ),
                      ),
                      enableTooltip: true,
                    ),
                  ],
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x: point.y ريال',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectFinancialChart(String title, List<ChartData> data) {
    if (data.isEmpty) return SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.right,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                series: <CircularSeries>[
                  PieSeries<ChartData, String>(
                    dataSource: data,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      connectorLineSettings: ConnectorLineSettings(
                        type: ConnectorType.curve,
                      ),
                    ),
                    enableTooltip: true,
                  ),
                ],
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x: point.y ريال',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectFinancialTable(
    Map<String, Map<String, double>> projectFinancials,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'جدول تفصيلي للمشاريع',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateColor.resolveWith(
                  (states) => Colors.indigo.shade50,
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'المشروع',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'القيمة الإجمالية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'المدفوع',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'المتبقي',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'نسبة السداد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows:
                    projectFinancials.entries.map((entry) {
                      final projectNumber = entry.key;
                      final amounts = entry.value;
                      final total = amounts['total'] ?? 0;
                      final paid = amounts['paid'] ?? 0;
                      final remaining = amounts['remaining'] ?? 0;
                      final percentage = total > 0 ? (paid / total) * 100 : 0;

                      return DataRow(
                        cells: [
                          DataCell(Text('مشروع $projectNumber')),
                          DataCell(Text('${total.toStringAsFixed(0)} ريال')),
                          DataCell(
                            Text(
                              '${paid.toStringAsFixed(0)} ريال',
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${remaining.toStringAsFixed(0)} ريال',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    percentage > 70
                                        ? Colors.green.shade100
                                        : percentage > 40
                                        ? Colors.orange.shade100
                                        : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      percentage > 70
                                          ? Colors.green.shade800
                                          : percentage > 40
                                          ? Colors.orange.shade800
                                          : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    // حساب إجماليات مالية
    double totalContractValue = 0;
    for (var contract in _allContracts) {
      final data = contract.data() as Map<String, dynamic>;
      if (data['totalAmount'] != null) {
        totalContractValue +=
            double.tryParse(data['totalAmount'].toString()) ?? 0;
      }
    }

    // تجميع البيانات المالية حسب المشروع
    Map<String, double> projectTotals = {};
    for (var contract in _allContracts) {
      final data = contract.data() as Map<String, dynamic>;
      final projectNumber = data['projectNumber'] ?? 'غير محدد';

      projectTotals[projectNumber] =
          (projectTotals[projectNumber] ?? 0) + amount;
    }

    // تحويل البيانات إلى شكل مناسب للرسم البياني
    List<ChartData> projectFinancialData = [];
    projectTotals.forEach((projectNumber, amount) {
      projectFinancialData.add(
        ChartData(
          projectNumber,
          amount.toInt(),
          Colors.primaries[projectFinancialData.length %
              Colors.primaries.length],
        ),
      );
    });

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'الملخص المالي',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),

        _buildInfoCard(
          'إجمالي قيمة العقود',
          '${totalContractValue.toStringAsFixed(2)} ريال',
          Icons.monetization_on,
          color: Colors.green,
        ),

        SizedBox(height: 20),
        Text(
          'توزيع القيمة المالية حسب المشروع',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),

        // رسم بياني للبيانات المالية حسب المشروع
        _buildChartCard('القيمة المالية للمشاريع', projectFinancialData),
      ],
    );
  }

  // الدوال الجديدة لعرض التبويبات
  Widget _buildApartmentsTab() {
    if (_isLoadingData) {
      return Center(child: CircularProgressIndicator());
    }
    if (_allApartments.isEmpty) {
      return Center(child: Text('لا توجد بيانات وحدات لعرضها.'));
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
        // شريط الفلترة المحسن
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E3192), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.filter_list, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'فلترة حسب المشروع:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProjectNumber,
                      hint: Text('اختر مشروع'),
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF2E3192),
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

        // عرض عدد الوحدات المفلترة
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.home_work, color: Color(0xFF2E3192), size: 20),
              SizedBox(width: 8),
              Text(
                'عدد الوحدات: ${filteredApartments.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3192),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // قائمة الوحدات المحسنة
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: filteredApartments.length,
            itemBuilder: (context, index) {
              final doc = filteredApartments[index];
              final data = doc.data() as Map<String, dynamic>;

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
              String buyerName = data['buyerName'] ?? '';

              return _buildUnitCard(
                pn: pn,
                projectNumber: projectNumber,
                buyerName: buyerName,
                status: status,
                area: area,
                floor: floor,
                direction: direction,
                city: city,
                district: district,
                description: description,
                number: number,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnitCard({
    required String pn,
    required String projectNumber,
    required String buyerName,
    required String status,
    required String area,
    required String floor,
    required String direction,
    required String city,
    required String district,
    required String description,
    required String number,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showUnitDetailsDialog(
            pn: pn,
            projectNumber: projectNumber,
            buyerName: buyerName,
            status: status,
            area: area,
            floor: floor,
            direction: direction,
            city: city,
            district: district,
            description: description,
            number: number,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
            boxShadow: [
              BoxShadow(
                color:
                    isDark
                        ? Color(0xFF4A5568).withOpacity(0.5)
                        : Colors.white.withOpacity(0.7),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(-8, -8),
              ),
              BoxShadow(
                color:
                    isDark
                        ? Color(0xFF1A202C).withOpacity(0.8)
                        : Colors.grey.shade400.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(8, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصف العلوي - رقم الشقة والحالة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Color(0xFF2D3748)
                                      : Color(0xFFE8EBF0),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      isDark
                                          ? Color(0xFF4A5568).withOpacity(0.5)
                                          : Colors.white.withOpacity(0.7),
                                  blurRadius: 6,
                                  offset: const Offset(-3, -3),
                                ),
                                BoxShadow(
                                  color:
                                      isDark
                                          ? Color(0xFF1A202C).withOpacity(0.8)
                                          : Colors.grey.shade400.withOpacity(
                                            0.5,
                                          ),
                                  blurRadius: 6,
                                  offset: const Offset(3, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.home_work,
                              color:
                                  isDark
                                      ? Color(0xFF68D391)
                                      : Color(0xFF2E3192),
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'شقة $pn',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color:
                                        isDark
                                            ? Color(0xFFE2E8F0)
                                            : Color(0xFF2E3192),
                                  ),
                                ),
                                Text(
                                  'مشروع $projectNumber',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        isDark
                                            ? Color(0xFFA0AEC0)
                                            : Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(status).withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // اسم المشتري إن وجد
                if (buyerName.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDark
                                  ? Color(0xFF1A202C).withOpacity(0.8)
                                  : Colors.grey.shade300,
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                        BoxShadow(
                          color:
                              isDark
                                  ? Color(0xFF4A5568).withOpacity(0.5)
                                  : Colors.white,
                          blurRadius: 4,
                          offset: const Offset(-2, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: isDark ? Color(0xFF68D391) : Colors.green[700],
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'المشتري: $buyerName',
                          style: TextStyle(
                            color:
                                isDark ? Color(0xFF68D391) : Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                ],

                // معلومات سريعة
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickInfo(
                        Icons.square_foot,
                        'المساحة',
                        '$area م²',
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickInfo(
                        Icons.layers,
                        'الطابق',
                        floor,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8),

                // أزرار عرض التفاصيل وعرض الصك
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showUnitDetailsDialog(
                            pn: pn,
                            projectNumber: projectNumber,
                            buyerName: buyerName,
                            status: status,
                            area: area,
                            floor: floor,
                            direction: direction,
                            city: city,
                            district: district,
                            description: description,
                            number: number,
                          );
                        },
                        icon: Icon(Icons.visibility, size: 16),
                        label: Text(
                          'عرض التفاصيل',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                          foregroundColor:
                              isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ).copyWith(
                          overlayColor: MaterialStateProperty.all(
                            Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showDeedDocument(pn);
                        },
                        icon: Icon(Icons.description, size: 16),
                        label: Text(
                          'عرض الصك',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                          foregroundColor:
                              isDark ? Color(0xFF68D391) : Colors.green[700],
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ).copyWith(
                          overlayColor: MaterialStateProperty.all(
                            Colors.transparent,
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
      ),
    );
  }

  Widget _buildQuickInfo(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
          BoxShadow(
            color: isDark ? Color(0xFF4A5568).withOpacity(0.5) : Colors.white,
            blurRadius: 4,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: isDark ? Color(0xFFE2E8F0) : color, size: 16),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Color(0xFFA0AEC0) : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Color(0xFFE2E8F0) : color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'متاح':
        return Colors.green;
      case 'مباع':
        return Colors.red;
      case 'محجوز':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showUnitDetailsDialog({
    required String pn,
    required String projectNumber,
    required String buyerName,
    required String status,
    required String area,
    required String floor,
    required String direction,
    required String city,
    required String district,
    required String description,
    required String number,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E3192), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.home_work, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تفاصيل الوحدة $pn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'مشروع $projectNumber',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(
                                    status,
                                  ).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 20),

                        // Buyer Info
                        if (buyerName.isNotEmpty) ...[
                          _buildDetailRow('اسم المشتري', buyerName),
                          SizedBox(height: 12),
                        ],

                        // Unit Details
                        _buildDetailRow('رقم الوحدة', number),
                        SizedBox(height: 12),
                        _buildDetailRow('المساحة', '$area م²'),
                        SizedBox(height: 12),
                        _buildDetailRow('الطابق', floor),
                        SizedBox(height: 12),
                        _buildDetailRow('الاتجاه', direction),
                        SizedBox(height: 12),
                        _buildDetailRow('المدينة', city),
                        SizedBox(height: 12),
                        _buildDetailRow('الحي', district),

                        if (description.isNotEmpty) ...[
                          SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.description,
                                      color: Colors.grey[600],
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'الوصف',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomersTab() {
    if (_isLoadingData) {
      return Center(child: CircularProgressIndicator());
    }
    if (_allCustomers.isEmpty) {
      return Center(child: Text('لا توجد بيانات عملاء لعرضها.'));
    }
    return ListView.builder(
      padding: EdgeInsets.all(8.0),
      itemCount: _allCustomers.length,
      itemBuilder: (context, index) {
        final doc = _allCustomers[index];
        final data = doc.data() as Map<String, dynamic>;

        String name = data['name'] ?? 'غير متوفر';
        String identityNumber = data['identityNumber'] ?? 'غير متوفر';
        String phoneNumber = data['phoneNumber'] ?? 'غير متوفر';
        String type = data['type'] ?? 'غير محدد';
        String description = data['description'] ?? '';
        List<dynamic> contractNumbers = data['contractNumbers'] ?? [];

        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'العميل: $name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).primaryColorDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'النوع: $type',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                Divider(height: 12, thickness: 0.5),
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4),
                    Text(
                      'رقم الهوية: $identityNumber',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'رقم الجوال: $phoneNumber',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    if (phoneNumber != 'غير متوفر') ...[
                      IconButton(
                        icon: Icon(Icons.call, color: Colors.green, size: 18),
                        onPressed: () => _makePhoneCall(phoneNumber),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.chat, color: Colors.green, size: 18),
                        onPressed:
                            () => _sendWhatsAppMessage(phoneNumber, name, 0.0),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ],
                ),
                if (contractNumbers.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'أرقام العقود: ${contractNumbers.map((e) => e.toString()).join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
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
      },
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon, {
    Color color = Colors.blue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF4A5568).withOpacity(0.5)
                    : Colors.white.withOpacity(0.7),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(-6, -6),
          ),
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Colors.grey.shade400.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
                            ? Color(0xFF4A5568).withOpacity(0.5)
                            : Colors.white.withOpacity(0.7),
                    blurRadius: 8,
                    offset: const Offset(-4, -4),
                  ),
                  BoxShadow(
                    color:
                        isDark
                            ? Color(0xFF1A202C).withOpacity(0.8)
                            : Colors.grey.shade400.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 40,
                color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
              ),
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
              ),
            ),
            SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                color: isDark ? Color(0xFF68D391) : Color(0xFF38A169),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة لعرض ملخص سريع لآخر الأحداث
  Widget _buildRecentEventsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey[600], size: 20),
                SizedBox(width: 12),
                Text(
                  'الأحداث الحديثة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // قائمة الأحداث
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('logs')
                    .orderBy('timestamp', descending: true)
                    .limit(3)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber[400]!,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blueGrey.withOpacity(0.08),
                      width: 1.0,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.85),
                        Colors.grey[50]!.withOpacity(0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[400],
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد أحداث حديثة',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final events = snapshot.data!.docs;
              return Column(
                children:
                    events.map((event) {
                      final data = event.data() as Map<String, dynamic>;
                      final timestamp = data['timestamp'] as Timestamp?;
                      final action = data['action'] ?? 'إجراء غير محدد';
                      final unitNumber = data['itemId'] ?? '';
                      final projectNumber = data['projectNumber'] ?? '';
                      final user = data['user'] ?? 'مستخدم غير معروف';
                      final formattedDate =
                          timestamp != null
                              ? DateFormat(
                                'hh:mm a | yyyy/MM/dd',
                              ).format(timestamp.toDate())
                              : '';

                      return _buildEventCard(data, formattedDate, isDark);
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    Map<String, dynamic> data,
    String formattedDate,
    bool isDark,
  ) {
    final action = data['action'] ?? 'إجراء غير محدد';
    final unitNumber = data['itemId'] ?? '';
    final user = data['user'] ?? 'مستخدم غير معروف';
    final timestamp = data['timestamp'] as Timestamp?;

    // تحديد لون ونوع الحدث
    Color accentColor = Colors.amber[600]!;
    IconData eventIcon = Icons.info;

    if (action.contains('إضافة') || action.contains('إنشاء')) {
      accentColor = Colors.green[600]!;
      eventIcon = Icons.add_circle;
    } else if (action.contains('تعديل') || action.contains('تحديث')) {
      accentColor = Colors.orange[600]!;
      eventIcon = Icons.edit;
    } else if (action.contains('حذف')) {
      accentColor = Colors.red[600]!;
      eventIcon = Icons.delete;
    } else if (action.contains('دفع') || action.contains('مالي')) {
      accentColor = Colors.blue[600]!;
      eventIcon = Icons.payment;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF4A5568).withOpacity(0.5)
                    : Colors.white.withOpacity(0.7),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(-4, -4),
          ),
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Colors.grey.shade400.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // أيقونة الحدث
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
                            ? Color(0xFF4A5568).withOpacity(0.5)
                            : Colors.white.withOpacity(0.7),
                    blurRadius: 6,
                    offset: const Offset(-3, -3),
                  ),
                  BoxShadow(
                    color:
                        isDark
                            ? Color(0xFF1A202C).withOpacity(0.8)
                            : Colors.grey.shade400.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              child: Icon(
                eventIcon,
                color: isDark ? Color(0xFFE2E8F0) : accentColor,
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            // تفاصيل الحدث
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Color(0xFFE2E8F0) : Colors.grey[800],
                      fontFamily: 'Tajawal',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      if (unitNumber.isNotEmpty) ...[
                        Icon(Icons.home_outlined, size: 12, color: accentColor),
                        SizedBox(width: 4),
                        Text(
                          'شقة $unitNumber',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Color(0xFF68D391) : accentColor,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                      Icon(
                        Icons.person_outline,
                        size: 12,
                        color: isDark ? Color(0xFFA0AEC0) : Colors.grey[500],
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          user,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Color(0xFFA0AEC0) : Colors.grey[600],
                            fontFamily: 'Tajawal',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // الوقت
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timestamp != null) ...[
                  Text(
                    DateFormat('hh:mm a').format(timestamp.toDate()),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Color(0xFF68D391) : accentColor,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    DateFormat('yyyy/MM/dd').format(timestamp.toDate()),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Color(0xFFA0AEC0) : Colors.grey[500],
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // دالة لتنسيق الوقت
  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return 'منذ ${difference.inDays} يوم';
    }
  }

  // دالة لتنسيق التاريخ بشكل مفصل
  String _formatDetailedTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // دالة لتنسيق الوقت فقط
  String _formatTimeOnly(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildChartCard(String title, List<ChartData> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
          boxShadow: [
            BoxShadow(
              color:
                  isDark
                      ? Color(0xFF4A5568).withOpacity(0.5)
                      : Colors.white.withOpacity(0.7),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(-6, -6),
            ),
            BoxShadow(
              color:
                  isDark
                      ? Color(0xFF1A202C).withOpacity(0.8)
                      : Colors.grey.shade400.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(6, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'لا توجد بيانات لعرض الرسم البياني لـ "$title"',
              style: TextStyle(
                color: isDark ? Color(0xFFCBD5E0) : Color(0xFF4A5568),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF4A5568).withOpacity(0.5)
                    : Colors.white.withOpacity(0.7),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(-6, -6),
          ),
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Colors.grey.shade400.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 200, // ارتفاع افتراضي للرسم البياني
              child: SfCircularChart(
                // أو SfCartesianChart حسب نوع الرسم
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

  // تحميل العملاء المدينين
  Future<void> _loadTopDebtorCustomers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDebtors = true;
    });

    try {
      final contractsSnapshot = await _firestore.collection('contracts').get();
      Map<String, Map<String, dynamic>> customerDebts = {};

      for (var contractDoc in contractsSnapshot.docs) {
        final contractData = contractDoc.data();
        final clientName =
            contractData['name'] ?? contractData['clientName'] ?? 'غير محدد';
        final identityNumber = contractData['identityNumber'] ?? '';
        final contractNumber = contractData['pn'] ?? 'غير محدد'; // رقم العقد

        // تم إزالة رسالة DEBUG لتحسين الأداء

        // البحث عن رقم الجوال في جميع الحقول المحتملة
        final phoneNumber = _extractPhoneNumber(contractData);

        final totalAmount =
            double.tryParse(contractData['totalAmount']?.toString() ?? '0') ??
            0;

        // حساب المديونية الصحيحة من العمليات المالية
        double actualDebt = await _calculateActualDebt(
          identityNumber,
          contractNumber,
          totalAmount,
        );

        if (actualDebt > 0 && identityNumber.isNotEmpty) {
          if (customerDebts.containsKey(identityNumber)) {
            customerDebts[identityNumber]!['totalDebt'] += actualDebt;
            customerDebts[identityNumber]!['contractsCount']++;
            // إضافة رقم العقد إلى القائمة
            (customerDebts[identityNumber]!['contractNumbers'] as List<dynamic>)
                .add(contractNumber);
          } else {
            // البحث عن رقم الجوال من جدول العملاء باستخدام رقم الهوية
            String customerPhoneNumber = phoneNumber;
            if (phoneNumber == 'غير متوفر') {
              customerPhoneNumber = await _getCustomerPhoneByIdentity(
                identityNumber,
              );
            }

            customerDebts[identityNumber] = {
              'customerName': clientName,
              'identityNumber': identityNumber,
              'phoneNumber': customerPhoneNumber,
              'totalDebt': actualDebt,
              'contractsCount': 1,
              'contractNumbers': <dynamic>[
                contractNumber,
              ], // قائمة أرقام العقود
            };
          }
        }
      }

      // ترتيب العملاء حسب المديونية وأخذ أعلى 5
      final sortedCustomers =
          customerDebts.values.toList()
            ..sort((a, b) => b['totalDebt'].compareTo(a['totalDebt']));

      if (mounted) {
        setState(() {
          _topDebtorCustomers = sortedCustomers.take(5).toList();
          _isLoadingDebtors = false;
        });
      }
    } catch (e) {
      print('Error loading top debtor customers: $e');
      if (mounted) {
        setState(() {
          _isLoadingDebtors = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات العملاء المدينين: $e')),
        );
      }
    }
  }

  // تحميل شقق إعادة البيع
  Future<void> _loadResaleApartments() async {
    if (!mounted) return;
    setState(() {
      _isLoadingResaleApartments = true;
    });
    try {
      final apartmentsSnapshot =
          await _firestore
              .collection('apartments')
              .where('status', whereIn: ['معروضة للبيع'])
              .limit(20) // عرض أول 20 شقة
              .get();

      if (mounted) {
        setState(() {
          _resaleApartments = apartmentsSnapshot.docs;
          _isLoadingResaleApartments = false;
        });
      }
    } catch (e) {
      print('Error loading resale apartments: $e');
      if (mounted) {
        setState(() {
          _isLoadingResaleApartments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات شقق إعادة البيع: $e')),
        );
      }
    }
  }

  // عرض الصك المحفوظ
  Future<void> _showDeedDocument(String pn) async {
    try {
      // البحث عن الشقة بناءً على رقم PN
      final apartmentQuery =
          await _firestore
              .collection('apartments')
              .where('pn', isEqualTo: pn)
              .get();

      if (apartmentQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم العثور على الشقة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final apartmentData = apartmentQuery.docs.first.data();
      final deedPdfUrl = apartmentData['deedPdfUrl'] as String?;
      final deedPdfName = apartmentData['deedPdfName'] as String?;

      if (deedPdfUrl == null || deedPdfUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يوجد صك محفوظ لهذه الشقة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // عرض نافذة تحتوي على معلومات الصك وزر التحميل
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.description, color: Colors.green[700]),
                SizedBox(width: 8),
                Text('صك الشقة رقم $pn'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (deedPdfName != null) ...[
                  Text(
                    'اسم الملف:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(deedPdfName),
                  SizedBox(height: 12),
                ],
                Text(
                  'تاريخ الرفع:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  apartmentData['deedUploadDate'] != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format(
                        (apartmentData['deedUploadDate'] as Timestamp).toDate(),
                      )
                      : 'غير متوفر',
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        if (await canLaunch(deedPdfUrl)) {
                          await launch(deedPdfUrl);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('لا يمكن فتح الملف'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ في فتح الملف: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(Icons.open_in_new),
                    label: Text('فتح الصك'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('إغلاق'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error showing deed document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء جلب بيانات الصك: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // حساب المديونية الصحيحة من العمليات المالية
  Future<double> _calculateActualDebt(
    String identityNumber,
    String contractNumber,
    double totalAmount,
  ) async {
    try {
      // جلب جميع العمليات المالية للعميل من مجموعة financialTransactions
      final transactionsQuery =
          await _firestore
              .collection('financialTransactions')
              .where('idNumber', isEqualTo: identityNumber)
              .get();

      double totalPaid = 0.0; // إجمالي المدفوع (له)
      double totalOwed = 0.0; // إجمالي المطلوب (عليه)

      for (var transactionDoc in transactionsQuery.docs) {
        final transactionData = transactionDoc.data();
        final amount =
            double.tryParse(transactionData['amount']?.toString() ?? '0') ??
            0.0;
        final debitCredit = transactionData['debitCredit']?.toString() ?? '';
        final transactionPn = transactionData['pn']?.toString() ?? '';

        // التأكد من أن العملية مرتبطة بنفس العقد أو العميل
        bool isRelatedTransaction =
            transactionPn == contractNumber ||
            transactionData['idNumber'] == identityNumber;

        if (isRelatedTransaction && amount > 0) {
          if (debitCredit == 'له' || debitCredit == 'لة') {
            // العميل دفع (سداد)
            totalPaid += amount;
          } else if (debitCredit == 'عليه') {
            // على العميل أن يدفع (دين)
            totalOwed += amount;
          }
        }
      }

      // إذا لم توجد عمليات "عليه"، استخدم قيمة العقد الإجمالية
      if (totalOwed == 0.0 && totalAmount > 0) {
        totalOwed = totalAmount;
      }

      // حساب المديونية الفعلية = ما عليه أن يدفع - ما دفعه فعلاً
      double actualDebt = totalOwed - totalPaid;

      // تم إزالة رسالة DEBUG لتحسين الأداء

      return actualDebt > 0 ? actualDebt : 0.0;
    } catch (e) {
      print('Error calculating actual debt for $identityNumber: $e');
      // في حالة الخطأ، استخدم الطريقة القديمة
      return totalAmount;
    }
  }

  // البحث عن رقم الجوال من جدول العملاء باستخدام رقم الهوية
  Future<String> _getCustomerPhoneByIdentity(String identityNumber) async {
    if (identityNumber.isEmpty) {
      print('DEBUG: Empty identity number provided');
      return 'غير متوفر';
    }

    try {
      print('DEBUG: Searching for customer with identity: $identityNumber');

      // البحث في جدول العملاء باستخدام رقم الهوية
      final customerQuery =
          await _firestore
              .collection('customers')
              .where('identityNumber', isEqualTo: identityNumber)
              .limit(1)
              .get();

      print(
        'DEBUG: Found ${customerQuery.docs.length} customers with identity $identityNumber',
      );

      if (customerQuery.docs.isNotEmpty) {
        final customerData = customerQuery.docs.first.data();
        print('DEBUG: Customer data keys: ${customerData.keys.toList()}');

        // البحث في حقول الهاتف المختلفة
        final phoneFields = ['phoneNumber', 'phone', 'mobile', 'cellphone'];
        for (String field in phoneFields) {
          final phoneNumber = customerData[field]?.toString().trim();
          if (phoneNumber != null &&
              phoneNumber.isNotEmpty &&
              phoneNumber != 'null') {
            print(
              'DEBUG: Found phone number $phoneNumber in field $field for identity $identityNumber',
            );
            return phoneNumber;
          }
        }

        print(
          'DEBUG: No valid phone number found in customer data for identity $identityNumber',
        );
      } else {
        print('DEBUG: No customer found with identity $identityNumber');
      }
    } catch (e) {
      print('Error fetching customer phone by identity: $e');
    }
    return 'غير متوفر';
  }

  // استخراج رقم الجوال من جميع الحقول المحتملة
  String _extractPhoneNumber(Map<String, dynamic> data) {
    final phoneFields = [
      'phoneNumber',
      'phone',
      'phon',
      'mobile',
      'mobileNumber',
      'cellphone',
      'tel',
      'telephone',
      'clientPhone',
      'clientPhoneNumber',
    ];

    for (String field in phoneFields) {
      final value = data[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return 'غير متوفر';
  }

  // بناء قسم العملاء المدينين
  Widget _buildTopDebtorsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade50, Colors.orange.shade50],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade700,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'أعلى 5 عملاء مدينين',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _loadTopDebtorCustomers,
                      icon: Icon(Icons.refresh, color: Colors.red.shade700),
                      tooltip: 'تحديث البيانات',
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_isLoadingDebtors)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.red.shade600,
                        ),
                      ),
                    ),
                  )
                else if (_topDebtorCustomers.isEmpty)
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.sentiment_satisfied,
                            size: 48,
                            color: Colors.green.shade600,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'لا توجد مديونيات مستحقة',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children:
                        _topDebtorCustomers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final customer = entry.value;
                          return _buildDebtorCustomerCard(customer, index + 1);
                        }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بناء بطاقة العميل المدين
  Widget _buildDebtorCustomerCard(Map<String, dynamic> customer, int rank) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rankColors = [
      Colors.red.shade700,
      Colors.orange.shade600,
      Colors.amber.shade600,
      Colors.blue.shade600,
      Colors.purple.shade600,
    ];

    final rankColor =
        rank <= rankColors.length ? rankColors[rank - 1] : Colors.grey.shade600;
    final debtAmount = customer['totalDebt'] ?? 0.0;
    final phoneNumber =
        customer['phoneNumber'] ?? customer['clientPhone'] ?? 'غير متوفر';

    print(
      'DEBUG Debtor: ${customer['customerName']}, Phone: $phoneNumber, Contracts: ${customer['contractNumbers']}',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 600;

        return Container(
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
            boxShadow: [
              BoxShadow(
                color:
                    isDark
                        ? Color(0xFF4A5568).withOpacity(0.5)
                        : Colors.white.withOpacity(0.7),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(-6, -6),
              ),
              BoxShadow(
                color:
                    isDark
                        ? Color(0xFF1A202C).withOpacity(0.8)
                        : Colors.grey.shade400.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(6, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            onTap: () => _showCustomerDebtDetails(customer),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 16),
              child: Row(
                children: [
                  // رقم الترتيب
                  Container(
                    width: isMobile ? 30 : 40,
                    height: isMobile ? 30 : 40,
                    decoration: BoxDecoration(
                      color: rankColor,
                      borderRadius: BorderRadius.circular(isMobile ? 15 : 20),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 16),
                  // معلومات العميل
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['customerName'] ?? 'غير محدد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 16,
                            color:
                                isDark
                                    ? Color(0xFFE2E8F0)
                                    : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isMobile ? 2 : 4),
                        if (phoneNumber != 'غير متوفر')
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: isMobile ? 10 : 14,
                                color:
                                    isDark
                                        ? Color(0xFFA0AEC0)
                                        : Colors.grey.shade600,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  phoneNumber,
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 14,
                                    color:
                                        isDark
                                            ? Color(0xFFA0AEC0)
                                            : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: isMobile ? 2 : 4),
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: isMobile ? 10 : 14,
                              color: rankColor,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${debtAmount.toStringAsFixed(2)} ر.س',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 14,
                                  color: rankColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (!isMobile) ...[
                          SizedBox(height: 4),
                          // عرض أرقام العقود (فقط في الشاشات الكبيرة)
                          if (customer['contractNumbers'] != null &&
                              (customer['contractNumbers'] as List).isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 14,
                                  color:
                                      isDark
                                          ? Color(0xFFA0AEC0)
                                          : Colors.grey.shade600,
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'العقود: ${(customer['contractNumbers'] as List).map((e) => e.toString()).join(', ')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isDark
                                              ? Color(0xFF68D391)
                                              : Colors.blue.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                  // أزرار الإجراءات
                  if (phoneNumber != 'غير متوفر') ...[
                    if (isMobile)
                      // في الجوال - زر واحد فقط للاتصال
                      Container(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          onPressed: () => _makePhoneCall(phoneNumber),
                          icon: Icon(
                            Icons.phone,
                            color: Colors.green.shade600,
                            size: 16,
                          ),
                          tooltip: 'اتصال',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      )
                    else
                      // في الشاشات الكبيرة - زرين
                      Column(
                        children: [
                          // زر الاتصال
                          Container(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              onPressed: () => _makePhoneCall(phoneNumber),
                              icon: Icon(
                                Icons.phone,
                                color: Colors.green.shade600,
                              ),
                              tooltip: 'اتصال',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          // زر الواتساب
                          Container(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              onPressed:
                                  () => _sendWhatsAppMessage(
                                    phoneNumber,
                                    customer['customerName'] ?? 'العميل',
                                    debtAmount,
                                  ),
                              icon: Icon(
                                Icons.message,
                                color: Colors.green.shade700,
                              ),
                              tooltip: 'واتساب',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
      },
    );
  }

  // عرض تفاصيل مديونية العميل
  void _showCustomerDebtDetails(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // المقبض
                Container(
                  margin: EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // العنوان
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade600),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تفاصيل مديونية ${customer['customerName']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                // المحتوى
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // معلومات العميل
                        _buildDetailRow(
                          'اسم العميل',
                          customer['customerName'] ?? 'غير محدد',
                        ),
                        _buildDetailRow(
                          'رقم الهوية',
                          customer['identityNumber'] ?? 'غير محدد',
                        ),
                        _buildDetailRow(
                          'رقم الجوال',
                          customer['phoneNumber'] ?? 'غير متوفر',
                        ),
                        _buildDetailRow(
                          'إجمالي الدين',
                          '${customer['totalDebt']?.toStringAsFixed(2) ?? '0'} ر.س',
                        ),
                        _buildDetailRow(
                          'عدد العقود',
                          '${customer['contractsCount'] ?? 0}',
                        ),

                        SizedBox(height: 20),

                        // أزرار الإجراءات
                        if (customer['phoneNumber'] != null &&
                            customer['phoneNumber'] != 'غير متوفر') ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () => _makePhoneCall(
                                        customer['phoneNumber'],
                                      ),
                                  icon: Icon(Icons.phone),
                                  label: Text('اتصال'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () => _sendWhatsAppMessage(
                                        customer['phoneNumber'],
                                        customer['customerName'] ?? 'العميل',
                                        customer['totalDebt'] ?? 0.0,
                                      ),
                                  icon: Icon(Icons.message),
                                  label: Text('واتساب'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
              ],
            ),
          ),
    );
  }

  // بناء قسم شقق إعادة البيع
  Widget _buildResaleApartmentsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade50, Colors.blue.shade50],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.sell_outlined,
                            color: Colors.purple.shade700,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'شقق إعادة البيع',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _loadResaleApartments,
                      icon: Icon(Icons.refresh, color: Colors.purple.shade700),
                      tooltip: 'تحديث البيانات',
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_isLoadingResaleApartments)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purple.shade600,
                        ),
                      ),
                    ),
                  )
                else if (_resaleApartments.isEmpty)
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'لا توجد شقق معروضة للبيع حالياً',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // تحديد عدد الأعمدة حسب عرض الشاشة
                      if (constraints.maxWidth <= 600) {
                        // شاشة الجوال - عرض أفقي قابل للتمرير
                        return Container(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _resaleApartments.length,
                            itemBuilder: (context, index) {
                              final apartment = _resaleApartments[index];
                              final data =
                                  apartment.data() as Map<String, dynamic>;
                              return Container(
                                width: 100,
                                margin: EdgeInsets.only(right: 8),
                                child: _buildResaleApartmentCard(
                                  data,
                                  apartment.id,
                                  true,
                                ),
                              );
                            },
                          ),
                        );
                      } else {
                        // الشاشات الأكبر - عرض شبكي
                        int crossAxisCount;
                        if (constraints.maxWidth > 1200) {
                          crossAxisCount = 6; // شاشة كبيرة
                        } else if (constraints.maxWidth > 800) {
                          crossAxisCount = 4; // شاشة متوسطة
                        } else {
                          crossAxisCount = 3; // تابلت
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.0,
                              ),
                          itemCount: _resaleApartments.length,
                          itemBuilder: (context, index) {
                            final apartment = _resaleApartments[index];
                            final data =
                                apartment.data() as Map<String, dynamic>;
                            return _buildResaleApartmentCard(
                              data,
                              apartment.id,
                              false,
                            );
                          },
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بناء بطاقة الشقة
  Widget _buildResaleApartmentCard(
    Map<String, dynamic> data,
    String docId,
    bool isMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final apartmentNumber = data['number']?.toString() ?? 'غير محدد';
    final projectNumber = data['projectNumber']?.toString() ?? 'غير محدد';
    final clientName = data['clientName']?.toString() ?? 'غير محدد';
    // البحث عن رقم الهوية في الحقول المختلفة
    final identityNumber =
        data['clientIdentity']?.toString() ??
        data['identityNumber']?.toString() ??
        data['clientId']?.toString() ??
        '';
    final price =
        data['resalePrice']?.toString() ??
        data['totalAmount']?.toString() ??
        'غير محدد';

    // طباعة للتشخيص
    print(
      'DEBUG Apartment: $apartmentNumber, Client: $clientName, Identity: $identityNumber',
    );
    print('DEBUG Available fields: ${data.keys.toList()}');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        color: isDark ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF4A5568).withOpacity(0.5)
                    : Colors.white.withOpacity(0.7),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(-6, -6),
          ),
          BoxShadow(
            color:
                isDark
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Colors.grey.shade400.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        onTap: () => _showApartmentDetailsDialog(data),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with apartment icon and number
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 6 : 8),
                      decoration: BoxDecoration(
                        color:
                            isDark ? Color(0xFF4A5568) : Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDark
                                    ? Color(0xFF2D3748).withOpacity(0.5)
                                    : Colors.white.withOpacity(0.7),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(-3, -3),
                          ),
                          BoxShadow(
                            color:
                                isDark
                                    ? Color(0xFF1A202C).withOpacity(0.8)
                                    : Colors.grey.shade300.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        color:
                            isDark ? Color(0xFF9F7AEA) : Colors.purple.shade700,
                        size: isMobile ? 18 : 24,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'شقة $apartmentNumber',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDark
                                      ? Color(0xFF9F7AEA)
                                      : Colors.purple.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'مشروع $projectNumber',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 12,
                              color:
                                  isDark
                                      ? Color(0xFFA0AEC0)
                                      : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 8 : 12),

                // Client info
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Color(0xFF4A5568)
                            : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF2D3748).withOpacity(0.5)
                                : Colors.white.withOpacity(0.7),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(-3, -3),
                      ),
                      BoxShadow(
                        color:
                            isDark
                                ? Color(0xFF1A202C).withOpacity(0.8)
                                : Colors.grey.shade300.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: isMobile ? 14 : 16,
                            color:
                                isDark
                                    ? Color(0xFFA0AEC0)
                                    : Colors.grey.shade600,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              clientName,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark
                                        ? Color(0xFFE2E8F0)
                                        : Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),

                      // Phone number with future builder
                      FutureBuilder<String>(
                        future:
                            identityNumber.isNotEmpty
                                ? _getCustomerPhoneByIdentity(identityNumber)
                                : Future.value(_extractPhoneNumber(data)),
                        builder: (context, snapshot) {
                          final phoneNumber =
                              snapshot.data ?? 'جاري التحميل...';
                          return Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: isMobile ? 14 : 16,
                                color:
                                    isDark
                                        ? Color(0xFF68D391)
                                        : Colors.green.shade600,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  phoneNumber,
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 12,
                                    color:
                                        isDark
                                            ? Color(0xFF68D391)
                                            : Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (phoneNumber != 'غير متوفر' &&
                                  phoneNumber != 'جاري التحميل...')
                                InkWell(
                                  onTap: () => _makePhoneCall(phoneNumber),
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.call,
                                      size: isMobile ? 12 : 14,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: 4),

                      // Price
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: isMobile ? 14 : 16,
                            color:
                                isDark
                                    ? Color(0xFFF6AD55)
                                    : Colors.orange.shade600,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              price != 'غير محدد' ? '$price ر.س' : price,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark
                                        ? Color(0xFFF6AD55)
                                        : Colors.orange.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // عرض تفاصيل الشقة في نافذة منبثقة
  void _showApartmentDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.home, color: Colors.purple.shade700),
                SizedBox(width: 8),
                Text(
                  'تفاصيل الشقة ${data['number'] ?? 'غير محدد'}',
                  style: TextStyle(color: Colors.purple.shade800),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'رقم الشقة',
                    data['number']?.toString() ?? 'غير محدد',
                  ),
                  _buildDetailRow(
                    'رقم المشروع',
                    data['projectNumber']?.toString() ?? 'غير محدد',
                  ),
                  _buildDetailRow(
                    'اسم البائع',
                    data['clientName']?.toString() ?? 'غير محدد',
                  ),
                  if (data['buyerName'] != null)
                    _buildDetailRow(
                      'اسم المشتري',
                      data['buyerName']?.toString() ?? 'غير محدد',
                    ),
                  _buildDetailRow(
                    'رقم جوال البائع',
                    data['clientPhone']?.toString() ?? 'غير متوفر',
                  ),
                  _buildDetailRow(
                    'السعر المحدد',
                    data['resalePrice'] != null
                        ? '${data['resalePrice']} ر.س'
                        : data['totalAmount'] != null
                        ? '${data['totalAmount']} ر.س'
                        : 'غير محدد',
                  ),
                  if (data['area'] != null)
                    _buildDetailRow('المساحة', '${data['area']} متر مربع'),
                  if (data['floor'] != null)
                    _buildDetailRow(
                      'الطابق',
                      data['floor']?.toString() ?? 'غير محدد',
                    ),
                  if (data['direction'] != null)
                    _buildDetailRow(
                      'الاتجاه',
                      data['direction']?.toString() ?? 'غير محدد',
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  // بناء صف التفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }

  // إجراء الاتصال
  void _makePhoneCall(String phoneNumber) async {
    try {
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);

      // محاولة فتح تطبيق الهاتف
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لا يمكن إجراء المكالمة. تأكد من وجود تطبيق الهاتف.',
              ),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إجراء المكالمة: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  // إرسال رسالة واتساب
  void _sendWhatsAppMessage(
    String phoneNumber,
    String customerName,
    double debtAmount,
  ) async {
    try {
      // تنظيف رقم الجوال
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

      // إضافة رمز الدولة إذا لم يكن موجوداً
      if (!cleanPhone.startsWith('+') && !cleanPhone.startsWith('966')) {
        if (cleanPhone.startsWith('0')) {
          cleanPhone = '966${cleanPhone.substring(1)}';
        } else {
          cleanPhone = '966$cleanPhone';
        }
      }

      // إنشاء نص الرسالة
      final message =
          '🌟 السلام عليكم ورحمة الله وبركاته\n'
          'الأستاذ /ة الكريم /ة/ $customerName\n\n'
          '🏢 نتشرف بالتواصل معكم من شركة مساكن الرفاهية\n\n'
          '📋 نود إحاطتكم علماً بوجود مستحقات مالية قدرها:\n'
          '💰 ${debtAmount.toStringAsFixed(2)} ريال سعودي\n\n'
          '🤝 نقدر ظروفكم ونتفهم التزاماتكم، ونرجو منكم التكرم بالتواصل معنا لمناقشة أفضل الحلول المناسبة لكم\n\n'
          '📞 فريق خدمة العملاء في خدمتكم دائماً\n\n'
          '🙏 نشكركم لثقتكم الغالية وتعاونكم المستمر\n'
          'مع أطيب التحيات 🌹';

      // ترميز الرسالة للـ URL
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';
      final Uri whatsappUri = Uri.parse(whatsappUrl);

      // محاولة فتح واتساب
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يمكن فتح واتساب. تأكد من تثبيت التطبيق.'),
              backgroundColor: Colors.orange.shade600,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال رسالة واتساب: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  // بناء شريط التطبيق المخصص بتصميم كارد أنيق
  Widget _buildCustomAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;

    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: isMobile ? 12 : 16,
          ),
          child:
              isMobile
                  ? _buildMobileAppBar(context)
                  : _buildDesktopAppBar(context),
        ),
      ),
    );
  }

  // تصميم شريط التطبيق للجوال
  Widget _buildMobileAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // أيقونة القائمة
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200, width: 1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: Colors.blue.shade700,
              size: 24,
            ),
            onPressed: () {
              _showMobileMenu(context);
            },
            tooltip: 'القائمة',
          ),
        ),

        // العنوان المتحرك
        Expanded(
          child: Center(
            child: AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  "مرحبا بك",
                  textStyle: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'tg',
                  ),
                  speed: Duration(milliseconds: 100),
                ),
              ],
              totalRepeatCount: 1,
              displayFullTextOnTap: true,
            ),
          ),
        ),

        // أيقونة تسجيل الخروج
        Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200, width: 1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.red.shade600,
              size: 24,
            ),
            onPressed: () {
              _showLogoutDialog(context);
            },
            tooltip: 'تسجيل الخروج',
          ),
        ),
      ],
    );
  }

  // تصميم شريط التطبيق للشاشات الكبيرة
  Widget _buildDesktopAppBar(BuildContext context) {
    return Row(
      children: [
        // العنوان المتحرك
        Expanded(
          flex: 2,
          child: AnimatedTextKit(
            animatedTexts: [
              TypewriterAnimatedText(
                "مرحبا بك",
                textStyle: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'tg',
                ),
                speed: Duration(milliseconds: 100),
              ),
            ],
            totalRepeatCount: 1,
            displayFullTextOnTap: true,
          ),
        ),

        // الأزرار والقوائم
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // زر لوحة المشاريع والعملاء
              _buildActionButton(
                icon: Icons.analytics_outlined,
                tooltip: 'لوحة المشاريع والعملاء',
                color: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectsDashboardScreen(),
                    ),
                  );
                },
              ),

              SizedBox(width: 8),

              // زر لوحة العقود
              _buildActionButton(
                icon: Icons.content_copy_rounded,
                tooltip: 'لوحة العقود',
                color: Colors.green,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ContractsScreenl()),
                  );
                },
              ),

              SizedBox(width: 8),

              // قائمة المشاريع
              Container(
                constraints: BoxConstraints(maxWidth: 150),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  value: _selectedProjectNumber,
                  hint: Text(
                    'المشاريع',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontFamily: 'tg',
                      fontSize: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'tg',
                  ),
                  dropdownColor: Colors.white,
                  underline: SizedBox(),
                  isExpanded: true,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedProjectNumber = newValue;
                      _loadDashboardData();
                    });
                  },
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'جميع المشاريع',
                        style: TextStyle(
                          fontFamily: 'tg',
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._projectNumbers.map((String projectNumber) {
                      return DropdownMenuItem<String>(
                        value: projectNumber,
                        child: Text(
                          'مشروع $projectNumber',
                          style: TextStyle(
                            fontFamily: 'tg',
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                ),
              ),

              SizedBox(width: 8),

              // زر التحديث
              _buildActionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'تحديث البيانات',
                color: Colors.orange,
                onPressed: () {
                  _fetchProjectData();
                  _fetchAllCollectionsData();
                  if (_selectedProjectNumber != null &&
                      _selectedTabIndex == 1) {
                    _fetchUnitData(_selectedProjectNumber!);
                    _fetchFinancialData(_selectedProjectNumber!);
                  }
                },
              ),

              SizedBox(width: 8),

              // زر تسجيل الخروج
              _buildActionButton(
                icon: Icons.logout_rounded,
                tooltip: 'تسجيل الخروج',
                color: Colors.red,
                onPressed: () {
                  _showLogoutDialog(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // بناء زر الإجراء
  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, color: color.withOpacity(0.8), size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  // عرض قائمة الجوال
  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20),

                _buildMobileMenuItem(
                  icon: Icons.analytics_outlined,
                  title: 'لوحة المشاريع والعملاء',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectsDashboardScreen(),
                      ),
                    );
                  },
                ),

                _buildMobileMenuItem(
                  icon: Icons.content_copy_rounded,
                  title: 'لوحة العقود',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContractsScreenl(),
                      ),
                    );
                  },
                ),

                _buildMobileMenuItem(
                  icon: Icons.refresh_rounded,
                  title: 'تحديث البيانات',
                  onTap: () {
                    Navigator.pop(context);
                    _fetchProjectData();
                    _fetchAllCollectionsData();
                    if (_selectedProjectNumber != null &&
                        _selectedTabIndex == 1) {
                      _fetchUnitData(_selectedProjectNumber!);
                      _fetchFinancialData(_selectedProjectNumber!);
                    }
                  },
                ),

                // قائمة المشاريع للجوال
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedProjectNumber,
                    hint: Text(
                      'اختر المشروع',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontFamily: 'tg',
                        fontSize: 14,
                      ),
                    ),
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'tg',
                    ),
                    dropdownColor: Colors.white,
                    underline: SizedBox(),
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedProjectNumber = newValue;
                        _loadDashboardData();
                      });
                      Navigator.pop(context);
                    },
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'جميع المشاريع',
                          style: TextStyle(
                            fontFamily: 'tg',
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ..._projectNumbers.map((String projectNumber) {
                        return DropdownMenuItem<String>(
                          value: projectNumber,
                          child: Text(
                            'مشروع $projectNumber',
                            style: TextStyle(
                              fontFamily: 'tg',
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // بناء عنصر قائمة الجوال
  Widget _buildMobileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'tg',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // عرض حوار تسجيل الخروج
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.logout_rounded, color: Colors.red.shade600),
                SizedBox(width: 8),
                Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'tg',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
              style: TextStyle(fontFamily: 'tg', fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'tg',
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // هنا يمكن إضافة منطق تسجيل الخروج
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontFamily: 'tg', color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  // بناء أيقونة شريط التنقل مع تأثيرات بصرية
  Widget _buildNavIcon(
    IconData unselectedIcon,
    IconData selectedIcon,
    int index,
  ) {
    final isSelected = _selectedTabIndex == index;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(isSelected ? 8 : 6),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Color(0xFF1565C0).withOpacity(0.15)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected
                ? Border.all(
                  color: Color(0xFF1565C0).withOpacity(0.3),
                  width: 1,
                )
                : null,
      ),
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          key: ValueKey(isSelected),
          size: isSelected ? 26 : 24,
          color: isSelected ? Color(0xFF1565C0) : Color(0xFF9E9E9E),
        ),
      ),
    );
  }
}
