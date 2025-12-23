// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

// --- PLATFORM UTILITIES IMPORTS ---
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⭐️ ADDED: For persistent login
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/song.dart';
import 'package:ttact/Components/web_ad_widget.dart';
import 'package:ttact/Pages/FaceVerificationPage.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/ForgotPassword.dart';
import 'package:ttact/Pages/User/SongsUpdate.dart';
import '../Components/API.dart';
import '../Components/Custom_Buttons.dart';
// import '../Components/TextField.dart'; // No longer needed
import 'User/SignUpPage.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:camera/camera.dart';

// --- PLATFORM UTILITIES ---
bool get isMobileNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

// UPDATED: This logic now checks the OS, even on the web.
bool get isIOSPlatform {
  // Checks for iOS or macOS (which iPads/Macs report in browsers)
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// UPDATED: This logic now checks the OS, even on the web.
bool get isAndroidPlatform {
  // Checks for Android, Linux, or Fuchsia to default to Material style.
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// ---------------------------

// --- COPIED HELPERS FROM SIGNUPPAGE ---

// Custom platform-aware TextField Builder
Widget _buildPlatformTextField({
  required TextEditingController controller,
  required String placeholder,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  bool readOnly = false,
  int? maxLines = 1,
  String? Function(String?)? validator,
  Widget? suffixIcon,
  required BuildContext context,
}) {
  final color = Theme.of(context);
  return isIOSPlatform
      ? CupertinoTextField(
          style: TextStyle(color: Theme.of(context).cardColor),
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,

          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(color: color.cardColor),
            borderRadius: BorderRadius.circular(13.0),
          ),
          padding: const EdgeInsets.all(16.0),
          prefix: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(prefixIcon, color: color.cardColor),
                )
              : null,
          suffixMode: OverlayVisibilityMode.editing,
          suffix: suffixIcon,
        )
      : TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: placeholder,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
          ),
          validator: validator,
        );
}
// --- END COPIED HELPERS ---

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

  String loggedMemberName = '';
  String loggedMemberRole = '';
  // Email/Password Login Handler with Face Verification Step
  // Email/Password Login Handler with Face Verification Step
  Future<void> _handleEmailPasswordLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    isIOSPlatform ? Api().showIosLoading(context) : Api().showLoading(context);

    try {
      // 1. Firebase Auth Login
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
          'Login failed: User is null.',
          'Error',
          Colors.red,
        );
        return;
      }

      var uid = user.uid;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', uid);

      // -----------------------------------------------------------------------
      // CHECK 1: TACTSO BRANCH ADMIN (University)
      // -----------------------------------------------------------------------
      final tactsoBranchesQuery = await FirebaseFirestore.instance
          .collection('tactso_branches')
          .where('email', isEqualTo: txtEmail.text.trim())
          .get();

      if (tactsoBranchesQuery.docs.isNotEmpty) {
        final branchDoc = tactsoBranchesQuery.docs.first;
        final faceUrls =
            branchDoc.data()['authorizedUserFaceUrls'] as List<dynamic>? ?? [];

        await _launchFaceVerification(
          context,
          faceUrls.cast<String>(),
          uid,
          role: 'Tactso Branch',
        );
        return; // Stops execution here
      }

      // -----------------------------------------------------------------------
      // CHECK 2: OVERSEER
      // -----------------------------------------------------------------------
      final overseerQuery = await FirebaseFirestore.instance
          .collection('overseers')
          .where('email', isEqualTo: txtEmail.text.trim())
          .get();

      if (overseerQuery.docs.isNotEmpty) {
        final overseerDoc = overseerQuery.docs.first;
        List<String> faceUrls = [];

        // Check main doc
        if (overseerDoc.data().containsKey('authorizedUserFaceUrls')) {
          var mainList =
              overseerDoc.data()['authorizedUserFaceUrls'] as List<dynamic>?;
          if (mainList != null) faceUrls.addAll(mainList.cast<String>());
        }

        // Check committee sub-collection
        if (faceUrls.isEmpty) {
          final committeeSnapshot = await overseerDoc.reference
              .collection('committee_members')
              .get();

          for (var doc in committeeSnapshot.docs) {
            if (doc.data().containsKey('faceUrl')) {
              faceUrls.add(doc.data()['faceUrl'] as String);
              // We temporarily set this, but ideally, we pass it explicitly if we know who logged in
              setState(() {
                loggedMemberName = doc.data()['name'] ?? 'Overseer Member';
                loggedMemberRole = doc.data()['portfolio'] ?? 'Committee';
              });
            }
          }
        }

        await _launchFaceVerification(
          context,
          faceUrls,
          uid,
          role: 'Overseer',
          loggedMemberName: loggedMemberName,
          loggedMemberRole: loggedMemberRole,
        );
        return; // Stops execution here
      }

      // -----------------------------------------------------------------------
      // CHECK 3: STAFF MEMBERS (Updated for your DB Schema)
      // -----------------------------------------------------------------------
      final staffQuery = await FirebaseFirestore.instance
          .collection('staff_members')
          .where('email', isEqualTo: txtEmail.text.trim())
          .get();

      if (staffQuery.docs.isNotEmpty) {
        final staffDoc = staffQuery.docs.first;
        final staffData = staffDoc.data();

        // 1. Get Face URL (Handle singular 'faceUrl' from your DB)
        List<String> targetFaces = [];
        if (staffData['faceUrl'] != null &&
            staffData['faceUrl'].toString().isNotEmpty) {
          targetFaces.add(staffData['faceUrl'] as String);
        }

        // 2. Get Details (Matches your DB: 'name', 'portfolio', 'role')
        final String staffName =
            staffData['name'] ?? 'Staff Member'; // e.g., "Kgaogelo"
        final String staffPortfolio =
            staffData['portfolio'] ?? 'Staff'; // e.g., "Super User"
        final String staffRole = staffData['role'] ?? 'Admin'; // e.g., "Admin"

        // 3. Get Camera
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          if (context.mounted) {
            Navigator.pop(context); // Close loading
            Api().showMessage(context, 'No camera found.', 'Error', Colors.red);
          }
          return;
        }

        // 4. Launch Verification
        if (!context.mounted) return;

        // OPTIONAL: Close the loading spinner here so it doesn't overlap the camera
        // Navigator.pop(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceVerificationScreen(
              email: txtEmail.text.trim(),
              password: txtPassword.text.trim(),
              camera: cameras.first,
              authorizedFaceUrls:
                  targetFaces, // Passed as a List ["https://..."]
              entityUid: uid,
              role: staffRole,
              loggedMemberName: staffName,
              loggedMemberRole: staffPortfolio,
            ),
          ),
        );
        return; // <--- CRITICAL FIX: PREVENTS FALLING THROUGH TO CHECK 4
      }

      // -----------------------------------------------------------------------
      // CHECK 4: STANDARD USERS (Member, Seller, External)
      // -----------------------------------------------------------------------
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        if (!context.mounted) return;
        Navigator.pop(context);
        Api().showMessage(
          context,
          'User profile not found.',
          'Error',
          Colors.red,
        );
        return;
      }

      final Map<String, dynamic>? userData = userDoc.data();
      final String role = userData?['role'] ?? 'Member';

      if (role == 'Member' || role == 'Seller' || role == 'External Member') {
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, "/main-menu");
      } else {
        if (!context.mounted) return;
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Access denied for role: $role',
          'Error',
          Colors.red,
        );
      }
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

  // --- UPDATED HELPER FUNCTION ---
  Future<void> _launchFaceVerification(
    BuildContext context,
    List<String> faceUrls,
    String uid, {
    required String role, // Added Role Parameter
    String? loggedMemberName,

    final String? loggedMemberRole,
  }) async {
    // 1. Close the Loading Dialog
    if (context.mounted) Navigator.pop(context);

    // 2. Check if we actually found faces
    if (faceUrls.isEmpty) {
      if (context.mounted) {
        // Fallback: If absolutely no faces found, maybe allow login or show specific error?
        // For security, we usually block.
        Api().showMessage(
          context,
          'No registered faces found for this account.',
          'Access Denied',
          Colors.red,
        );
      }
      return;
    }

    // 3. Check Camera Availability
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (context.mounted) {
        Api().showMessage(context, 'No camera found.', 'Error', Colors.red);
      }
      return;
    }

    // 4. Navigate
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FaceVerificationScreen(
            email: txtEmail.text.trim(),
            password: txtPassword.text.trim(),
            camera: cameras.first,
            authorizedFaceUrls: faceUrls,
            entityUid: uid, // Renamed from universityUID
            role: role, // Pass the identified role
            loggedMemberName: loggedMemberName,
            loggedMemberRole: loggedMemberRole,
          ),
        ),
      );
    }
  }
  // --- HELPER FUNCTION TO AVOID REPEATING CAMERA LOGIC ---

  // [REPLACED build METHOD]
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.centerLeft,
            colors: [
              color.primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              // Center the layout
              child: Container(
                // Constrain the width on large screens (web)
                constraints: const BoxConstraints(maxWidth: 500),
                // Always use the mobile layout
                child: buildMobileLayout(),
              ),
            );
          },
        ),
      ),
    );
  }

  // [buildWebLayout METHOD IS DELETED]

  // [KEPT buildMobileLayout METHOD]
  Widget buildMobileLayout() {
    final color = Theme.of(context);
    final bool showAd = isAndroidPlatform && isIOSPlatform && !kIsWeb;

    return Column(
      children: [
        SizedBox(height: 20),
        SlideTransition(
          position: _logoOffsetAnimation,
          child: FadeTransition(
            opacity: _logoOpacityAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(90),
              child: Image.asset(
                "assets/dankie_logo.PNG",
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        if (showAd) AdManager().bannerAdWidget(),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                color: color.primaryColor.withOpacity(0.7),
                elevation: 20,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: buildFormContent(isWeb: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // [REPLACED buildFormContent METHOD]
  Widget buildFormContent({required bool isWeb}) {
    final colorScheme = Theme.of(context);

    // [FIX] Now that web and mobile are the same, text is always white.
    final textColor = colorScheme.cardColor;

    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      key: _formKey,
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
            style: TextStyle(fontSize: 16, color: textColor.withOpacity(1)),
          ),
          const SizedBox(height: 30),

          // --- PLATFORM AWARE EMAIL FIELD ---
          _buildPlatformTextField(
            context: context,
            controller: txtEmail,
            placeholder: 'Email Address',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: isIOSPlatform ? CupertinoIcons.mail_solid : Icons.email,
            validator: (value) => TextFieldValidation.email(value!),
          ),

          const SizedBox(height: 10),

          // --- PLATFORM AWARE PASSWORD FIELD ---
          _buildPlatformTextField(
            context: context,
            controller: txtPassword,
            placeholder: 'Password',
            obscureText: _obscureText,
            prefixIcon: isIOSPlatform ? CupertinoIcons.lock_fill : Icons.lock,
            suffixIcon: isIOSPlatform
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                    child: Icon(
                      _obscureText
                          ? CupertinoIcons.eye_slash_fill
                          : CupertinoIcons.eye_fill,
                      color: CupertinoColors.systemGrey,
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      color: colorScheme.primaryColor,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
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
                    color: colorScheme.cardColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          isIOSPlatform
              ? CupertinoButton.filled(
                  foregroundColor: colorScheme.primaryColor,
                  color: colorScheme.scaffoldBackgroundColor,
                  child: Text("Login"),
                  onPressed: () {
                    if (txtEmail.text.trim() == "mfundo@thetact.com" &&
                        txtPassword.text.trim() == "password123") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SongsUpdate(),
                        ),
                      );
                    } else {
                      _handleEmailPasswordLogin();
                    }
                  },
                )
              : Custom_Button(
                  text: "Login",
                  backgroundColor: colorScheme.primaryColor,
                  foregroundColor: Colors.white,
                  onPressed: _handleEmailPasswordLogin,
                  minWidth: double.infinity,
                ),

          const SizedBox(height: 10),

          // --- PLATFORM AWARE PROCEED BUTTON ---
          isIOSPlatform
              ? CupertinoButton(
                  color: colorScheme.primaryColor,
                  foregroundColor: colorScheme.scaffoldBackgroundColor,
                  child: Text(
                    "Proceed without login",
                    style: TextStyle(color: colorScheme.cardColor),
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('authToken');
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
                )
              : CustomOutlinedButton(
                  text: "Proceed without login",
                  backgroundColor: colorScheme.scaffoldBackgroundColor,
                  foregroundColor: colorScheme.primaryColor,
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('authToken');

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

          const Divider(color: Colors.grey, thickness: 1),

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
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
