import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ttact/Components/AdBanner.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
  }

  // Huawei device detection
  Future<bool> isHuaweiDevice() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    return androidInfo.manufacturer.toLowerCase().contains("huawei");
  }

  // Refactored signInWithGoogle function
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      if (await isHuaweiDevice()) {
        final user = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoogleWebViewSignIn(
              clientId:
                  "219784074240-sibqjr68odge1lpcdmn239brfosbefk6.apps.googleusercontent.com",
              redirectUri: "https://tact-3c612.firebaseapp.com/__/auth/handler",
            ),
          ),
        );
        if (user == null) return;
      } else {
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

        await _auth.signInWithCredential(credential);
      }

      // This logic is now outside the if-else block
      final user = FirebaseAuth.instance.currentUser;
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
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      print(e);
      if (!context.mounted) return;
      Api().showMessage(
        context,
        'An unexpected error occurred: ${e.toString()}',
        'Error',
        Theme.of(context).colorScheme.primary, // Use a themed color
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: Platform.isIOS
          ? CupertinoNavigationBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              border: Border.all(color: Colors.transparent),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isMobile ? buildMobileLayout() : buildWebLayout(),
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
            "assets/dankie_logo.PNG",
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
        const SizedBox(height: 70),
        ClipRRect(
          child: Image.asset(
            "assets/dankie_logo.PNG",
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
        AdManager().bannerAdWidget(),
        Padding(padding: const EdgeInsets.all(16.0), child: buildFormContent()),
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
            if (Platform.isIOS)
              CupertinoTextField(
                controller: txtPassword,
                placeholder: 'Password',
                obscureText: _obscureText,
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(17.0),
                ),
                padding: const EdgeInsets.all(12.0),
                suffixMode: OverlayVisibilityMode.editing,
                suffix: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                  child: Icon(
                    _obscureText
                        ? CupertinoIcons.eye_slash_fill
                        : CupertinoIcons.eye_fill,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              )
            else
              TextFormField(
                controller: txtPassword,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.cardColor),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  fillColor: colorScheme.scaffoldBackgroundColor,
                  filled: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      color: colorScheme.cardColor,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                  hintText: 'Password',
                  hintStyle: TextStyle(color: colorScheme.cardColor),
                ),
                obscureText: _obscureText,
              ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPassword(),
                  ),
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
                    if (_formKey.currentState?.validate() ?? false) {
                      Api().showLoading(context);
                      try {
                        final userCredential = await FirebaseAuth.instance
                            .signInWithEmailAndPassword(
                              email: txtEmail.text.trim(),
                              password: txtPassword.text.trim(),
                            );

                        var uid = userCredential.user!.uid;

                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .get();

                        final Map<String, dynamic>? userData = userDoc.data();

                        final tactsoBranchesQuery = await FirebaseFirestore
                            .instance
                            .collection('tactso_branches')
                            .where('uid', isEqualTo: uid)
                            .get();

                        if (tactsoBranchesQuery.docs.isNotEmpty) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                            context,
                            "/tactso-branches",
                          );
                          return;
                        }

                        final overseerQuery = await FirebaseFirestore.instance
                            .collection('overseers')
                            .where('email', isEqualTo: txtEmail.text)
                            .get();

                        if (overseerQuery.docs.isNotEmpty) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, "/overseer");
                          return;
                        }

                        final String role = userData?['role'] ?? '';

                        if (role == 'Admin') {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, "/admin");
                        } else if (role == 'Member' || role == 'Seller') {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(context, "/main-menu");
                        } else {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          Api().showMessage(
                            context,
                            'Unknown role or no specific access found for this user: $role',
                            'Error',
                            colorScheme.primaryColorDark,
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        String errorMessage;
                        if (e.code == 'user-not-found') {
                          errorMessage = 'No user found for that email.';
                        } else if (e.code == 'wrong-password') {
                          errorMessage =
                              'Wrong password provided for that user.';
                        } else if (e.code == 'invalid-email') {
                          errorMessage = 'The email address is not valid.';
                        } else {
                          errorMessage =
                              'Login failed: ${e.message ?? 'An unknown authentication error occurred.'}';
                        }
                        Api().showMessage(
                          context,
                          errorMessage,
                          'Authentication Error',
                          colorScheme.primaryColorDark,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        Api().showMessage(
                          context,
                          'An unexpected error occurred during login: ${e.toString()}',
                          'Error',
                          colorScheme.primaryColorDark,
                        );
                      }
                    }
                  },
                  minWidth: isMobile ? double.infinity : 300,
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                  style: TextStyle(color: colorScheme.cardColor),
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
            const SizedBox(height: 20),
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

// WebView Widget for Huawei Google Sign-In
class GoogleWebViewSignIn extends StatefulWidget {
  final String clientId;
  final String redirectUri;

  const GoogleWebViewSignIn({
    super.key,
    required this.clientId,
    required this.redirectUri,
  });

  @override
  State<GoogleWebViewSignIn> createState() => _GoogleWebViewSignInState();
}

class _GoogleWebViewSignInState extends State<GoogleWebViewSignIn> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final authUrl =
        "https://accounts.google.com/o/oauth2/v2/auth"
        "?response_type=token%20id_token"
        "&client_id=${widget.clientId}"
        "&redirect_uri=${Uri.encodeComponent(widget.redirectUri)}"
        "&scope=email%20profile%20openid";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (url.startsWith(widget.redirectUri)) {
              final fragment = Uri.parse(url).fragment;
              final params = Uri.splitQueryString(fragment);

              final idToken = params["id_token"];
              final accessToken = params["access_token"];

              if (idToken != null) {
                _signInToFirebase(idToken, accessToken);
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  Future<void> _signInToFirebase(String idToken, String? accessToken) async {
    try {
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) Navigator.pop(context, FirebaseAuth.instance.currentUser);
    } catch (e) {
      debugPrint("Firebase Sign-In error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Google Sign-In")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
