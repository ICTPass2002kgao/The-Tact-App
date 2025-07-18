import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/ForgotPassword.dart';
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

  Future<void> login(String email, String password) async {
    Api().showLoading(context);
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;

      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final overseers = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (!context.mounted) return;
      if (overseers.docs.isNotEmpty) {
        Navigator.pushNamed(context, "/overseer");
      }

      if (userDoc.exists) {
        final role = userDoc.data()?['role'] ?? '';
        if (role == 'Admin') {
          Navigator.pushNamed(context, "/admin");
        } else if (role == 'Member') {
          Navigator.pushNamed(context, "/main-menu");
        } else {
          Navigator.pop(context);
          await _auth.signOut();
          Api().showMessage(
            context,
            'Unknown role: $role',
            'Error',
            Theme.of(context).primaryColorDark,
          );
        }
      }
    } catch (e) {
      Api().showMessage(
        context,
        'Login failed: ${e.toString()}',
        'Error',
        Theme.of(context).primaryColorDark,
      );
      await _auth.signOut();
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleSignInAccount = await _googleSignIn
          .signIn();
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

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

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
            height: 600,
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
        Card(
          elevation: 0,
          color: Colors.white,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.asset(
              "assets/tact_logo.PNG",
              height: 250,
              fit: BoxFit.cover,
            ),
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ForgotPassword()),
                );
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: colorScheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Card(
                color: Colors.transparent,
                elevation: 10,
                child: Custom_Button(
                  text: "Login",
                  backgroundColor: colorScheme.primaryColor,
                  foregroundColor: colorScheme.scaffoldBackgroundColor,
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        await login(txtEmail.text, txtPassword.text);
                        if (!context.mounted) return;
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
            ),
            SizedBox(height: 10),
            Center(
              child: Card(
                elevation: 5,
                color: Colors.transparent,
                child: CustomOutlinedButton(
                  text: "Proceed without login",
                  backgroundColor: colorScheme.scaffoldBackgroundColor,
                  foregroundColor: colorScheme.primaryColor,
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.pushNamed(context, '/main-menu');
                    } catch (e) {
                      Api().showMessage(
                        context,
                        'Something went wrong try again later $e',
                        '',
                        colorScheme.primaryColorDark,
                      );
                    }
                  },
                  width: isMobile ? double.infinity : 300,
                ),
              ),
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpPage()),
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
