import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Pages/Admin_Portal.dart';
import 'package:ttact/Pages/CartPage.dart';
import 'package:ttact/Pages/Login.dart';
import 'package:ttact/Pages/MotherPage.dart';
import 'package:ttact/Pages/OverseerPage.dart';
import 'package:ttact/Pages/SignUpPage.dart'; // Corrected import from Tact_Seller
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/Pages/Tactso_Branches_Applications.dart';
import 'package:ttact/Pages/orders.dart'; // Corrected import for the actual OrdersPage
import 'package:ttact/firebase_options.dart';
import 'package:ttact/introductionPage.dart';

// ✅ Added for AdMob
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

// Make MyApp Stateful to manage theme mode
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light; // Default theme mode

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
        appBarTheme: AppBarTheme(
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
      // Dark Theme (NEW)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: AppBarTheme(
          backgroundColor: Color.fromRGBO(255, 255, 255, 1),
          foregroundColor: const Color.fromARGB(252, 5, 2, 80),
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
        primaryColor: Color.fromRGBO(255, 255, 255, 1),
        scaffoldBackgroundColor: const Color.fromARGB(
          255,
          100,
          111,
          129,
        ).withOpacity(1), // Dark background
        hintColor: const Color.fromARGB(255, 170, 170, 170),
        splashColor: const Color.fromARGB(255, 60, 130, 62),
        primaryColorDark: const Color.fromARGB(255, 255, 90, 80),
        cardColor: const Color.fromARGB(255, 45, 45, 45),
        dialogBackgroundColor: const Color.fromARGB(255, 55, 55, 55),
      ),
      themeMode: _themeMode,
      initialRoute: '/',
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
        '/': (context) => Introductionpage(),
      },
    );
  }
}
