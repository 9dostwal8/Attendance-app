import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/attendance_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with fallback logging if configuration is missing/invalid
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('Firebase messaging background handler setup skipped: $e');
      }
    }
    debugPrint('Firebase initialized successfully.');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e. Running in offline/fallback mode.');
  }

  // Set system UI overlay style for transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  runApp(const MyApp());
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: Consumer<AttendanceProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            title: 'Time Attendance App',
            debugShowCheckedModeBanner: false,
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              fontFamily: provider.currentLanguage == 'ku' ? 'UniQaidar' : 'Inter',
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E65FF),
                brightness: Brightness.light,
                surface: const Color(0xFFF8FAFC),
                onSurface: const Color(0xFF1E293B),
                primary: const Color(0xFF2E65FF),
                onPrimary: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: Color(0xFF1E293B)),
                titleTextStyle: TextStyle(color: Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              iconTheme: const IconThemeData(color: Color(0xFF334155)),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFF1E293B)),
                bodyMedium: TextStyle(color: Color(0xFF334155)),
                titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
              cardTheme: const CardThemeData(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              ),
              dividerColor: const Color(0xFFE2E8F0),
            ),
            darkTheme: ThemeData(
              fontFamily: provider.currentLanguage == 'ku' ? 'UniQaidar' : 'Inter',
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF3b59ff),
                brightness: Brightness.dark,
                surface: const Color(0xFF1E293B),
                onSurface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              iconTheme: const IconThemeData(color: Colors.white70),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white70),
                titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              dividerColor: Colors.white.withValues(alpha: 0.1),
            ),
            home: provider.isLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
