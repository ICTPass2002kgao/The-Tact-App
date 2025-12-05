// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/NotificationService.dart';
import 'package:ttact/Pages/InitialRoadWrapper.dart';
import 'package:ttact/firebase_options.dart';

import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Audio_Handler.dart';
import 'package:ttact/Pages/Admin_Portal.dart';
import 'package:ttact/Pages/CartPage.dart';
import 'package:ttact/Pages/Login.dart';
import 'package:ttact/Pages/MotherPage.dart';
import 'package:ttact/Pages/OverseerPage.dart';
import 'package:ttact/Pages/SignUpPage.dart';
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/Pages/Tactso_Branches_Applications.dart';
import 'package:ttact/Pages/orders.dart';
import 'package:ttact/introductionPage.dart';

MyAudioHandler? audioHandler;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.init();
    await NotificationService.scheduleDailyVerses();
  } catch (e) {
    print("⚠️ Notification Error: $e");
    // App will continue to run even if notifications fail
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Crashlytics collection in production
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Catch all uncaught asynchronous errors
  runZonedGuarded<Future<void>>(() async {
    if (!kIsWeb) {
      try {
        await MobileAds.instance.initialize();
        await AdManager.initialize();
      } catch (e) {
        print('MobileAds initialization failed: $e');
      }
    }

    // Initialize Audio Handler
    try {
      audioHandler = await AudioService.init(
        builder: () => MyAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.thetact.ttact.channel.audio',
          androidNotificationChannelName: 'TACT Music',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'drawable/ic_notification',
        ),
      );
      print('✅ Audio Handler initialized');
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'AudioService init failed');
      debugPrint('⚠️ Audio Service init failed: $e');
    }

    runApp(const MyApp());
  }, (error, stackTrace) {
    // Catch any other uncaught errors
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // --- UPDATED STATE ---
  ThemeMode _themeMode = ThemeMode.light; // This will be overwritten
  bool _isLoadingTheme = true; // Show loading screen while theme loads
  // --- END UPDATED STATE ---

  @override
  void initState() {
    super.initState();
    _loadTheme(); // Load the theme on app start
  }

  /// NEW: Load the saved theme preference from SharedPreferences
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Get the saved bool, or default to 'false' (light mode)
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      _isLoadingTheme = false; // Theme is loaded, stop loading
    });
  }

  // This is the callback function passed to MotherPage
  void toggleTheme(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
    // The saving logic is handled inside MotherPage's _handleThemeChange
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Add loading check
    if (_isLoadingTheme) {
      // Show a simple loading screen while the theme preference is read
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode, // This will now be the *loaded* theme
      theme: ThemeData(
        cardColor: Colors.black,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Color.fromARGB(255, 255, 255, 255),
        ),
        hintColor: const Color.fromARGB(255, 185, 182, 182),
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        splashColor: const Color.fromARGB(255, 33, 98, 35),
        primaryColorDark: const Color.fromARGB(255, 170, 42, 33),
        primaryColorLight: Colors.purple,
      ),
      darkTheme: ThemeData(
        cardColor: Colors.white,
        hintColor: const Color.fromARGB(255, 255, 255, 255),
        primaryColor: Colors.blue,
        brightness: Brightness.dark,
        splashColor: const Color.fromARGB(255, 33, 98, 35),
        primaryColorDark: const Color.fromARGB(255, 170, 42, 33),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color.fromARGB(255, 0, 0, 0),
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 4, 36, 77), 
      ),
      home: const InitialRouteWrapper(),
      routes: {
        '/tact_seller': (context) => SellerProductPage(),
        '/main-menu': (context) => MotherPage(onToggleTheme: toggleTheme),
        '/signup': (context) => SignUpPage(),
        '/cart': (context) => CartPage(),
        '/orders': (context) => OrdersPage(),
        '/admin': (context) => AdminPortal(),
        '/login': (context) => Login_Page(),
        '/overseer': (context) => OverseerPage(),
        '/tactso-branches': (context) => TactsoBranchesApplications(),
        '/introduction': (context) => Introductionpage(
          onGetStarted: () async {
            // This is a minimal implementation of the callback for named routes
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('hasSeenIntro', true);
          },
        ),
      },
    );
  }
}