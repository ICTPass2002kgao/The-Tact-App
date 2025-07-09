import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Pages/Admin_Portal.dart';
import 'package:ttact/Pages/CartPage.dart';
import 'package:ttact/Pages/Login.dart';
import 'package:ttact/Pages/MotherPage.dart';
import 'package:ttact/Pages/Payment.dart';
import 'package:ttact/Pages/SignUpPage.dart';
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/firebase_options.dart';
import 'package:ttact/introductionPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      ),
      //const Color.fromARGB(255, 7, 2, 80)
      initialRoute: '/',
      routes: {
        '/tact_seller': (context) => SellerProductPage(),
        '/main-menu': (context) => const MotherPage(),
        '/signup': (context) => SignUpPage(),
        '/cart': (context) => CartPage(),
        '/admin': (context) => AdminPortal(),
        '/login': (context) => Login_Page(),
        '/': (context) => Introductionpage(),
      },
    );
  }
}
