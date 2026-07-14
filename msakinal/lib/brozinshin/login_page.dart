import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:msakinal/brozinshin/الماليه/malih.dart';
import 'package:msakinal/priovider/auth_provider.dart';
import 'package:msakinal/priovider/projects_dashboard.dart';
import 'package:provider/provider.dart';
import '../priovider/dash.dart';
import 'dashpordadmin.dart';
import '../building_layout_page.dart';

class LoginScreen1 extends StatefulWidget {
  const LoginScreen1({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen1>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = "يرجى إدخال البريد الإلكتروني وكلمة المرور";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.delayed(Duration(milliseconds: 300));
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = credential.user!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        setState(() {
          _error = 'لم يتم العثور على صلاحيات لهذا المستخدم.';
        });
        return;
      }

      final data = userDoc.data()!;
      final role = data['role'];
      final name = data['name'];
      final email = _emailController.text.trim();

      await Provider.of<AppAuthProvider>(
        context,
        listen: false,
      ).login(name, email: email, userType: role);

      if (role == 'مستر') {
        _navigateWithAnimation(() => EpicMasterDashboard(username: name));
      } else if (role == 'مدير') {
        _navigateWithAnimation(() => NewProfessionalDashboardScreen());
      } else if (role == 'مدير1') {
        _navigateWithAnimation(() => EpicMasterDashboard(username: name));
      } else if (role == 'محاسب') {
        _navigateWithAnimation(() => FinancialOperationsPage());
      } else if (role == 'مسوق') {
        _navigateWithAnimation(() => ProjectsDashboardScreen());
      } else {
        setState(() {
          _error = 'نوع صلاحية غير معروف.';
        });
      }
    } catch (e) {
      setState(() {
        _error = "فشل تسجيل الدخول: ${e.toString()}";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _navigateWithAnimation(Widget Function() destinationBuilder) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => destinationBuilder(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var curve = Curves.easeInOut;
          var curveTween = CurveTween(curve: curve);

          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(animation.drive(curveTween));

          var slideAnimation = Tween<Offset>(
            begin: Offset(0.0, 0.5),
            end: Offset.zero,
          ).animate(animation.drive(curveTween));

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: isDarkMode ? Color(0xFF0F1419) : Color(0xFFF8FAFC),
      body: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // النصف الأيسر - وصف الشركة
        Expanded(flex: 3, child: _buildCompanySection()),
        // النصف الأيمن - نموذج تسجيل الدخول
        Expanded(flex: 2, child: _buildLoginSection()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDarkMode
                  ? [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF334155),
                    Color(0xFF475569),
                  ]
                  : [
                    Color(0xFFFFFFFF),
                    Color(0xFFF8FAFC),
                    Color(0xFFE2E8F0),
                    Color(0xFFCBD5E1),
                  ],
        ),
      ),
      child: Stack(
        children: [
          _buildProfessionalBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  children: [
                    // القسم العلوي المحسن مع الشعار والترحيب
                    Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: _buildProfessionalMobileHeader(),
                    ),
                    // قسم تسجيل الدخول المحسن
                    _buildProfessionalMobileLoginForm(),
                  ],
                ),
              ),
            ),
          ),
          // زر تبديل الوضع المحسن
          Positioned(
            top: 50,
            right: 20,
            child: _buildProfessionalThemeToggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySection({bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDarkMode
                  ? [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF1D4ED8)]
                  : [Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
        ),
      ),
      child: Stack(
        children: [
          // خلفية متحركة
          Positioned.fill(
            child: CustomPaint(
              painter: ProfessionalBackgroundPainter(
                isDarkMode: isDarkMode,
                animationValue: 1.3,
              ),
            ),
          ),
          // المحتوى
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile) ...[
                  // الشعار
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Image.asset(
                        'images/2.png',
                        height: 100,
                        width: 100,
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
                // العنوان الرئيسي
                SlideTransition(
                  position: _slideAnimation,
                  child: Text(
                    isMobile ? "مرحباً بك" : "مرحباً بك في منصة مساكن الرفاهية",
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 20),
                // الوصف
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    isMobile
                        ? "إدارة مشاريعك العقارية بسهولة"
                        : "منصة شاملة لإدارة المشاريع العقارية والعملاء والعمليات المالية بكفاءة عالية ودقة متناهية",
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 18,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.6,
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  SizedBox(height: 40),
                  // المميزات
                  ..._buildFeaturesList(),
                ],
              ],
            ),
          ),
          // زر تبديل الثيم
          Positioned(top: 20, right: 20, child: _buildThemeToggle()),
          // وصف المطور
          Positioned(
            bottom: 10,
            left: 10,
            child: Opacity(
              opacity: 0.7,
              child: Text(
                "Developed by Zohair Al Zohairy\nzizozoahir11@gmail.com",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // قسم الهيدر الاحترافي للجوال
  Widget _buildProfessionalMobileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // الشعار الاحترافي المحسن
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 1500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF3B82F6),
                        Color(0xFF1D4ED8),
                        Color(0xFF1E40AF),
                        Color(0xFF1E3A8A),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF3B82F6).withOpacity(0.4),
                        blurRadius: 25,
                        offset: Offset(0, 12),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 15,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Image.asset('images/2.png', height: 50, width: 50),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20),
          // العنوان الاحترافي
          AnimatedContainer(
            duration: Duration(milliseconds: 800),
            child: ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF1D4ED8),
                      Color(0xFF1E40AF),
                    ],
                  ).createShader(bounds),
              child: Text(
                "مساكن الرفاهية",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(height: 8),
          // الوصف الاحترافي
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Text(
              "منصة إدارة المشاريع العقارية المتطورة",
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[300] : Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
          // أيقونات الميزات الاحترافية
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProfessionalFeatureIcon(
                  Icons.dashboard_outlined,
                  "لوحة التحكم",
                ),
                _buildProfessionalFeatureIcon(
                  Icons.analytics_outlined,
                  "التقارير",
                ),
                _buildProfessionalFeatureIcon(
                  Icons.security_outlined,
                  "الأمان",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // أيقونة مميزة للجوال
  Widget _buildProfessionalFeatureIcon(IconData icon, String label) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // نموذج تسجيل الدخول الاحترافي للجوال
  Widget _buildProfessionalMobileLoginForm() {
    return Container(
      decoration: BoxDecoration(
        color:
            isDarkMode
                ? Color(0xFF0F1419).withOpacity(0.98)
                : Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: Offset(0, -15),
            spreadRadius: 5,
          ),
          BoxShadow(
            color:
                isDarkMode
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 20, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مؤشر السحب المحسن
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF3B82F6).withOpacity(0.3),
                    Color(0xFF1D4ED8).withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: 24),
            // العنوان الاحترافي
            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "تسجيل الدخول",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDarkMode ? Colors.white : Color(0xFF1F2937),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? Color(0xFF3B82F6).withOpacity(0.05)
                        : Color(0xFF3B82F6).withOpacity(0.03),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                "أدخل بياناتك للوصول إلى حسابك",
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 28),
            // حقول الإدخال المحسنة
            _buildProfessionalTextField(
              controller: _emailController,
              label: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 18),
            _buildProfessionalTextField(
              controller: _passwordController,
              label: 'كلمة المرور',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: isDarkMode ? Colors.grey[400] : Color(0xFF6B7280),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            SizedBox(height: 28),
            // زر تسجيل الدخول الاحترافي المحسن
            _buildProfessionalLoginButton(),
            // رسالة الخطأ المحسنة
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginSection({bool isMobile = false}) {
    return Container(
      color: isDarkMode ? Color(0xFF0F1419) : Color(0xFFF8FAFC),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 24 : 48),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: isMobile ? double.infinity : 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMobile) SizedBox(height: 20),
                  // العنوان
                  Text(
                    "تسجيل الدخول",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Color(0xFF1F2937),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "أدخل بياناتك للوصول إلى حسابك",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
                  // حقل البريد الإلكتروني
                  _buildModernTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 20),
                  // حقل كلمة المرور
                  _buildModernTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color:
                            isDarkMode ? Colors.grey[400] : Color(0xFF6B7280),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 32),
                  // زر تسجيل الدخول
                  _loading
                      ? Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      )
                      : Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "تسجيل الدخول",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  // رسالة الخطأ
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalBackground() {
    return Stack(
      children: [
        // الخلفية المتحركة الأساسية
        CustomPaint(
          painter: ProfessionalBackgroundPainter(
            animationValue: _animationController.value,
            isDarkMode: isDarkMode,
          ),
          size: Size.infinite,
        ),
        // طبقة إضافية من التأثيرات
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  isDarkMode
                      ? Colors.black.withOpacity(0.1)
                      : Colors.white.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFeaturesList() {
    final features = [
      {'icon': Icons.dashboard_outlined, 'text': 'لوحة تحكم شاملة'},
      {'icon': Icons.people_outline, 'text': 'إدارة العملاء والمشاريع'},
      {'icon': Icons.analytics_outlined, 'text': 'تقارير مالية دقيقة'},
      {'icon': Icons.security_outlined, 'text': 'أمان وحماية عالية'},
    ];

    return features.map((feature) {
      return Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Text(
                feature['text'] as String,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildProfessionalThemeToggle() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    isDarkMode
                        ? [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ]
                        : [
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.03),
                        ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color:
                    isDarkMode
                        ? Colors.white.withOpacity(0.25)
                        : Colors.black.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 22,
                ),
              ),
              onPressed: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: IconButton(
        onPressed: () {
          setState(() {
            isDarkMode = !isDarkMode;
          });
        },
        icon: Icon(
          isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: Colors.white,
        ),
        tooltip: isDarkMode ? "الوضع النهاري" : "الوضع الليلي",
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Color(0xFF374151) : Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDarkMode
                    ? Colors.black.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.white : Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Color(0xFF6B7280),
          ),
          prefixIcon: Icon(
            icon,
            color: isDarkMode ? Colors.grey[400] : Color(0xFF6B7280),
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // حقل نص محسن للجوال
  Widget _buildProfessionalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDarkMode
                          ? [
                            Color(0xFF1F2937).withOpacity(0.9),
                            Color(0xFF374151).withOpacity(0.8),
                          ]
                          : [
                            Colors.white.withOpacity(0.95),
                            Color(0xFFF8FAFC).withOpacity(0.9),
                          ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isDarkMode
                          ? Color(0xFF4B5563).withOpacity(0.6)
                          : Color(0xFFE5E7EB).withOpacity(0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF3B82F6).withOpacity(0.15),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Colors.white.withOpacity(0.02)
                            : Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: Container(
                    margin: EdgeInsets.all(14),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF3B82F6).withOpacity(0.15),
                          Color(0xFF1D4ED8).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFF3B82F6).withOpacity(0.2),
                      ),
                    ),
                    child: Icon(icon, color: Color(0xFF3B82F6), size: 22),
                  ),
                  suffixIcon: suffixIcon,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // زر تسجيل الدخول المحسن
  Widget _buildProfessionalLoginButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 1000),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    _loading
                        ? [Colors.grey[400]!, Colors.grey[500]!]
                        : [
                          Color(0xFF3B82F6),
                          Color(0xFF1D4ED8),
                          Color(0xFF1E40AF),
                          Color(0xFF1E3A8A),
                        ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF3B82F6).withOpacity(0.4),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child:
                    _loading
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              "جاري تسجيل الدخول...",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.login_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "تسجيل الدخول",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// رسام الخلفية المتحركة
class ProfessionalBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDarkMode;

  ProfessionalBackgroundPainter({
    required this.animationValue,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // رسم دوائر متحركة محسنة
    for (int i = 0; i < 8; i++) {
      final progress = (animationValue + i * 0.15) % 1.0;
      final radius = size.width * 0.08 * (1 + progress * 0.5);
      final opacity = (1 - progress) * 0.08;

      // تدرج لوني للدوائر
      final gradient = RadialGradient(
        colors:
            isDarkMode
                ? [
                  Colors.white.withOpacity(opacity * 2),
                  Colors.white.withOpacity(opacity * 0.5),
                  Colors.transparent,
                ]
                : [
                  Color(0xFF3B82F6).withOpacity(opacity * 2),
                  Color(0xFF1D4ED8).withOpacity(opacity),
                  Colors.transparent,
                ],
      );

      paint.shader = gradient.createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * (0.1 + i * 0.12),
            size.height * (0.2 + (i % 3) * 0.25 + progress * 0.1),
          ),
          radius: radius,
        ),
      );

      final center = Offset(
        size.width * (0.1 + i * 0.12),
        size.height * (0.2 + (i % 3) * 0.25 + progress * 0.1),
      );

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimatedBackgroundPainter extends CustomPainter {
  final double animationValue;

  AnimatedBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.fill;

    // رسم دوائر متحركة
    for (int i = 0; i < 5; i++) {
      final radius = 50 + (i * 30);
      final x = size.width * 0.8 + (animationValue * 100) - (i * 50);
      final y = size.height * 0.3 + (animationValue * 50) + (i * 80);

      canvas.drawCircle(
        Offset(x % (size.width + 200) - 100, y % (size.height + 200) - 100),
        radius as double,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
