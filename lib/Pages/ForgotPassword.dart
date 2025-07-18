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
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Forgot Password'),
        centerTitle: true,
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
      ),
      backgroundColor: color.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Please enter your email address to reset your password.',
                style: TextStyle(fontSize: 16, color: color.primaryColor),
                textAlign: TextAlign.center,
              ),
            ),
            AuthTextField(
              onValidate: TextFieldValidation.email,
              placeholder: 'Email Address',
              controller: emailController,
            ),
            SizedBox(height: 20),
            CustomOutlinedButton(
              onPressed: () async {
                if (emailController.text.isNotEmpty &&
                    TextFieldValidation.email(emailController.text) == null) {
                  Api().showLoading(context);
                  FirebaseAuth auth = FirebaseAuth.instance;
                  await auth.sendPasswordResetEmail(
                    email: emailController.text,
                  );
                  Navigator.pop(context);
                  Api().showMessage(
                    context,
                    'Password reset link sent to ${emailController.text}',
                    'Success',
                    color.splashColor,
                  );
                } else {
                  Api().showMessage(
                    context,
                    'Please enter a valid email address',
                    'Error',
                    color.primaryColorDark,
                  );
                }
              },
              text: 'Reset Password',
              backgroundColor: color.primaryColor,
              foregroundColor: color.scaffoldBackgroundColor,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
