// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ttact/Pages/FaceVerificationPage.dart';
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
import 'package:camera/camera.dart';

class Login_Page extends StatefulWidget {
  const Login_Page({super.key});

  @override
  State<Login_Page> createState() => _Login_PageState();
}

class _Login_PageState extends State<Login_Page>
    with SingleTickerProviderStateMixin {
  final TextEditingController txtEmail = TextEditingController();
  final TextEditingController txtPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ANIMATION
  late AnimationController _logoAnimationController;
  late Animation<Offset> _logoOffsetAnimation;
  late Animation<double> _logoOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _logoOffsetAnimation =
        Tween<Offset>(begin: Offset(0, -0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _logoAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeIn),
    );

    _logoAnimationController.forward();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    txtEmail.dispose();
    txtPassword.dispose();
    super.dispose();
  }

  Future<bool> isHuaweiDevice() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    return androidInfo.manufacturer.toLowerCase().contains("huawei");
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    if (!context.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (await isHuaweiDevice()) {
        final user = await Navigator.of(context).push<dynamic>(
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

        final dynamic googleUser = await (_googleSignIn as dynamic).signIn();
        if (googleUser == null) {
          debugPrint("Google Sign-In was cancelled by the user.");
          return;
        }

        final dynamic googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken ?? googleAuth.id_token;
        final credential = GoogleAuthProvider.credential(idToken: idToken);

        await _auth.signInWithCredential(credential);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("Authentication succeeded but currentUser is null.");
        return;
      }

      final uid = user.uid;
      final email = user.email;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!context.mounted) return;

      if (userDoc.exists) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil("/main-menu", (route) => false);
      } else {
        Navigator.of(context).pushNamed("/signup", arguments: {'email': email});
      }
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // NEW: Email/Password Login Handler with Face Verification Step
  // NEW: Email/Password Login Handler with Face Verification Step
  Future<void> _handleEmailPasswordLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Api().showLoading(context);
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: txtEmail.text.trim(),
            password: txtPassword.text.trim(),
          );

      var user = userCredential.user;
      if (user == null) {
        if (!context.mounted) return;
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Login failed: User object is null.',
          'Error',
          Theme.of(context).primaryColorDark,
        );
        return;
      }

      var uid = user.uid;

      // 🚀 REVENUECAT IMPLEMENTATION: Set the App User ID here
      await Purchases.logIn(uid);
      // --------------------------------------------------------

      final tactsoBranchesQuery = await FirebaseFirestore.instance
          .collection('tactso_branches')
          .where('uid', isEqualTo: uid)
          .get();

      // 1. TACTSO Branch Admin Login (Requires Biometric Verification)
      if (tactsoBranchesQuery.docs.isNotEmpty) {
        final branchDoc = tactsoBranchesQuery.docs.first;
        final faceUrls =
            branchDoc.data()['authorizedUserFaceUrls'] as List<dynamic>? ?? [];

        if (!context.mounted) return;
        Navigator.pop(context); // Dismiss loading dialog

        // Obtain available cameras and pick the first one to pass into FaceVerificationScreen
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          if (!context.mounted) return;
          // Navigator.pop(context); // Already dismissed if userCredential wasn't null
          Api().showMessage(
            context,
            'No camera found on this device.',
            'Error',
            Theme.of(context).primaryColorDark,
          );
          return;
        }
        final CameraDescription camera = cameras.first;

        if (!context.mounted) return;
        // Navigator.pop(context); // Already dismissed if userCredential wasn't null

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FaceVerificationScreen(
              camera: camera,
              authorizedFaceUrls: faceUrls.cast<String>(),
              universityUID: uid,
            ),
          ),
        );

        return;
      }

      // 2. Other Roles (Standard Login)
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

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final Map<String, dynamic>? userData = userDoc.data();
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
          Theme.of(context).primaryColorDark,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided for that user.';
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
        Theme.of(context).primaryColorDark,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      Api().showMessage(
        context,
        'An unexpected error occurred during login: ${e.toString()}',
        'Error',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,

      appBar: Platform.isIOS
          ? CupertinoNavigationBar(
              backgroundColor: Colors.transparent,
              border: Border.all(color: Colors.transparent),
              automaticallyImplyLeading: false,
            )
          : null,

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).primaryColor.withOpacity(0.15),
            ],
          ),
        ),

        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isMobile
                    ? buildMobileLayout()
                    : SingleChildScrollView(child: buildWebLayout()),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Image.asset(
                "assets/dankie_logo.PNG",
                height: 500,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 40),
        Expanded(
          flex: 3,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: buildFormContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMobileLayout() {
    final color = Theme.of(context);
    return Column(
      children: [
        SlideTransition(
          position: _logoOffsetAnimation,
          child: FadeTransition(
            opacity: _logoOpacityAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                "assets/dankie_logo.PNG",
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        if (Platform.isAndroid) AdManager().bannerAdWidget(),

        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Card(
                color: color.primaryColor.withOpacity(0.4),
                elevation: 20,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: buildFormContent(),
                ),
              ),
            ),
          ),
        ),
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
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 1 : 0),
        child: Container(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.scaffoldBackgroundColor,
                ),
              ),
              Text(
                "Sign in to access your DANKIE Ministry account.",
                style: TextStyle(fontSize: 16, color: colorScheme.hintColor),
              ),
              const SizedBox(height: 10),

              // Email Field
              AuthTextField(
                placeholder: 'Email Address',
                controller: txtEmail,
                onValidate: (value) => TextFieldValidation.email(value!),
              ),

              // Password Field
              if (Platform.isIOS)
                CupertinoTextField(
                  controller: txtPassword,
                  placeholder: 'Password',
                  obscureText: _obscureText,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: const EdgeInsets.all(12.0),

                  suffixMode: OverlayVisibilityMode.editing,
                  suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
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
                  style: TextStyle(color: colorScheme.scaffoldBackgroundColor),
                  controller: txtPassword,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    fillColor: colorScheme.hintColor.withOpacity(0.2),
                    filled: true,
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: colorScheme.primaryColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: colorScheme.primaryColor,
                      ),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    ),
                    hintText: 'Password',
                    hintStyle: TextStyle(
                      color: colorScheme.scaffoldBackgroundColor,
                    ),
                  ),
                  obscureText: _obscureText,
                ),

              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPassword(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 5.0),
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: colorScheme.scaffoldBackgroundColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Login Button (NOW CALLS THE NEW HANDLER)
              Custom_Button(
                text: "Login",
                backgroundColor: colorScheme.primaryColor,
                foregroundColor: Colors.white,
                onPressed: _handleEmailPasswordLogin, // <--- UPDATED
                minWidth: double.infinity,
              ),

              const SizedBox(height: 10),

              // Proceed without Login Button
              CustomOutlinedButton(
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
                width: double.infinity,
              ),

              const SizedBox(height: 20),

              // Divider for Social Login
              Row(
                children: [
                  const Expanded(
                    child: Divider(color: Colors.grey, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Text("OR", style: TextStyle(color: Colors.grey)),
                  ),
                  const Expanded(
                    child: Divider(color: Colors.grey, thickness: 1),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Google Sign-In Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await signInWithGoogle(context);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(39),
                      child: Image.asset(
                        "assets/google.jpeg",
                        height: 55,
                        width: 55,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Register Link
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
                      MaterialPageRoute(
                        builder: (context) => const SignUpPage(),
                      ),
                    ),
                    child: Text(
                      "Register Now",
                      style: TextStyle(
                        color: colorScheme.scaffoldBackgroundColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// WebView Widget for Huawei Google Sign-In (Unchanged)
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
