 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:flutter/material.dart'; 
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart'; 
import 'CustomOutlinedButton.dart'; 

class Api {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signUp(
    String name,
    String email,
    String password,
    String txtAddress,
    String txtContactNumber,
    String role,
    BuildContext context,
  ) async {
    try {
      showLoading(context);
      UserCredential credentials = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credentials.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          "name": name,
          "email": email,
          "profileUrl": "",
          "Address": txtAddress,
          "Contact Number": txtContactNumber,
          "role": role,
        });
      }
      await user?.sendEmailVerification();
      Navigator.pop(context);
      showSuccessMessage(
        context,
        "Account created successfully! Please login.",
      );
      return user;
    } catch (e) {
      showMessage(context, e.toString());
    }
    return null;
  }

  void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        backgroundColor: const Color.fromARGB(255, 44, 102, 46),
        content: Text(message),
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/');
          },
        ),
      ),
    );
  }

  Future<User?> login(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      showLoading(context);
      UserCredential? user = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Navigator.pop(context);
      Navigator.pushNamed(context, '/main-menu');
      return user.user;
    } catch (e) {
      Navigator.pop(context);
      showMessage(context, e.toString());
    }
  }

  Future<Map<String, dynamic>?> fetchUser(
    String uid,
    BuildContext context,
  ) async {
    try {
      showLoading(context);
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      Navigator.pop(context);
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        showMessage(context, "User data not found.");
        return null;
      }
    } catch (e) {
      Navigator.pop(context);
      print("Error fetching user: $e");
      showMessage(context, "Something went wrong. Please try again later.");
      return null;
    }
  }

  void showLogoutMessage(
    BuildContext context,
    String title,
    String message,
    String btnCancel,
    String btnConfirm,
    Function() onPressed,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Center(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ),
        content: Text(message),
        actions: [
          CustomOutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            text: btnCancel,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).primaryColor,
            width: 120,
          ),
          CustomOutlinedButton(
            onPressed: onPressed,
            text: btnConfirm,
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            width: 120,
          ),
        ],
      ),
    );
  }

  void showLoading(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: Colors.green)),
    );
  }
  //  Future<void> sendEmail(
  //       String recipientEmail, String subject, String body) async {

  //       final smtpServer = gmail('accomate33@gmail.com', 'nhle ndut leqq baho');
  //       final message = Message()
  //         ..from = Address('accomate33@gmail.com', 'Accomate')
  //         ..recipients.add(recipientEmail)
  //         ..subject = subject
  //         ..html = body;

  //       try {
  //         await send(message, smtpServer);
  //         print('Email sent successfully');
  //       } catch (e) {
  //         print('Error sending email: $e');
  //       }}
  Future<void> sendEmail(
    BuildContext context,
    String email,
    String _message,
    String subject,
    String body,
  ) async {
    String username = "weath3rextreme@gmail.com";
    String password = "mhoi nfdw pdhq eqip";
    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 465,
      username: username,
      password: password,
      ssl: true,
    );
    final message = Message()
      ..from = Address(username, 'Weather Alert Extreme')
      ..recipients.add(email)
      ..subject = subject
      ..html = _message
      ..text = body;
    try {
      showLoading(context);
      final report = await send(message, smtpServer);
      print("Email send successfully ${report.toString()}");
    } catch (e) {
      print(e.toString());
    }
  }
}
