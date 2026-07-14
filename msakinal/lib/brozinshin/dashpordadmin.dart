import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:msakinal/brozinshin/admin/contract_assignments.dart';
import 'package:msakinal/priovider/dash.dart';
import 'package:msakinal/utils/database_export_import.dart';

import '../class/التحديثات.dart';
import '../login.dart';
import '../massg.dart';

import '../priovider/projects_dashboard.dart';
import 'admin/okod.dart';
import 'admin/العملاء.dart';
import 'admin/صفحة الاضافة.dart';
import 'admin/طلبات_الموافقة.dart';
import 'login_page.dart';
import 'mapyat/homein.dart';
import 'الماليه/malih.dart';
import 'الماليه/arth.dart';
import 'الماليه/المديونية.dart';
import '../pages/free_notifications_admin.dart';
import '../resale_units_page.dart';

class EpicMasterDashboard extends StatefulWidget {
  final String username;
  const EpicMasterDashboard({super.key, required this.username});

  @override
  State<EpicMasterDashboard> createState() => _EpicMasterDashboardState();
}

class _EpicMasterDashboardState extends State<EpicMasterDashboard>
    with TickerProviderStateMixin {
  bool isDarkMode = true;
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late AnimationController _sidebarController;
  late AnimationController _floatingController;

  late Animation<double> _backgroundAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _sidebarAnimation;
  late Animation<double> _floatingAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<DashboardItem> items = [
    DashboardItem(
      "المدراء",
      Icons.admin_panel_settings_outlined,
      [Color(0xFF1e3a8a), Color(0xFF3b82f6)], // أزرق داكن إلى فاتح أنيق
      NewProfessionalDashboardScreen(),
    ),
    DashboardItem("مدير التسويق", Icons.trending_up_outlined, [
      Color(0xFF1d4ed8), // أزرق ملكي
      Color(0xFF60a5fa), // أزرق سماوي فاتح
    ], HomePage11()),
    DashboardItem("العقود", Icons.description_outlined, [
      Color(0xFF2563eb), // أزرق متوسط جميل
      Color(0xFF93c5fd), // أزرق لافندر فاتح
    ], ContractsPage12()),
    DashboardItem("إدارة العقود", Icons.assignment_outlined, [
      Color(0xFF1e40af), // أزرق داكن كلاسيكي
      Color(0xFF60a5fa), // أزرق سماوي فاتح
    ], ContractsScreenl()),
    DashboardItem("الوحدات", Icons.home_work_outlined, [
      Color(0xFF0f172a), // أزرق ليلي عميق
      Color(0xFF1d4ed8), // أزرق ملكي
    ], ApartmentsListPage()),
    DashboardItem("وحدات إعادة البيع", Icons.sell_outlined, [
      Color(0xFF7c2d92), // بنفسجي داكن
      Color(0xFFa855f7), // بنفسجي فاتح
    ], ResaleUnitsPage()),
    DashboardItem("تعديل الصكوك", Icons.edit_document, [
      Color(0xFF0ea5e9), // أزرق سماوي متوسط
      Color(0xFF38bdf8), // أزرق سماوي فاتح
    ], UpdateDeedPage()),
    DashboardItem("اضافة الوحدات", Icons.add_home_work_outlined, [
      Color(0xFF0284c7), // أزرق سماوي داكن
      Color(0xFF7dd3fc), // أزرق سماوي فاتح جداً
    ], ApartmentGeneratorPage()),
    DashboardItem("العملاء", Icons.people_outline, [
      Color(0xFF1e40af), // أزرق داكن كلاسيكي
      Color(0xFF3b82f6), // أزرق متوسط أنيق
    ], CustomerFormPage()),
    DashboardItem("التنازلات", Icons.production_quantity_limits, [
      Color(0xFF1e3a8a), // أزرق داكن رسمي
      Color(0xFF60a5fa), // أزرق سماوي فاتح
    ], ContractAssignmentsPage()),
    DashboardItem("المالية", Icons.account_balance_wallet_outlined, [
      Color(0xFF2563eb), // أزرق متوسط جميل
      Color(0xFF93c5fd), // أزرق لافندر فاتح
    ], FinancialOperationsPage()),
    DashboardItem("عرض المديونية", Icons.account_balance_outlined, [
      Color(0xFF059669), // أخضر داكن
      Color(0xFF34d399), // أخضر فاتح
    ], DebtDisplayPage()),
    DashboardItem("التحديثات", Icons.refresh_outlined, [
      Color(0xFF1d4ed8), // أزرق ملكي
      Color(0xFF7dd3fc), // أزرق سماوي فاتح جداً
    ], LuxuryLogsPage()),
    DashboardItem("لوحة المشاريع والعملاء", Icons.analytics_outlined, [
      Color(0xFF1e40af), // أزرق داكن كلاسيكي
      Color(0xFF60a5fa), // أزرق سماوي فاتح
    ], ProjectsDashboardScreen()),
    // حذف مؤقت لصفحة النسخ الاحتياطي
    DashboardItem("النسخ الاحتياطي ", Icons.refresh_outlined, [
      Color(0xFF0284c7), // أزرق سماوي داكن
      Color(0xFF38bdf8), // أزرق سماوي فاتح
    ], DatabaseManagementPage()),
    DashboardItem(
      "طلبات الموافقة",
      Icons.security_outlined,
      [Color(0xFF1e3a8a), Color(0xFF93c5fd)], // أزرق داكن إلى لافندر
      ApprovalRequestsPage(
        currentUserEmail: 'zizoalzohairy@gmail.com',
        userType: 'مستر',
      ),
    ),
    DashboardItem(
      "إدارة الإشعارات",
      Icons.notifications_outlined,
      [Color(0xFF7c3aed), Color(0xFFa855f7)], // بنفسجي أنيق
      FreeNotificationsAdminPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.linear),
    );

    _cardScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeInOut),
    );

    _sidebarAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _sidebarController, curve: Curves.elasticOut),
    );

    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _backgroundController.repeat();
    _sidebarController.forward();
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _cardController.dispose();
    _sidebarController.dispose();
    _floatingController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 800 && size.width <= 1200;
    final isMobile = size.width <= 800;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor:
          isDarkMode
              ? Color(0xFF2D3748)
              : Color(0xFFE8EBF0), // خلفية Neumorphism
      drawer: isMobile ? _buildGlassmorphicDrawer() : null,
      body: Container(
        decoration: BoxDecoration(
          color:
              isDarkMode
                  ? Color(0xFF2D3748)
                  : Color(0xFFE8EBF0), // لون موحد للـ Neumorphism
        ),
        child: Stack(
          children: [
            _buildAnimatedBackground(),
            Row(
              children: [
                if (isDesktop) _buildAdvancedSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildGlassmorphicHeader(isMobile),
                      Expanded(
                        child: _buildMainContent(isMobile, isTablet, isDesktop),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildFloatingActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlesPainter(_backgroundAnimation.value, isDarkMode),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildGlassmorphicHeader(bool isMobile) {
    return Container(
      height: 80,
      margin: EdgeInsets.all(isMobile ? 8 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20), // حواف ناعمة للـ Neumorphism
        color:
            isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0), // لون الخلفية
        boxShadow: [
          // ظل علوي فاتح (Neumorphism)
          BoxShadow(
            color:
                isDarkMode
                    ? Color(0xFF4A5568).withOpacity(0.8)
                    : Colors.white.withOpacity(0.8),
            offset: Offset(-8, -8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          // ظل سفلي داكن (Neumorphism)
          BoxShadow(
            color:
                isDarkMode
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Color(0xFFBEBEBE).withOpacity(0.8),
            offset: Offset(8, 8),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
        child: Row(
          children: [
            if (isMobile) ...[
              _buildGlowingButton(
                icon: Icons.menu_rounded,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              SizedBox(width: 12),
            ],
            _buildAnimatedLogo(),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                isMobile
                    ? 'مساكن الرفاهية'
                    : 'لوحة تحكم المستر - مساكن الرفاهية',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 22,
                  fontWeight: FontWeight.bold,
                  color:
                      isDarkMode
                          ? Color(0xFFE2E8F0)
                          : Color(0xFF2D3748), // لون النص للـ Neumorphism
                ),
              ),
            ),
            SizedBox(width: isMobile ? 6 : 18),
            _buildGlowingButton(
              icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
              onPressed: () => setState(() => isDarkMode = !isDarkMode),
            ),
            SizedBox(width: 6),
            _buildUserAvatar(showLabel: !isMobile),
            SizedBox(width: 6),
            _buildGlowingButton(
              icon: Icons.logout_rounded,
              onPressed: _showLogoutDialog,
              color: Color(0xFFf43f5e),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            math.sin(_floatingAnimation.value * 2 * math.pi) * 5,
          ),
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color:
                  isDarkMode
                      ? Color(0xFF2D3748)
                      : Color(0xFFE8EBF0), // لون الخلفية Neumorphism
              boxShadow: [
                // ظل علوي فاتح
                BoxShadow(
                  color:
                      isDarkMode
                          ? Color(0xFF4A5568).withOpacity(0.8)
                          : Colors.white.withOpacity(0.8),
                  offset: Offset(-4, -4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                // ظل سفلي داكن
                BoxShadow(
                  color:
                      isDarkMode
                          ? Color(0xFF1A202C).withOpacity(0.8)
                          : Color(0xFFBEBEBE).withOpacity(0.8),
                  offset: Offset(4, 4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.home_work_rounded,
              color:
                  isDarkMode
                      ? Color(0xFF63B3ED)
                      : Color(0xFF3182CE), // لون الأيقونة
              size: 23,
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar({bool showLabel = true}) {
    return GestureDetector(
      onTap:
          showLabel
              ? null
              : () {
                // إظهار اللابل عند النقر في شاشة الجوال
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(widget.username),
                    duration: Duration(seconds: 2),
                    backgroundColor:
                        isDarkMode ? Color(0xFF4A5568) : Color(0xFF2D3748),
                  ),
                );
              },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color:
              isDarkMode
                  ? Color(0xFF2D3748)
                  : Color(0xFFE8EBF0), // لون الخلفية Neumorphism
          boxShadow: [
            // ظل علوي فاتح
            BoxShadow(
              color:
                  isDarkMode
                      ? Color(0xFF4A5568).withOpacity(0.6)
                      : Colors.white.withOpacity(0.6),
              offset: Offset(-3, -3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
            // ظل سفلي داكن
            BoxShadow(
              color:
                  isDarkMode
                      ? Color(0xFF1A202C).withOpacity(0.6)
                      : Color(0xFFBEBEBE).withOpacity(0.6),
              offset: Offset(3, 3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDarkMode ? Color(0xFF4A5568) : Colors.white,
              child: Text(
                widget.username.isNotEmpty
                    ? widget.username[0].toUpperCase()
                    : "M",
                style: TextStyle(
                  color: isDarkMode ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            if (showLabel) ...[
              SizedBox(width: 5),
              Text(
                widget.username,
                style: TextStyle(
                  color:
                      isDarkMode
                          ? Color(0xFFE2E8F0)
                          : Color(0xFF2D3748), // لون النص للـ Neumorphism
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final iconColor =
        color ?? (isDarkMode ? Color(0xFF63B3ED) : Color(0xFF3182CE));

    return GestureDetector(
      onTapDown: (_) => _cardController.forward(),
      onTapUp: (_) => _cardController.reverse(),
      onTapCancel: () => _cardController.reverse(),
      onTap: onPressed,
      child: AnimatedBuilder(
        animation: _cardScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _cardScaleAnimation.value,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  12,
                ), // حواف ناعمة للـ Neumorphism
                color:
                    isDarkMode
                        ? Color(0xFF2D3748)
                        : Color(0xFFE8EBF0), // لون الخلفية
                boxShadow: [
                  // ظل علوي فاتح
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Color(0xFF4A5568).withOpacity(0.8)
                            : Colors.white.withOpacity(0.8),
                    offset: Offset(-3, -3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                  // ظل سفلي داكن
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Color(0xFF1A202C).withOpacity(0.8)
                            : Color(0xFFBEBEBE).withOpacity(0.8),
                    offset: Offset(3, 3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedSidebar() {
    return SlideTransition(
      position: _sidebarAnimation,
      child: Container(
        width: 230,
        margin: EdgeInsets.only(top: 16, right: 8, bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // حواف ناعمة للـ Neumorphism
          color:
              isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0), // لون الخلفية
          boxShadow: [
            // ظل علوي فاتح
            BoxShadow(
              color:
                  isDarkMode
                      ? Color(0xFF4A5568).withOpacity(0.8)
                      : Colors.white.withOpacity(0.8),
              offset: Offset(-10, -10),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            // ظل سفلي داكن
            BoxShadow(
              color:
                  isDarkMode
                      ? Color(0xFF1A202C).withOpacity(0.8)
                      : Color(0xFFBEBEBE).withOpacity(0.8),
              offset: Offset(10, 10),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildAnimatedLogo(),
                  SizedBox(height: 10),
                  Text(
                    'مساكن الرفاهية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                    ),
                  ),
                  Text(
                    'للتطوير العقاري',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Color(0xFFA0AEC0) : Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimationLimiter(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: Duration(milliseconds: 500),
                      child: SlideAnimation(
                        horizontalOffset: 40.0,
                        child: FadeInAnimation(
                          child: _buildAdvancedMenuItem(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(padding: EdgeInsets.all(10), child: _buildSettingsButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedMenuItem(int index) {
    final item = items[index];
    final isSelected = _selectedIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8), // تعديل هنا
        child: InkWell(
          borderRadius: BorderRadius.circular(2), // حواف حادة رسمية
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _pageController.animateToPage(
                index,
                duration: Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
              );
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                15,
              ), // حواف ناعمة للـ Neumorphism
              color:
                  isSelected
                      ? (isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0))
                      : Colors.transparent,
              boxShadow:
                  isSelected
                      ? [
                        // ظل علوي فاتح
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Color(0xFF4A5568).withOpacity(0.6)
                                  : Colors.white.withOpacity(0.6),
                          offset: Offset(-5, -5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                        // ظل سفلي داكن
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Color(0xFF1A202C).withOpacity(0.6)
                                  : Color(0xFFBEBEBE).withOpacity(0.6),
                          offset: Offset(5, 5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                      : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                    boxShadow: [
                      // ظل علوي فاتح
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Color(0xFF4A5568).withOpacity(0.6)
                                : Colors.white.withOpacity(0.6),
                        offset: Offset(-3, -3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                      // ظل سفلي داكن
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Color(0xFF1A202C).withOpacity(0.6)
                                : Color(0xFFBEBEBE).withOpacity(0.6),
                        offset: Offset(3, 3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    item.icon,
                    color: isDarkMode ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                    size: 18,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      shadows: [
                        Shadow(
                          color:
                              isDarkMode
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.5),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          // ظل علوي فاتح
          BoxShadow(
            color:
                isDarkMode
                    ? Color(0xFF4A5568).withOpacity(0.6)
                    : Colors.white.withOpacity(0.6),
            offset: Offset(-5, -5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          // ظل سفلي داكن
          BoxShadow(
            color:
                isDarkMode
                    ? Color(0xFF1A202C).withOpacity(0.6)
                    : Color(0xFFBEBEBE).withOpacity(0.6),
            offset: Offset(5, 5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.settings_outlined,
            color: isDarkMode ? Color(0xFFA0AEC0) : Color(0xFF718096),
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            'الإعدادات',
            style: TextStyle(
              color: isDarkMode ? Color(0xFFA0AEC0) : Color(0xFF718096),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isMobile, bool isTablet, bool isDesktop) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 8 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20), // حواف ناعمة للـ Neumorphism
        color: isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
        boxShadow: [
          // ظل علوي فاتح
          BoxShadow(
            color:
                isDarkMode
                    ? Color(0xFF4A5568).withOpacity(0.8)
                    : Colors.white.withOpacity(0.8),
            offset: Offset(-15, -15),
            blurRadius: 30,
            spreadRadius: 3,
          ),
          // ظل سفلي داكن
          BoxShadow(
            color:
                isDarkMode
                    ? Color(0xFF1A202C).withOpacity(0.8)
                    : Color(0xFFBEBEBE).withOpacity(0.8),
            offset: Offset(15, 15),
            blurRadius: 30,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20), // حواف ناعمة للـ Neumorphism
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          itemCount: items.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: Duration(milliseconds: 800),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: items[index].page),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  math.sin(_floatingAnimation.value * 2 * math.pi) * 3,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
                    boxShadow: [
                      // ظل علوي فاتح
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Color(0xFF4A5568).withOpacity(0.8)
                                : Colors.white.withOpacity(0.8),
                        offset: Offset(-8, -8),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                      // ظل سفلي داكن
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Color(0xFF1A202C).withOpacity(0.8)
                                : Color(0xFFBEBEBE).withOpacity(0.8),
                        offset: Offset(8, 8),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_selectedIndex > 0) {
                            setState(() {
                              _selectedIndex--;
                              _pageController.animateToPage(
                                _selectedIndex,
                                duration: Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                              );
                            });
                          }
                        },
                        child: Icon(
                          Icons.arrow_back_ios_rounded,
                          color:
                              isDarkMode
                                  ? Color(0xFFE2E8F0)
                                  : Color(0xFF2D3748),
                          size: 17,
                        ),
                      ),
                      SizedBox(width: 9),
                      Text(
                        "${_selectedIndex + 1} / ${items.length}",
                        style: TextStyle(
                          color:
                              isDarkMode
                                  ? Color(0xFFE2E8F0)
                                  : Color(0xFF2D3748),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 9),
                      GestureDetector(
                        onTap: () {
                          if (_selectedIndex < items.length - 1) {
                            setState(() {
                              _selectedIndex++;
                              _pageController.animateToPage(
                                _selectedIndex,
                                duration: Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                              );
                            });
                          }
                        },
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color:
                              isDarkMode
                                  ? Color(0xFFE2E8F0)
                                  : Color(0xFF2D3748),
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0),
          boxShadow: [
            // ظل داخلي علوي فاتح
            BoxShadow(
              color:
                  isDarkMode
                      ? Color(0xFF4A5568).withOpacity(0.6)
                      : Colors.white.withOpacity(0.8),
              offset: Offset(-5, -5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
            // ظل داخلي سفلي داكن
            BoxShadow(
              color:
                  isDarkMode
                      ? Color(0xFF1A202C).withOpacity(0.8)
                      : Color(0xFFBEBEBE).withOpacity(0.6),
              offset: Offset(5, 5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(0),
            bottomRight: Radius.circular(0),
          ),
          child: Column(
            children: [
              Container(
                height: 160,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF4A5568) : Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    // ظل علوي فاتح
                    BoxShadow(
                      color:
                          isDarkMode
                              ? Color(0xFF5A6B7D).withOpacity(0.6)
                              : Colors.white.withOpacity(0.8),
                      offset: Offset(-3, -3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                    // ظل سفلي داكن
                    BoxShadow(
                      color:
                          isDarkMode
                              ? Color(0xFF2D3748).withOpacity(0.8)
                              : Color(0xFFBEBEBE).withOpacity(0.6),
                      offset: Offset(3, 3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnimatedLogo(),
                    SizedBox(height: 10),
                    Text(
                      'مساكن الرفاهية',
                      style: TextStyle(
                        color:
                            isDarkMode ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'للتطوير العقاري',
                      style: TextStyle(
                        color:
                            isDarkMode ? Color(0xFFCBD5E0) : Color(0xFF4A5568),
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 5),
                    _buildUserAvatar(),
                  ],
                ),
              ),
              Expanded(
                child: AnimationLimiter(
                  child: ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: Duration(milliseconds: 500),
                        child: SlideAnimation(
                          horizontalOffset: 40.0,
                          child: FadeInAnimation(
                            child: _buildDrawerMenuItem(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem(int index) {
    final item = items[index];
    final isSelected = _selectedIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _pageController.animateToPage(
                index,
                duration: Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
              );
            });
            Navigator.pop(context);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color:
                  isSelected
                      ? (isDarkMode ? Color(0xFF4A5568) : Color(0xFFD1D5DB))
                      : (isDarkMode ? Color(0xFF2D3748) : Color(0xFFE8EBF0)),
              boxShadow:
                  isSelected
                      ? [
                        // ظل داخلي للعنصر المحدد
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Color(0xFF1A202C).withOpacity(0.8)
                                  : Color(0xFFBEBEBE).withOpacity(0.6),
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Color(0xFF5A6B7D).withOpacity(0.6)
                                  : Colors.white.withOpacity(0.8),
                          offset: Offset(-2, -2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ]
                      : [
                        // ظل خارجي للعناصر غير المحددة
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Color(0xFF4A5568).withOpacity(0.6)
                                  : Colors.white.withOpacity(0.8),
                          offset: Offset(-2, -2),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Color(0xFF1A202C).withOpacity(0.6)
                                  : Color(0xFFBEBEBE).withOpacity(0.6),
                          offset: Offset(2, 2),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDarkMode ? Color(0xFF4A5568) : Color(0xFFD1D5DB),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Color(0xFF5A6B7D).withOpacity(0.6)
                                : Colors.white.withOpacity(0.8),
                        offset: Offset(-1, -1),
                        blurRadius: 3,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Color(0xFF2D3748).withOpacity(0.8)
                                : Color(0xFFBEBEBE).withOpacity(0.6),
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    item.icon,
                    color: isDarkMode ? Color(0xFFE2E8F0) : Color(0xFF2D3748),
                    size: 15,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              content: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors:
                        isDarkMode
                            ? [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ]
                            : [
                              Colors.black.withOpacity(0.15),
                              Colors.black.withOpacity(0.05),
                            ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFf43f5e),
                      size: 44,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogButton(
                            text: 'إلغاء',
                            onPressed: () => Navigator.pop(context),
                            gradient: [Colors.grey, Colors.grey[600]!],
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildDialogButton(
                            text: 'تأكيد',
                            onPressed: () async {
                              try {
                                // تسجيل الخروج من Firebase
                                await FirebaseAuth.instance.signOut();

                                // إعادة ضبط حالة المستخدم إن كنت تستخدم Provider (اختياري)
                                // context.read<UserProvider>().logout();  // إذا كان عندك UserProvider

                                // الانتقال إلى صفحة تسجيل الدخول واستبدال كل الصفحات السابقة
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LoginScreen1(),
                                  ),
                                );
                              } catch (e) {
                                print('خطأ أثناء تسجيل الخروج: $e');
                              }
                            },
                            gradient: [Color(0xFFf43f5e), Color(0xFFe11d48)],
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

  Widget _buildDialogButton({
    required String text,
    required VoidCallback onPressed,
    required List<Color> gradient,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.18),
              blurRadius: 7,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// Custom Particles Painter for Animated Background
class ParticlesPainter extends CustomPainter {
  final double animationValue;
  final bool isDarkMode;

  ParticlesPainter(this.animationValue, this.isDarkMode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Create multiple floating particles
    for (int i = 0; i < 50; i++) {
      final double progress = (animationValue + i * 0.02) % 1.0;
      final double x = (i * 47) % size.width;
      final double y = size.height * progress;

      final double opacity = (math.sin(progress * math.pi) * 0.7).clamp(
        0.0,
        1.0,
      );

      paint.color = [
        Color(0xFF3b82f6),
        Color(0xFF8b5cf6),
        Color(0xFF06b6d4),
        Color(0xFFfbbf24),
        Color(0xFFf43f5e),
      ][i % 5].withOpacity(opacity * (isDarkMode ? 0.3 : 0.1));

      canvas.drawCircle(
        Offset(x, y),
        2 + (math.sin(progress * math.pi * 4) * 2),
        paint,
      );
    }

    // Add some larger floating elements
    for (int i = 0; i < 10; i++) {
      final double progress = (animationValue * 0.5 + i * 0.1) % 1.0;
      final double x =
          (i * 123 + math.sin(progress * math.pi * 2) * 100) % size.width;
      final double y =
          (size.height * progress + math.cos(progress * math.pi * 2) * 50) %
          size.height;

      final double opacity = (math.sin(progress * math.pi) * 0.4).clamp(
        0.0,
        1.0,
      );

      paint.color = [
        Color(0xFF667eea),
        Color(0xFF764ba2),
        Color(0xFFf093fb),
      ][i % 3].withOpacity(opacity * (isDarkMode ? 0.2 : 0.05));

      canvas.drawCircle(
        Offset(x, y),
        5 + (math.sin(progress * math.pi * 3) * 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DashboardItem {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final Widget page;

  DashboardItem(this.title, this.icon, this.gradientColors, this.page);
}

class DummyPage extends StatelessWidget {
  final String title;

  const DummyPage(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_rounded,
              size: 60,
              color: Color(0xFF667eea).withOpacity(0.7),
            ),
            SizedBox(height: 24),
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [
                      Color(0xFF667eea),
                      Color(0xFF764ba2),
                      Color(0xFFf093fb),
                    ],
                  ).createShader(bounds),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'هذه صفحة $title\nصُممت بتقنيات متقدمة وتأثيرات بصرية مذهلة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF667eea).withOpacity(0.8),
                    Color(0xFF764ba2).withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF667eea).withOpacity(0.18),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                'ابدأ العمل',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
