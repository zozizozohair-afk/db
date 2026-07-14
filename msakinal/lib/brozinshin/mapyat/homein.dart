import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:msakinal/brozinshin/admin/agencies_list_page.dart';
import '../../class/التحديثات.dart';
import '../admin/okod.dart';
import '../admin/العملاء.dart';
import '../admin/صفحة_الاضافة_محسنة.dart';
import 'mshro.dart';
import '2222.dart';
import 'dart:ui';

class HomePage11 extends StatefulWidget {
  const HomePage11({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage11>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool isDarkMode = false;

  final List<_Section> _sections = [
    _Section('العقود', Icons.assignment, Colors.teal),
    _Section('المشاريع', Icons.business, Colors.blue),
    _Section('البيع', Icons.shop, Colors.purple),
    _Section('العملاء', Icons.person_outline, Colors.orange),
    _Section('الصكوك المحسنة', Icons.upload_file, Colors.green),
    _Section('المستجدات', Icons.new_releases, Colors.red),
    _Section(
      'الوكالات',
      Icons.new_releases,
      const Color.fromARGB(255, 232, 186, 0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _loadUserData();
  }

  void _loadUserData() async {
    _user = _auth.currentUser;
    setState(() {});
  }

  void _signOut() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('تأكيد المغادرة'),
                content: Text('هل أنت متأكد أنك تريد مغادرة التطبيق؟'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('لا'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('نعم', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showExitConfirmation,
      child: Scaffold(
        appBar: _buildGlassAppBar(context),
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => isDarkMode = !isDarkMode),
          backgroundColor: isDarkMode ? Colors.indigo : Colors.amber,
          tooltip: isDarkMode ? "وضع ليلي" : "وضع نهاري",
          child: Icon(
            isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: Size.fromHeight(80),
      child: SafeArea(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors:
                  isDarkMode
                      ? [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.3),
                      ]
                      : [
                        Colors.white.withOpacity(0.85),
                        Colors.blue.withOpacity(0.08),
                      ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.06),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(Icons.home, color: Colors.indigo, size: 30),
                    SizedBox(width: 16),
                    Text(
                      'مساكن الرفاهية',
                      style: TextStyle(
                        color: Colors.indigo[700],
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 1.2,
                        fontFamily: 'tg',
                      ),
                    ),
                    Spacer(),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child:
                          _user != null
                              ? Text(
                                _user!.displayName?.substring(0, 1) ?? 'U',
                                style: TextStyle(color: Colors.blueGrey),
                              )
                              : Icon(Icons.person, color: Colors.blueGrey),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _user?.displayName ?? 'ضيف',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.logout, color: Colors.redAccent),
                      tooltip: "تسجيل الخروج",
                      onPressed: _signOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.builder(
        padding: EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
        itemCount: _sections.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,
          childAspectRatio: 2.4,
        ),
        itemBuilder: (context, idx) => _buildSectionCard(_sections[idx], idx),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.separated(
        padding: EdgeInsets.only(top: 110, left: 18, right: 18, bottom: 18),
        itemCount: _sections.length,
        separatorBuilder: (context, _) => SizedBox(height: 14),
        itemBuilder: (context, idx) => _buildSectionCard(_sections[idx], idx),
      ),
    );
  }

  Widget _buildSectionCard(_Section section, int idx) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 400 + idx * 80),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToPage(section.title),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            constraints: BoxConstraints(minHeight: 72, maxHeight: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(section.icon, size: 24, color: Colors.indigo.shade700),
                SizedBox(height: 6),
                Text(
                  section.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _getSectionSubtitle(section.title),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSectionSubtitle(String title) {
    switch (title) {
      case 'العقود':
        return 'إدارة وإنشاء العقود';
      case 'المشاريع':
        return 'بيانات المشاريع والوحدات';
      case 'البيع':
        return 'إجراءات البيع وإتمامها';
      case 'العملاء':
        return 'إضافة وتحديث العملاء';
      case 'الصكوك المحسنة':
        return 'رفع وتحديث بيانات الصكوك';
      case 'المستجدات':
        return 'سجل المستجدات والتحديثات';
      case 'الوكالات':
        return 'قائمة وإدارة الوكالات';
      default:
        return '';
    }
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlesPainter(_animationController.value, isDarkMode),
          size: Size.infinite,
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToPage(String title) {
    switch (title) {
      case 'العقود':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContractsPage()),
        );
        break;
      case 'المشاريع':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProjectsPage11()),
        );
        break;
      case 'البيع':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContractsPage12()),
        );
        break;
      case 'العملاء':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CustomerFormPage()),
        );
        break;
      case 'الصكوك المحسنة':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UpdateDeedPageEnhanced()),
        );
        break;
      case 'المستجدات':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LuxuryLogsPage()),
        );
      case 'الوكالات':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AgenciesListPage()),
        );
        break;
      default:
        print('الصفحة غير معروفة');
    }
  }
}

class _Section {
  final String title;
  final IconData icon;
  final Color color;
  _Section(this.title, this.icon, this.color);
}

class _ParticlesPainter extends CustomPainter {
  final double animationValue;
  final bool isDarkMode;
  _ParticlesPainter(this.animationValue, this.isDarkMode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 35; i++) {
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
      ][i % 5].withOpacity(opacity * (isDarkMode ? 0.25 : 0.10));

      canvas.drawCircle(
        Offset(x, y),
        2 + (math.sin(progress * math.pi * 3) * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
