// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

// --- PLATFORM UTILITIES IMPORTS ---
// We use foundation for platform checks that work everywhere (including web).
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ttact/Pages/FaceVerificationPage.dart';
// Note: webview_flutter and device_info_plus imports kept, assuming necessary
// for non-web platforms, even though Google Sign-In code was removed.
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

// --- PLATFORM UTILITIES ---

// Checks if we are running on native mobile (Android or iOS), excluding web.
bool get isMobileNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

// Checks if we are running on native iOS, excluding web.
bool get isIOSPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

// Checks if we are running on native Android, excluding web.
bool get isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

// ---------------------------

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
  // REMOVED: final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

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

    // Only run animation on mobile/web to prevent distracting on desktop
    if (isMobileNative || kIsWeb) {
      _logoAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    txtEmail.dispose();
    txtPassword.dispose();
    super.dispose();
  }

  // REMOVED: isHuaweiDevice method and signInWithGoogle method.

  // Email/Password Login Handler with Face Verification Step
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
      // await Purchases.logIn(uid);
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
    // Define breakpoints for responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    const double webBreakpoint = 900.0;
    final bool isDesktop = screenWidth >= webBreakpoint;

    return Scaffold(
      backgroundColor: Colors.transparent,

      // Fix: Conditionally show AppBar only if not on desktop/web,
      // and use the correct platform check.
      appBar: isDesktop
          ? null // No AppBar on web/desktop to maximize space
          : (isIOSPlatform
                ? CupertinoNavigationBar(
                    backgroundColor: Colors.transparent,
                    border: Border.all(color: Colors.transparent),
                    automaticallyImplyLeading: false,
                  )
                : AppBar(
                    // Use a regular AppBar for Android/Desktop Native
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 0, // Hide the toolbar space
                  )),

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
              // Constrain the content width for large screens
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1400),
                // Use the dedicated Web Layout for large screens
                child: isDesktop ? buildWebLayout() : buildMobileLayout(),
              ),
            );
          },
        ),
      ),
    );
  }

  // ENHANCED: Web Layout for an appealing, centered, two-column look.
  Widget buildWebLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 1400 ? 1200 : screenWidth * 0.8;

    return Center(
      child: Container(
        width: contentWidth.toDouble(),
        height:
            MediaQuery.of(context).size.height *
            0.8, // Take 80% of screen height
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).cardColor, // Use card color for the main container
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Side: Image/Logo
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  bottomLeft: Radius.circular(25),
                ),
                child: Image.asset("assets/dankie_logo.PNG", fit: BoxFit.cover),
              ),
            ),

            // Right Side: Login Form
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: buildFormContent(isWeb: true),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mobile/Tablet Layout (Closer to original structure)
  Widget buildMobileLayout() {
    final color = Theme.of(context);
    // CORRECTED FIX: Used the safe isAndroidPlatform getter instead of Platform.isAndroid
    final bool showAd = isMobileNative && isAndroidPlatform;

    return Column(
      children: [
        SizedBox(height: 20),
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

        // Ad Banner (Conditional: Only show on native Android)
        if (showAd) AdManager().bannerAdWidget(),

        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                // Use a subtle color scheme for the card background
                color: color.primaryColor.withOpacity(0.4),
                elevation: 20,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: buildFormContent(isWeb: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFormContent({required bool isWeb}) {
    final colorScheme = Theme.of(context);

    // Determine text color based on platform.
    final textColor = isWeb
        ? colorScheme
              .scaffoldBackgroundColor // Dark color on light web background
        : Colors.white; // Light color on dark mobile card background

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Welcome Back",
            style: TextStyle(
              fontSize: isWeb ? 40 : 32, // Larger font on web
              fontWeight: FontWeight.w900,
              color:
                  colorScheme.primaryColor, // Use primary color for main title
            ),
          ),
          Text(
            "Sign in to access your DANKIE Ministry account.",
            style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.8)),
          ),
          const SizedBox(height: 30),

          // Email Field
          AuthTextField(
            placeholder: 'Email Address',
            controller: txtEmail,
            onValidate: (value) => TextFieldValidation.email(value!),
          ),

          const SizedBox(height: 15),

          // Password Field
          // FIXED: Uses the safe isIOSPlatform getter
          if (isIOSPlatform)
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
              // Style text input color to contrast with the field background
              style: TextStyle(color: colorScheme.scaffoldBackgroundColor),
              controller: txtPassword,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                // Use a light color for field fill for better visibility
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
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                hintText: 'Password',
                // Hint text color contrast fix
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
                    // Use the dynamic text color
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Login Button
          Custom_Button(
            text: "Login",
            backgroundColor: colorScheme.primaryColor,
            foregroundColor: Colors.white,
            onPressed: _handleEmailPasswordLogin,
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

          // Divider
          const Divider(color: Colors.grey, thickness: 1),

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
                  MaterialPageRoute(builder: (context) => const SignUpPage()),
                ),
                child: Text(
                  "Register Now",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// REMOVED: GoogleWebViewSignIn class.
