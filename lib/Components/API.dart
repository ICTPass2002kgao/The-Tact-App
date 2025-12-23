import 'dart:convert';

import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:mailer/mailer.dart';

import 'package:mailer/smtp_server.dart';

import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:toastification/toastification.dart';
import 'package:ttact/Components/AdBanner.dart';

import 'package:ttact/Components/song.dart';

import 'CustomOutlinedButton.dart';

class Api {
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

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String YOUR_BACKEND_BASE_URL =
      'https://us-central1-tact-3c612.cloudfunctions.net/api';

  final String EMAIL_CF_URL =
      'https://us-central1-tact-3c612.cloudfunctions.net/api/sendCustomEmail';

  // --- NEW METHOD 1: Code Generation ---
  String generateVerificationCode() {
    // Generates a random 6-digit number as a String
    final random = Random();
    // Generates a number between 100000 and 999999
    return (random.nextInt(900000) + 100000).toString();
  }

  // --- NEW METHOD 2: Email Sending ---
  // In your Api.dart file:

  // --- THIS IS THE FIX ---
  // The correct endpoint is /api/sendCustomEmail

  // --- NEW METHOD 2: Email Sending ---
  Future<bool> sendEmail(
    String email,
    String subject,
    String message,
    BuildContext context,
  ) async {
    try {
      final url = Uri.parse(EMAIL_CF_URL); // This now uses the correct URL

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"to": email, "subject": subject, "body": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          String errorMessage = data['error'] ?? 'Unknown function error';
          showMessage(
            context,
            'Email Error',
            'Failed to send verification email: $errorMessage',
            Theme.of(context).primaryColorDark,
          );
          print('CF Error: $errorMessage');
          return false;
        }
      } else {
        // This is the error you are seeing
        showMessage(
          context,
          'Network Error',
          'Could not reach the verification service. Status: ${response.statusCode}',
          Theme.of(context).primaryColorDark,
        );
        print('HTTP Error: ${response.body}');
        return false;
      }
    } catch (e) {
      showMessage(
        context,
        'Connection Error',
        'Failed to connect to the server: $e',
        Theme.of(context).primaryColorDark,
      );
      print('Exception: $e');
      return false;
    }
  }

  Future<String?> createSellerSubaccount({
    required String uid,
    required String businessName,
    required String email,
    required String accountNumber,
    required String bankCode,
  }) async {
    final url = Uri.parse('$YOUR_BACKEND_BASE_URL/create_seller_subaccount');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "uid": uid,
        "business_name": businessName,
        "bank_code": bankCode,
        "account_number": accountNumber,
        "contact_email": email,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['subaccount_code'];
    } else {
      print('Error creating subaccount: ${response.body}');
      return null;
    }
  }

  Future<User?> signUp(
    String name,
    String surname,
    String email,

    String password,

    String txtAddress,

    String txtContactNumber,

    String selectedMemberUid,
    String role,
    String selectedProvince,
    String selectedDistrictElder,
    String selectedCommunityName,

    BuildContext context, {
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final color = Theme.of(context);

      UserCredential credentials = await _auth.createUserWithEmailAndPassword(
        email: email,

        password: password,
      );

      User? user = credentials.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          "name": name,
          "surname": surname,
          "email": email,
          "profileUrl": "",
          "address": txtAddress,
          "phone": txtContactNumber,
          "overseerUid": selectedMemberUid,
          'week1': 0.00,
          'week2': 0.00,
          'week3': 0.00,
          'week4': 0.00,
          "role": role,

          if (role == 'Seller') 'sellerPaystackAccount': '',
          if (role == 'Seller') 'accountVerified': false,
          "province": selectedProvince,
          "districtElderName": selectedDistrictElder,
          "communityName": selectedCommunityName,
          "uid": FirebaseAuth.instance.currentUser!.uid, // Ensure uid is stored
        });
      }
      if (role == 'Seller') {
        String? subaccountCode = await createSellerSubaccount(
          uid: FirebaseAuth.instance.currentUser!.uid,
          businessName: '${name} ${surname}\' s Shopping',
          email: email,
          accountNumber: accountNumber,
          bankCode: bankCode,  );

        if (subaccountCode != null) {
          sendEmail(email, "Seller Account Created – Pending Verification", """
  <p>Dear ${name} ${surname},</p>
  <p>Welcome to <strong>Dankie Mobile (TACT)</strong>! Your seller account has been created successfully.</p>
  <p>Our team will now review and verify your account details to ensure everything is in order. 
  This process usually takes a short while, and you’ll receive an email notification once your account has been approved.</p>
  <p>After verification, you’ll be able to start adding your products and managing your sales on the platform.</p>
  <p>If you did not register as a seller or believe this was a mistake, please contact our support team immediately.</p>
  <br>
  <p>Best regards,<br>
  The Dankie Mobile Support Team</p>
  """, context);

          sendEmail(
            "kgaogelodeveloper@gmail.com",
            "New Seller Registration – Verification Required",
            """
  <p>Hello Admin,</p>
  <p>A new seller has registered on <strong>Dankie Mobile (TACT)</strong>:</p>
  <ul>
    <li>Name: ${name} ${surname}</li>
    <li>Email: ${email}</li>
    <li>Registered At: ${DateTime.now().toLocal()}</li>
  </ul>
  <p>Please review and verify this seller account as soon as possible so they can start selling on the platform.</p>
  <br>
  <p>Best regards,<br>
  Dankie Mobile System Notification</p>

  """,
            context,
          );
          print('Subaccount created: $subaccountCode');
        } else {
          // Handle failure
          // A. Delete the data we just wrote to Firestore
          await _firestore.collection('users').doc(user?.uid).delete();

          // B. Delete the User from Firebase Auth
          await user?.delete();
          Navigator.pop(context);
          Navigator.pop(context);
          debugPrint('Failed to create Paystack subaccount');
          // C. Stop execution immediately by throwing an error
          Api().showMessage(
            context,
            'Could not verify bank details. Account creation cancelled',
            'Error',
            Colors.red,
          );
          throw Exception(
            "Could not verify bank details. Account creation cancelled.",
          );
        }
      }

      Navigator.pop(context);
      if (role == 'Member ') {
        sendEmail(email, "Account Created Successfully", """
  <p>Dear ${name} $surname,</p>

  <p>Welcome to <strong>Dankie Mobile(TACT)</strong>! Your account has been created successfully.</p>

  <p>You can now log in and start exploring all available features tailored for you.</p>

  <p>If you did not request this account, please contact our support team immediately.</p>

  <br>
  <p>Best regards,<br>
  Dankie Support Team</p>
  """, context);
      }

      AdManager().showRewardedInterstitialAd((ad, reward) {
        print('User earned reward: ${reward.amount} ${reward.type}');
      });
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

      title: Text(title, style: TextStyle(color: Colors.white)),

      description: RichText(
        text: TextSpan(
          text: message,
          style: TextStyle(color: Colors.white),
        ),
      ),

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
      barrierDismissible: false,

      builder: (context) =>
          Center(child: CircularProgressIndicator(color: color.primaryColor)),
    );
  }

  void showIosLoading(BuildContext context) {
    final color = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(child: CupertinoActivityIndicator(color: color.primaryColor)),
    );
  }
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

  static const String _playlistSongsKey = 'playlist_songs';

  // --- Core Methods for Downloaded Songs ---

  /// Downloads the audio file from `song.songUrl` and saves it locally.

  /// Updates the `song` object with the `localFilePath` and saves it to SharedPreferences.

  /// Returns the updated Song object or null if download fails.

  Future<Song?> downloadSong(Song songToDownload) async {
    if (songToDownload.songUrl == null || songToDownload.songUrl.isEmpty) {
      debugPrint('Song URL is null or empty. Cannot download.');

      return null;
    }

    if (songToDownload.id == null || songToDownload.id!.isEmpty) {
      debugPrint(
        'Song ID is null or empty. Cannot download without a unique ID.',
      );

      return null;
    }

    try {
      final response = await http.get(Uri.parse(songToDownload.songUrl));

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();

        // Create a unique file name using the song ID

        final fileName = '${songToDownload.id}.mp3';

        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        // Create a new Song object with the local file path

        final updatedSong = Song(
          id: songToDownload.id,

          songName: songToDownload.songName,

          artist: songToDownload.artist,

          songUrl: songToDownload.songUrl,

          createdAt: songToDownload.createdAt,

          localFilePath: filePath,
        );

        debugPrint('Song downloaded to: $filePath');

        return updatedSong;
      } else {
        debugPrint(
          'Failed to download song: HTTP Status ${response.statusCode}',
        );

        return null;
      }
    } catch (e) {
      debugPrint('Error downloading song: $e');

      return null;
    }
  }

  /// Saves a Song object (which may or may not have a localFilePath) to the downloaded_songs list.

  /// This will overwrite an existing song with the same ID or add a new one.

  /// Retrieves all downloaded songs metadata, including their local file paths.

  /// Deletes a downloaded song by its ID.

  /// This will remove both the local audio file and its metadata from SharedPreferences.

  // --- Existing Methods for Playlist (Unchanged but using new keys) ---

  Future<void> saveToPlaylist(Song song) async {
    final prefs = await SharedPreferences.getInstance();

    List<Song> currentPlaylistSongs = await getPlaylistSongs();

    // Prevent duplicates in playlist if a song is already there (optional)

    if (!currentPlaylistSongs.any((s) => s.id == song.id)) {
      currentPlaylistSongs.add(song);

      final List<String> playlistJsonList = currentPlaylistSongs
          .map((s) => jsonEncode(s.toMap()))
          .toList();

      await prefs.setStringList(_playlistSongsKey, playlistJsonList);

      debugPrint('Song added to playlist: ${song.songName}');
    } else {
      debugPrint('Song "${song.songName}" already exists in playlist.');
    }
  }

  Future<List<Song>> getPlaylistSongs() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String>? playlistJsonList = prefs.getStringList(
      _playlistSongsKey,
    );

    if (playlistJsonList == null) {
      return [];
    }

    return playlistJsonList.map((e) => Song.fromMap(jsonDecode(e))).toList();
  }

  /// Removes a song from the playlist by its ID.

  Future<void> removeFromPlaylist(String songId) async {
    final prefs = await SharedPreferences.getInstance();

    List<Song> currentPlaylistSongs = await getPlaylistSongs();

    final initialLength = currentPlaylistSongs.length;

    currentPlaylistSongs.removeWhere((s) => s.id == songId);

    if (currentPlaylistSongs.length < initialLength) {
      final List<String> updatedPlaylistJsonList = currentPlaylistSongs
          .map((s) => jsonEncode(s.toMap()))
          .toList();

      await prefs.setStringList(_playlistSongsKey, updatedPlaylistJsonList);

      debugPrint('Song with ID $songId removed from playlist.');
    } else {
      debugPrint('Song with ID $songId not found in playlist.');
    }
  }
}
