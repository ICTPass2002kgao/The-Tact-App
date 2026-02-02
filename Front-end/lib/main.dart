// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart'; // Added for iOS support
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/NotificationService.dart';
import 'package:ttact/Pages/InitialRoadWrapper.dart';
import 'package:ttact/Pages/Overseer/Overseer_Page.dart';
import 'package:ttact/Pages/tactso_pages/Tactso_Branches_Applications.dart';
import 'package:ttact/Pages/tactso_pages/tactso_main_page.dart';
import 'package:ttact/firebase_options.dart';

import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Audio_Handler.dart';
import 'package:ttact/Pages/Admin/Admin_Portal.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/CartPage.dart';
import 'package:ttact/Pages/Auth/Login.dart';
import 'package:ttact/Pages/User/MotherPage.dart';
import 'package:ttact/Pages/Auth/SignUpPage.dart';
import 'package:ttact/Pages/User/Seller/Tact_Seller.dart';
// import 'package:ttact/Pages/User/Tactso_Branches_Applications.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/orders.dart';
import 'package:ttact/introductionPage.dart';

MyAudioHandler? audioHandler;

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      try {
        await NotificationService.init();
        await NotificationService.scheduleDailyVerses();
      } catch (e) {
        print("⚠️ Notification Error: $e");
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // --- NEW: INITIALIZE AUDIO SESSION FOR IOS ---
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        print('✅ Audio Session configured for iOS');
      } catch (e) {
        print('⚠️ Audio Session configuration failed: $e');
      }

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      if (!kIsWeb) {
        try {
          await MobileAds.instance.initialize();
          await AdManager.initialize();
        } catch (e) {
          print('MobileAds initialization failed: $e');
        }
      }

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
        FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'AudioService init failed',
        );
        debugPrint('⚠️ Audio Service init failed: $e');
      }

      runApp(const MyApp());
    },
    (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoadingTheme = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      _isLoadingTheme = false;
    });
  }

  void toggleTheme(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTheme) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        cardColor: Colors.black,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Color.fromARGB(255, 255, 255, 255),
        ),
        hintColor: const Color.fromARGB(255, 185, 182, 182),
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        splashColor: const Color.fromARGB(255, 33, 98, 35),
        primaryColorDark: const Color.fromARGB(255, 170, 42, 33),
        primaryColorLight: Colors.purple,
      ),
      darkTheme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
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
        '/tactso-branches': (context) =>  TactsoBranchesApplications(),
        '/introduction': (context) => Introductionpage(
          onGetStarted: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('hasSeenIntro', true);
          },
        ),
      },
    );
  }
}
