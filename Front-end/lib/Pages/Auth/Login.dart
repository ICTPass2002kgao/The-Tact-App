// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'dart:convert'; // Added for JSON
import 'package:http/http.dart' as http; // Added for Django
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:text_field_validation/text_field_validation.dart';

import 'package:ttact/Pages/Auth/FaceVerificationPage.dart';
import 'package:ttact/Pages/Auth/ForgotPassword.dart';
import 'package:ttact/Pages/User/SongsUpdate.dart';
import '../../Components/API.dart';
import '../../Components/NeuDesign.dart';
import 'SignUpPage.dart';
import 'package:ttact/Components/web_ad_widget.dart';
import 'package:ttact/Components/AdBanner.dart';

// --- PLATFORM UTILITIES ---
bool get isMobileNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

// --- ⭐️ NEUMORPHIC TEXT FIELD WRAPPER ---
Widget _buildNeumorphicTextField({
  required TextEditingController controller,
  required String placeholder,
  required Color baseColor,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  Widget? suffixIcon,
  String? Function(String?)? validator,
  required BuildContext context,
}) {
  final theme = Theme.of(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      NeumorphicContainer(
        isPressed: true,
        color: baseColor,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: isIOSPlatform
            ? CupertinoTextField(
                controller: controller,
                placeholder: placeholder,
                placeholderStyle: TextStyle(
                  color: theme.hintColor.withOpacity(0.9),
                ),
                style: TextStyle(),
                keyboardType: keyboardType,
                obscureText: obscureText,
                decoration: null,
                padding: const EdgeInsets.all(16.0),
                prefix: prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(prefixIcon, color: theme.primaryColor),
                      )
                    : null,
                suffix: suffixIcon,
              )
            : TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
                  prefixIcon: prefixIcon != null
                      ? Icon(prefixIcon, color: theme.primaryColor)
                      : null,
                  suffixIcon: suffixIcon,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0,
                    horizontal: 10.0,
                  ),
                ),
                validator: validator,
              ),
      ),
      if (validator != null) SizedBox(height: 5),
    ],
  );
}

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

  late AnimationController _logoAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    );

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

  // --- UPDATED DJANGO AUTH LOGIC (With Strict Role Checking) ---
  Future<void> _handleEmailPasswordLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    isIOSPlatform ? Api().showIosLoading(context) : Api().showLoading(context);

    try {
      // 1. FIREBASE AUTH (The Guard)
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: txtEmail.text.trim(),
            password: txtPassword.text.trim(),
          );

      var user = userCredential.user;
      if (user == null) throw Exception("User is null");

      var uid = user.uid;
      // In Django, we typically use the email as the lookup key for authentication consistency
      var email = user.email ?? txtEmail.text.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', uid);

      print("🔍 Searching for user profile in Django...");

      // 2. CHECK OVERSEER (Priority 1)
      // Use 'email' lookup if 'uid' isn't reliable in your Overseer model, or use 'uid' if you added it.
      // Based on your previous models.py, Overseer has 'email' but not 'uid'.
      // So we search by EMAIL for Overseers.
      var overseerProfile = await _fetchProfileFromDjango(
        'overseers',
        email,
        isEmailLookup: true,
      );

      if (overseerProfile != null) {
        print("✅ Found Overseer Profile!");

        // Determine which face to use (Chairperson or Secretary)
        // You might want to ask the user "Who are you?" or just default to one.
        // For now, let's pick the one that has a URL.
        String faceUrl = overseerProfile['chairperson_face_url'] ?? '';
        String roleName = 'Chairperson';

        if (faceUrl.isEmpty) {
          faceUrl = overseerProfile['secretary_face_url'] ?? '';
          roleName = 'Secretary';
        }

        _launchFaceVerification(
          context,
          uid,
          role: 'Overseer', // Hardcoded role for routing
          faceUrl: faceUrl,
          name: overseerProfile['overseer_initials_surname'] ?? 'Overseer',
          portfolio: roleName,
        );
        return;
      }

      // 3. CHECK STAFF/ADMIN (Priority 2)
      var staffProfile = await _fetchProfileFromDjango('staff', uid);
      if (staffProfile != null) {
        print("✅ Found Staff Profile!");
        _launchFaceVerification(
          context,
          uid,
          role: 'Admin', // Hardcoded for routing
          faceUrl: staffProfile['face_url'] ?? '',
          name: staffProfile['full_name'] ?? 'Admin',
          portfolio: staffProfile['role'] ?? 'Staff',
        );
        return;
      }

      // 4. CHECK TACTSO BRANCH (Priority 3)
      var tactsoProfile = await _fetchProfileFromDjango('tactso_branches', uid);
      if (tactsoProfile != null) {
        print("✅ Found Tactso Branch Profile!");

        // Tactso branches often use a generic authorized user face
        // We need to parse the JSON list of faces if it's stored that way
        String faceUrl = '';
        if (tactsoProfile['education_officer_face_url'] != null &&
            tactsoProfile['education_officer_face_url'].toString().isNotEmpty) {
          faceUrl = tactsoProfile['education_officer_face_url'];
        }

        _launchFaceVerification(
          context,
          uid,
          role: 'Tactso Branch', // Hardcoded for routing
          faceUrl: faceUrl,
          name: tactsoProfile['university_name'] ?? 'Branch',
          portfolio: 'Education Officer',
        );
        return;
      }

      // 5. STANDARD USER (Priority 4)
      var userProfile = await _fetchProfileFromDjango('users', uid);
      if (userProfile != null) {
        print("✅ Found Standard User Profile!");
        if (!context.mounted) return;
        Navigator.pop(context); // Close loading
        Navigator.pushReplacementNamed(context, "/main-menu");
        return;
      }

      // If we reach here, user exists in Firebase but not in Django
      throw Exception("Profile not found in database system.");
    } on FirebaseAuthException catch (e) {
      if (context.mounted) Navigator.pop(context);
      Api().showMessage(
        context,
        e.message ?? 'Auth Error',
        'Error',
        Colors.red,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      Api().showMessage(context, 'Login Error: $e', 'Error', Colors.red);
    }
  }

  // --- HELPER: QUERY DJANGO ---
  Future<Map<String, dynamic>?> _fetchProfileFromDjango(
    String endpoint,
    String identifier, {
    bool isEmailLookup = false,
  }) async {
    try {
      // Construct URL: /api/overseers/?email=... OR /api/users/?uid=...
      String queryParam = isEmailLookup ? 'email' : 'uid';
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/$endpoint/?$queryParam=$identifier',
      );

      print("Querying: $url");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          // Return the first match found
          return results[0] as Map<String, dynamic>;
        }
      } else {
        print("Django Error ($endpoint): ${response.statusCode}");
      }
    } catch (e) {
      print("Network Error ($endpoint): $e");
    }
    return null;
  }

  Future<void> _launchFaceVerification(
    BuildContext context,
    String uid, {
    required String role,
    String? faceUrl,
    String? name,
    String? portfolio,
  }) async {
    if (context.mounted) Navigator.pop(context); // Close Loading

    if (faceUrl == null || faceUrl.isEmpty) {
      if (context.mounted) {
        Api().showMessage(
          context,
          'No registered face found for this account.',
          'Access Denied',
          Colors.red,
        );
      }
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (context.mounted)
        Api().showMessage(context, 'No camera found.', 'Error', Colors.red);
      return;
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FaceVerificationScreen(
            email: txtEmail.text.trim(),
            password: txtPassword.text.trim(),
            camera: cameras.first,
            entityUid: uid,
            role: role,
            faceUrl: faceUrl,
            loggedMemberName: name,
            loggedMemberRole: portfolio,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Your UI Build method remains exactly the same)
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    final size = MediaQuery.of(context).size;
    final bool showAd = isAndroidPlatform && isIOSPlatform && !kIsWeb;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(0.3),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: NeumorphicContainer(
                        color: neumoBaseColor,
                        borderRadius: 100,
                        padding: const EdgeInsets.all(20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(90),
                          child: Image.asset(
                            "assets/dankie_logo.PNG",
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 40),

                    NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 20,
                      padding: const EdgeInsets.all(25),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: theme.primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Sign in to continue",
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.primaryColor?.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: 30),

                            _buildNeumorphicTextField(
                              context: context,
                              baseColor: neumoBaseColor,
                              controller: txtEmail,
                              placeholder: "Email Address",
                              prefixIcon: isIOSPlatform
                                  ? CupertinoIcons.mail_solid
                                  : Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) =>
                                  TextFieldValidation.email(value!),
                            ),

                            SizedBox(height: 20),

                            _buildNeumorphicTextField(
                              context: context,
                              baseColor: neumoBaseColor,
                              controller: txtPassword,
                              placeholder: "Password",
                              prefixIcon: isIOSPlatform
                                  ? CupertinoIcons.lock_fill
                                  : Icons.lock,
                              obscureText: _obscureText,
                              suffixIcon: GestureDetector(
                                onTap: () => setState(
                                  () => _obscureText = !_obscureText,
                                ),
                                child: Icon(
                                  _obscureText
                                      ? (isIOSPlatform
                                            ? CupertinoIcons.eye_slash_fill
                                            : Icons.visibility_off)
                                      : (isIOSPlatform
                                            ? CupertinoIcons.eye_fill
                                            : Icons.visibility),
                                  color: theme.primaryColor.withOpacity(0.5),
                                ),
                              ),
                            ),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPassword(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 10),

                            GestureDetector(
                              onTap:
                                  _handleEmailPasswordLogin, // Calls new Django logic
                              child: NeumorphicContainer(
                                color: theme.primaryColor,
                                borderRadius: 10,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 15),

                            GestureDetector(
                              onTap: () async {
                                try {
                                  await FirebaseAuth.instance.signOut();
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.remove('authToken');
                                  if (!context.mounted) return;
                                  Navigator.pushNamed(context, '/main-menu');
                                } catch (e) {}
                              },
                              child: NeumorphicContainer(
                                color: neumoBaseColor,
                                borderRadius: 10,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    "Proceed without login",
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: theme.hintColor),
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
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (showAd)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: AdManager().bannerAdWidget(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
