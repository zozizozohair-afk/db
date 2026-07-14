import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAuthProvider extends ChangeNotifier {
  String? _username;
  String? _email;
  String? _userType;
  int? _loginTime;

  String? get username => _username;
  String? get email => _email;
  String? get userType => _userType;
  int? get loginTime => _loginTime;

  // معرفة ما إذا كان المستخدم محاسب
  bool get isAccountant => _userType == 'محاسب';
  
  // معرفة ما إذا كان المستخدم مستر (المدير)
  bool get isMaster => _email == 'zizoalzohairy@gmail.com';

  Future<void> login(String name, {String? email, String? userType}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    if (email != null) {
      await prefs.setString('email', email);
    }
    if (userType != null) {
      await prefs.setString('userType', userType);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('loginTime', now);
    _username = name;
    _email = email;
    _userType = userType;
    _loginTime = now;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('userType');
    await prefs.remove('loginTime');
    _username = null;
    _email = null;
    _userType = null;
    _loginTime = null;
    notifyListeners();
  }

  Future<bool> isLoggedIn() async {
    await loadUser();
    return _username != null;
  }

  Future<void> loadUser({bool checkDuration = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('username');
      final storedEmail = prefs.getString('email');
      final storedUserType = prefs.getString('userType');
      final loginTimestamp = prefs.getInt('loginTime');

      if (storedName != null && loginTimestamp != null) {
        if (checkDuration) {
          final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
          final now = DateTime.now();
          final sessionDuration = now.difference(loginTime);

          // زيادة مدة الجلسة إلى 120 دقيقة بدلاً من 60 دقيقة
          if (sessionDuration.inMinutes > 200) {
            await logout();
            return;
          }
        }
        _username = storedName;
        _email = storedEmail;
        _userType = storedUserType;
        _loginTime = loginTimestamp;
      } else {
        await logout();
      }
    } catch (e) {
      await logout();
    }
    notifyListeners();
  }
}
