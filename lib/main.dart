// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/AdBanner.dart'; 
// DELETE: The import for your custom handler class:
// import 'package:ttact/Components/Audio_Handler.dart';
// DELETE: The import for your custom service manager class:
// import 'package:ttact/Components/audio_service_manager.dart'; 
import 'package:ttact/Pages/Admin_Portal.dart';
import 'package:ttact/Pages/CartPage.dart';
import 'package:ttact/Pages/HomePage.dart';
import 'package:ttact/Pages/Login.dart';
import 'package:ttact/Pages/MotherPage.dart';
import 'package:ttact/Pages/OverseerPage.dart';
import 'package:ttact/Pages/SignUpPage.dart';
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/Pages/Tactso_Branches_Applications.dart';
import 'package:ttact/Pages/orders.dart';
import 'package:ttact/firebase_options.dart';
import 'package:ttact/introductionPage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:just_audio_background/just_audio_background.dart'; // <<< KEEP THIS IMPORT

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();
  await AdManager.initialize();
  
  // 🐛 FIX: Use JustAudioBackground.init() for single initialization
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.thetact.ttact.channel.audio',
      androidNotificationChannelName: 'TACT Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (e) {
    print('Failed to initialize audio service: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
// ... rest of MyApp class is unchanged ...
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
      theme: ThemeData(
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 16.0),
        ),
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        hintColor: Colors.black54,
        splashColor: const Color.fromARGB(255, 33, 98, 35),
        primaryColorDark: const Color.fromARGB(255, 194, 50, 40),
        cardColor: Colors.black,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(255, 255, 255, 1),
          foregroundColor: Color.fromARGB(252, 5, 2, 80),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          titleMedium: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
          bodyMedium: TextStyle(fontSize: 16.0, color: Colors.white70),
        ),
        primaryColor: const Color.fromRGBO(255, 255, 255, 1),
        scaffoldBackgroundColor: const Color.fromARGB(
          255,
          100,
          111,
          129,
        ).withOpacity(1),
        hintColor: const Color.fromARGB(255, 170, 170, 170),
        splashColor: const Color.fromARGB(255, 60, 130, 62),
        primaryColorDark: const Color.fromARGB(255, 255, 90, 80),
        cardColor: const Color.fromARGB(255, 45, 45, 45),
        dialogBackgroundColor: const Color.fromARGB(255, 55, 55, 55),
      ),
      themeMode: _themeMode,
      home: Introductionpage(),
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
      },
    );
  }
}