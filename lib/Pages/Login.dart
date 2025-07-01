import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/MotherPage.dart';
import '../Components/API.dart';
import '../Components/Custom_Buttons.dart';
import '../Components/TextField.dart';
import 'SignUpPage.dart';
import 'package:text_field_validation/text_field_validation.dart';

class Login_Page extends StatefulWidget {
  const Login_Page({super.key});

  @override
  State<Login_Page> createState() => _Login_PageState();
}

class _Login_PageState extends State<Login_Page> {
  final TextEditingController txtEmail = TextEditingController();
  final TextEditingController txtPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _checkAdminStatusAndNavigate(User user) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!context.mounted) return;

      if (userDoc.exists) {
        final isAdmin = userDoc.data()?['isAdmin'] ?? false;
        if (isAdmin) {
          Navigator.pushNamed(context, '/dashboard');
        } else {
          Navigator.pushNamed(context, '/main-menu');
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User data not found')));
        await _auth.signOut();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking admin status: ${e.toString()}')),
      );
      await _auth.signOut();
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;

  @override
  void initState() {
    super.initState();
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();
      if (googleSignInAccount == null) return;

      final googleAuth = await googleSignInAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) return;

      final uid = user.uid;
      final email = user.email;

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!context.mounted) return;

      if (userDoc.exists) {
        Navigator.pushNamed(context, "/main-menu");
      } else {
        Navigator.pushNamed(context, "/signup", arguments: {'email': email});
      }
    } catch (e, stackTrace) {
      print("Error signing in with Google: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isMobile ? buildMobileLayout() : buildWebLayout(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildWebLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Image.asset(
            "assets/tact_logo.PNG",
            height: 500,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 40),
        Expanded(flex: 3, child: buildFormContent()),
      ],
    );
  }

  Widget buildMobileLayout() {
    return Column(
      children: [
        SizedBox(height: 30),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: Image.asset(
            "assets/tact_logo.PNG",
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 30),
        buildFormContent(),
      ],
    );
  }

  Widget buildFormContent() {
    final colorScheme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      key: _formKey,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Login",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AuthTextField(
              placeholder: 'Email Address',
              controller: txtEmail,
              onValidate: (value) => TextFieldValidation.email(value!),
            ),
            TextField(
              controller: txtPassword,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.hintColor),
                  borderRadius: BorderRadius.circular(17),
                ),
                fillColor: colorScheme.scaffoldBackgroundColor,
                filled: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                    color: colorScheme.hintColor,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                hintText: 'Password',
                hintStyle: TextStyle(color: colorScheme.hintColor),
              ),
              obscureText: _obscureText,
            ),
            GestureDetector(
              onTap: () {},
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: colorScheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Custom_Button(
                text: "Login",
                backgroundColor: colorScheme.primaryColor,
                foregroundColor: colorScheme.scaffoldBackgroundColor,
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      await Api().login(
                        context,
                        txtEmail.text,
                        txtPassword.text,
                      );
                      final user = _auth.currentUser;
                      if (user != null) {
                        await _checkAdminStatusAndNavigate(user);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Login failed: ${e.toString()}'),
                        ),
                      );
                    }
                  }
                },
                minWidth: isMobile ? double.infinity : 300,
              ),
            ),
            SizedBox(height: 20),
            CustomOutlinedButton(
              text: "Proceed without login",
              backgroundColor: colorScheme.scaffoldBackgroundColor,
              foregroundColor: colorScheme.primaryColor,
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MotherPage()),
                );
              }, width:isMobile ? double.infinity : 300
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: TextStyle(color: colorScheme.hintColor),
                ),
                GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpPage(),
                        ),
                      ),
                  child: Text(
                    "Register Now",
                    style: TextStyle(
                      color: colorScheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    await signInWithGoogle(context);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: Image.asset(
                      "assets/google.jpeg",
                      height: 70,
                      width: 70,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
