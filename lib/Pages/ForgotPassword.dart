// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

// --- PLATFORM UTILITIES IMPORTS ---
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Pages/FaceVerificationPage.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/ForgotPassword.dart';
import '../Components/API.dart';
import '../Components/Custom_Buttons.dart';
// import 'package:ttact/Components/TextFields.dart'; // No longer needed
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
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: isIOSPlatform
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
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(12.0),
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(prefixIcon, color: CupertinoColors.systemGrey),
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
          ),
  );
}
// --- END COPIED HELPERS ---

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // --- NEW: Platform-Aware Message ---
  void _showPlatformMessage(
    String title,
    String message,
    Color backgroundColor,
  ) {
    if (isIOSPlatform) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else {
      // Use the original SnackBar method for Material
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  // Custom reset logic to handle form validation and Firebase call
  Future<void> _handlePasswordReset() async {
    final color = Theme.of(context);

    // 1. Validate the form (checks both empty and valid email)
    if (_formKey.currentState?.validate() ?? false) {
isIOSPlatform?
    Api().showIosLoading(context):
 
    Api().showLoading(context);

      try {
        FirebaseAuth auth = FirebaseAuth.instance;
        await auth.sendPasswordResetEmail(email: emailController.text.trim());

        if (!context.mounted) return;
        Navigator.pop(context); // Close loading dialog

        // UPDATED: Use platform message
        _showPlatformMessage(
          'Success',
          'Password reset link sent to ${emailController.text.trim()}',
          color.splashColor,
        );
      } on FirebaseAuthException catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Close loading dialog

        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found for that email address.';
        } else {
          errorMessage = e.message ?? 'An unknown error occurred.';
        }

        // UPDATED: Use platform message
        _showPlatformMessage('Error', errorMessage, color.primaryColorDark);
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Close loading dialog

        // UPDATED: Use platform message
        _showPlatformMessage(
          'Error',
          'An unexpected error occurred: ${e.toString()}',
          color.primaryColorDark,
        );
      }
    }
  }

  // --- NEW: Platform-Aware AppBar ---
  PreferredSizeWidget _buildAppBar(ThemeData color) {
    if (isIOSPlatform) {
      return CupertinoNavigationBar(
        middle: Text('Forgot Password'),
        backgroundColor: color.scaffoldBackgroundColor,
        leading: CupertinoNavigationBarBackButton(
          color: color.primaryColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      return AppBar(
        title: Text('Forgot Password'),
        centerTitle: true,
        backgroundColor: color.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: color.primaryColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      // Set Scaffold background to transparent for the gradient
      backgroundColor: Colors.transparent,

      appBar: _buildAppBar(color), // Use platform-aware app bar
      // Apply the Gradient to the entire body container
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // FIX: Simplified Gradient for clean vertical fade
            colors: [
              color.scaffoldBackgroundColor,
              color.primaryColor.withOpacity(
                0.4,
              ), // Reduced opacity for softer fade
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 450,
              ), // Constrain width on desktop
              // Wrap content in a Card for the clean, contained look
              child: Card(
                elevation: 10,
                // Make card slightly transparent using primary color for visual style
                color: color.primaryColor.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reset Your Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color
                                .primaryColor, // Use primary color for main title
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Enter your account email address below and we will send you a link to reset your password.',
                          style: TextStyle(
                            fontSize: 14,
                            color: color.hintColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 30),

                        // --- PLATFORM AWARE EMAIL FIELD ---
                        _buildPlatformTextField(
                          context: context,
                          controller: emailController,
                          placeholder: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: isIOSPlatform
                              ? CupertinoIcons.mail
                              : Icons.email,
                          validator: (value) =>
                              TextFieldValidation.email(value!),
                        ),
                        SizedBox(height: 30),

                        // --- PLATFORM AWARE RESET BUTTON ---
                        isIOSPlatform
                            ? CupertinoButton.filled(
                                child: Text('Send Reset Link'),
                                onPressed: _handlePasswordReset,
                              )
                            : CustomOutlinedButton(
                                onPressed: _handlePasswordReset,
                                text: 'Send Reset Link',
                                backgroundColor: color.primaryColor,
                                foregroundColor: Colors.white,
                                width: double.infinity,
                              ),
                        SizedBox(height: 10),

                        // --- PLATFORM AWARE BACK BUTTON ---
                        isIOSPlatform
                            ? CupertinoButton(
                                child: Text(
                                  'Back to Login',
                                  style: TextStyle(
                                    color: color.primaryColor.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                              )
                            : TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Back to Login',
                                  style: TextStyle(
                                    color: color.primaryColor.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
