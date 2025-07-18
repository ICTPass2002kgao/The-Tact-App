import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Pages/Admin_Portal.dart';
import 'package:ttact/Pages/CartPage.dart';
import 'package:ttact/Pages/Login.dart';
import 'package:ttact/Pages/MotherPage.dart';
import 'package:ttact/Pages/OverseerPage.dart'; 
import 'package:ttact/Pages/SignUpPage.dart'; // Corrected import from Tact_Seller
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/Pages/orders.dart'; // Corrected import for the actual OrdersPage
import 'package:ttact/firebase_options.dart';
import 'package:ttact/introductionPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      // Light Theme (your existing theme)
      theme: ThemeData(
        brightness: Brightness.light, // Explicitly set for clarity
        appBarTheme: AppBarTheme(
          backgroundColor: const Color.fromARGB(255, 7, 2, 80),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 16.0),
        ),
        primaryColor: const Color.fromARGB(252, 5, 2, 80),
        scaffoldBackgroundColor: const Color.fromRGBO(255, 255, 255, 1),
        hintColor: const Color.fromARGB(255, 103, 103, 103),
        splashColor: const Color.fromARGB(255, 33, 98, 35),
        primaryColorDark: const Color.fromARGB(255, 194, 50, 40),
        // Define other light theme properties
      ),
      // Dark Theme (NEW)
      darkTheme: ThemeData(
        brightness: Brightness.dark, // Explicitly set for clarity
        appBarTheme: AppBarTheme(
          backgroundColor: Color.fromRGBO(255, 255, 255, 1), // Darker AppBar
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
        primaryColor: Color.fromRGBO(255, 255, 255, 1), // Darker primary
        scaffoldBackgroundColor: const Color.fromARGB(
          255,
          100,
          111,
          129,
        ).withOpacity(1), // Dark background
        hintColor: const Color.fromARGB(255, 170, 170, 170),
        splashColor: const Color.fromARGB(255, 60, 130, 62),
        primaryColorDark: const Color.fromARGB(
          255,
          255,
          90,
          80,
        ), // Accent for dark mode errors
        // Define other dark theme properties
        cardColor: const Color.fromARGB(255, 45, 45, 45), // Dark card color
        dialogBackgroundColor: const Color.fromARGB(
          255,
          55,
          55,
          55,
        ), // Dark dialog background
        // Add more specific colors for dark mode to match your design
      ),
      themeMode: _themeMode, // Use the state variable to control the theme
      initialRoute: '/',
      routes: {
        '/tact_seller': (context) => SellerProductPage(),
        '/main-menu': (context) =>
            MotherPage(onToggleTheme: toggleTheme), // Pass the callback
        '/signup': (context) => SignUpPage(),
        '/cart': (context) => CartPage(),
        '/orders': (context) =>
            OrdersPage(), // Corrected this route to point to OrdersPage
        '/admin': (context) => AdminPortal(),
        '/login': (context) => Login_Page(),
        '/overseer': (context) => OverseerPage(),
        '/': (context) => Introductionpage(),
      },
    );
  }
}
