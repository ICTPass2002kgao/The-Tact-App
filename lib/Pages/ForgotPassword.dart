// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/TextFields.dart';

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

  // Custom reset logic to handle form validation and Firebase call
  Future<void> _handlePasswordReset() async {
    final color = Theme.of(context);

    // 1. Validate the form (checks both empty and valid email)
    if (_formKey.currentState?.validate() ?? false) {
      Api().showLoading(context);

      try {
        FirebaseAuth auth = FirebaseAuth.instance;
        await auth.sendPasswordResetEmail(email: emailController.text.trim());

        if (!context.mounted) return;
        Navigator.pop(context); // Close loading dialog

        Api().showMessage(
          context,
          'Password reset link sent to ${emailController.text.trim()}',
          'Success',
          color.splashColor,
        );

        // Navigator.pop(context); // Optional: pop the ForgotPassword screen after success
      } on FirebaseAuthException catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Close loading dialog

        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found for that email address.';
        } else {
          errorMessage = e.message ?? 'An unknown error occurred.';
        }

        Api().showMessage(
          context,
          errorMessage,
          'Error',
          color.primaryColorDark,
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Close loading dialog

        Api().showMessage(
          context,
          'An unexpected error occurred: ${e.toString()}',
          'Error',
          color.primaryColorDark,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      // Set Scaffold background to transparent for the gradient
      backgroundColor: Colors.transparent,

      appBar: AppBar(
        title: Text('Forgot Password'),
        centerTitle: true, 
        // FIX: Match AppBar background to the top of the body gradient
        backgroundColor: color.scaffoldBackgroundColor, 
        elevation: 0, 
        foregroundColor: color.primaryColor,
      ),

      // Apply the Gradient to the entire body container 
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // FIX: Simplified Gradient for clean vertical fade
            colors: [
              color.scaffoldBackgroundColor,
              color.primaryColor.withOpacity(0.4), // Reduced opacity for softer fade
            ],
          ),
        ),

        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: BoxConstraints(maxWidth: 450), // Constrain width on desktop
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
                            color: color.primaryColor, // Use primary color for main title
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

                        // Email Field with better styling
                        AuthTextField(
                          onValidate: (value) =>
                              TextFieldValidation.email(value!),
                          placeholder: 'Email Address',
                          controller: emailController,
                          // Assuming AuthTextField is the same custom component used elsewhere
                        ),
                        SizedBox(height: 30),

                        // Reset Button
                        CustomOutlinedButton(
                          onPressed: _handlePasswordReset,
                          text: 'Send Reset Link',
                          backgroundColor: color.primaryColor,
                          foregroundColor: Colors.white,
                          width: double.infinity,
                        ),
                        SizedBox(height: 10),

                        // Back to Login Button
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Back to Login',
                            style: TextStyle(color: color.primaryColor.withOpacity(0.7), fontWeight: FontWeight.w500),
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