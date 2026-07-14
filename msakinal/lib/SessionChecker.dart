import 'package:flutter/material.dart';
import 'package:msakinal/priovider/auth_provider.dart';
import 'package:msakinal/priovider/dash.dart';
import 'package:provider/provider.dart';

import 'brozinshin/dashpordadmin.dart';
import 'brozinshin/login_page.dart';
import 'brozinshin/الماليه/malih.dart';

import 'priovider/projects_dashboard.dart';

class SessionChecker extends StatefulWidget {
  const SessionChecker({super.key});

  @override
  State<SessionChecker> createState() => _SessionCheckerState();
}

class _SessionCheckerState extends State<SessionChecker> {
  bool _loading = true;
  String? _username;
  String? _userType;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    await authProvider.loadUser();
    setState(() {
      _username = authProvider.username;
      _userType = authProvider.userType;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // التحقق من وجود المستخدم ونوع المستخدم
    if (_username != null && _userType != null) {
      // توجيه المستخدمين حسب نوع المستخدم
      switch (_userType) {
        case 'محاسب': // المحاسب
          return FinancialOperationsPage();
        case 'مدير': // المدير العام
          return NewProfessionalDashboardScreen();
        case 'مسوق': // المسوق
          return ProjectsDashboardScreen();
        case 'مدير1': // المدير الفرعي
        case 'مستر': // المستر
        default:
          return EpicMasterDashboard(username: _username!);
      }
    } else {
      return LoginScreen1(); // غير مسجل الدخول
    }
  }
}
