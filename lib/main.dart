import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // ✅ Initialize Firebase and Ads first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    // Check if we are NOT on the web platform
    try {
      // NOTE: Google Mobile Ads is generally only for mobile platforms (iOS/Android).
      // We explicitly skip initialization on Web/Desktop to avoid MissingPluginException.
      await MobileAds.instance.initialize(); 
  await AdManager.initialize();
    } catch (e) {
      // Handle or ignore if initialization fails on unsupported platforms like Desktop/Linux
      print('MobileAds initialization skipped or failed on this platform: $e');
    }
  }
  
  
  // ✅ Initialize Audio Handler with better error handling
  try {
    audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.thetact.ttact.channel.audio',
        androidNotificationChannelName: 'TTact Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    ); 
  } catch (e, stackTrace) {
    debugPrint('⚠️ Failed to initialize audio service: $e');
    debugPrint('Stack trace: $stackTrace');
  } 
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        
        cardColor: Colors.black,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Color.fromARGB(255, 24, 24, 24),
        ),
        hintColor: const Color.fromARGB(255, 185, 182, 182),
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        splashColor: const Color.fromARGB(255, 33, 98, 35),
      ),
      darkTheme: ThemeData(
        cardColor: Colors.white,

        hintColor: const Color.fromARGB(255, 255, 255, 255),
        primaryColor: Colors.blue,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color.fromARGB(255, 0, 0, 0),
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 4, 36, 77),
        splashColor: const Color.fromARGB(255, 60, 130, 62),
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
        '/introduction': (context) => Introductionpage(onGetStarted: () async {
      // This is a minimal implementation of the callback for named routes
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenIntro', true);
  }),
      },
    );
  }
}
 