import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:ttact/Components/song.dart';
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
      final color = Theme.of(context);
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
      showMessage(
        context,
        "Account created successfully! Please login.",
        'Proceed to login',
        color.splashColor,
      );
      Navigator.pushNamed(context, '/login');
      return user;
    } catch (e) {
      final color = Theme.of(context);

      showMessage(context, e.toString(), 'Error', color.primaryColorDark);
    }
    return null;
  }

  void showMessage(
    BuildContext context,
    String message,
    String title,
    Color _color,
  ) {
    final color = Theme.of(context);
    toastification.dismissAll();
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      autoCloseDuration: const Duration(seconds: 5),
      title: Text(title, style: TextStyle(color: _color)),
      description: RichText(text: TextSpan(text: message)),
      alignment: Alignment.bottomCenter,
      animationDuration: const Duration(milliseconds: 500),
      icon: const Icon(Icons.check),
      showIcon: true,
      primaryColor: color.scaffoldBackgroundColor,
      backgroundColor: _color,

      borderRadius: BorderRadius.circular(30),
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(
        color: color.scaffoldBackgroundColor,
      ),
      closeButton: ToastCloseButton(
        showType: CloseButtonShowType.onHover,
        buttonBuilder: (context, onClose) {
          return OutlinedButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20, color: Colors.white),
            label: const Text('Close'),
          );
        },
      ),
      closeOnClick: true,
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
      return user.user;
    } on FirebaseAuthException catch (e) {
      final color = Theme.of(context);
      Navigator.pop(context);
      showMessage(context, e.message!, 'Error', color.primaryColorDark);
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
    final color = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) =>
          Center(child: CircularProgressIndicator(color: color.primaryColor)),
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

  //Music API
}
 

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();

  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal();

  final AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;

  Future<void> play(String url) async {
    await audioPlayer.play(UrlSource(url));
    isPlaying = true;
  }

  Future<void> pause() async {
    await audioPlayer.pause();
    isPlaying = false;
  }

  Future<void> resume() async {
    await audioPlayer.resume();
    isPlaying = true;
  }

  Future<void> stop() async {
    await audioPlayer.stop();
    isPlaying = false;
  }
} 
 

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<void> saveDownloadedSong(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('downloaded_songs') ?? [];
    existing.add(jsonEncode(song.toJson()));
    await prefs.setStringList('downloaded_songs', existing);
  }

  Future<void> saveToPlaylist(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('playlist_songs') ?? [];
    existing.add(jsonEncode(song.toJson()));
    await prefs.setStringList('playlist_songs', existing);
  }

  Future<List<Song>> getDownloadedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('downloaded_songs') ?? [];
    return list.map((e) => Song.fromMap(jsonDecode(e))).toList();
  }

  Future<List<Song>> getPlaylistSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('playlist_songs') ?? [];
    return list.map((e) => Song.fromMap(jsonDecode(e))).toList();
  }
}
