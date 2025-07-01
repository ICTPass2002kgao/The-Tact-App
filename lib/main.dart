import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/firebase_options.dart';
import 'package:ttact/introductionPage.dart';

void main()async {
  WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options:DefaultFirebaseOptions.currentPlatform);
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
         primaryColor: const Color.fromARGB(255, 7, 2, 80),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        hintColor: const Color(0xFFBDBDBD),
      
      ),
      home: Introductionpage(),
    );
  }
}
