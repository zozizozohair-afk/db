import 'package:flutter/material.dart';
import 'package:msakinal/priovider/auth_provider.dart';
import 'package:provider/provider.dart'; // ✅ أضفناها لدعم Provider
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ كلاس مزوّد الحالة
import 'SessionChecker.dart';
import 'firebase_options.dart';
import 'services/free_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // تهيئة معالج الرسائل في الخلفية
  FirebaseMessaging.onBackgroundMessage(freeFirebaseMessagingBackgroundHandler);
  
  // تهيئة خدمة الإشعارات المجانية
  await FreeNotificationService.initialize();

  // تهيئة Supabase
  await Supabase.initialize(
    url: 'https://rfcquyapkcldedbzoatg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJmY3F1eWFwa2NsZGVkYnpvYXRnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYwOTM5NjMsImV4cCI6MjA2MTY2OTk2M30.mosX1qF8cDUHF7O4XXdACpYwd_TckA53q_vH7Fwy4TE',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppAuthProvider(),
        ), // ✅ موفّر حالة المصادقة
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        home: SessionChecker(), // ✅ الصفحة الرئيسية كما هي
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'tg',
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontFamily: 'su',
              fontSize: 32.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
            displayMedium: TextStyle(
              fontFamily: 'su',
              fontSize: 28.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
            displaySmall: TextStyle(
              fontFamily: 'su',
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
            headlineMedium: TextStyle(
              fontFamily: 'su',
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
            headlineSmall: TextStyle(
              fontFamily: 'su',
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
            titleLarge: TextStyle(
              fontFamily: 'su',
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.3,
            ),
            bodyLarge: TextStyle(
              fontFamily: 'su',
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
              height: 1.5,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'su',
              fontSize: 14.0,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
              height: 1.5,
            ),
            bodySmall: TextStyle(
              fontFamily: 'su',
              fontSize: 12.0,
              fontWeight: FontWeight.normal,
              color: Colors.black54,
              height: 1.5,
            ),
            labelLarge: TextStyle(
              fontFamily: 'su',
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
