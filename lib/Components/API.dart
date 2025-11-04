import 'dart:convert';

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:mailer/mailer.dart';

import 'package:mailer/smtp_server.dart';

import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:toastification/toastification.dart'; 

import 'package:ttact/Components/song.dart';
 
import 'CustomOutlinedButton.dart';

class Api {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
String YOUR_BACKEND_BASE_URL =
    'https://us-central1-tact-3c612.cloudfunctions.net/api';
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
    String selectedCommunityElder,
    String selectedCommunityName, 

    BuildContext context, {required String bankCode,required String accountNumber}
  ) async {
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

                            if (role == 'Seller')
                            'sellerPaystackAccount':'',
          "province": selectedProvince,
          "districtElderName": selectedDistrictElder,
          "communityElderName": selectedCommunityElder,
          "communityName": selectedCommunityName,
                            "uid": FirebaseAuth
                                .instance
                                .currentUser!
                                .uid, // Ensure uid is stored
        });
      }
if (role == 'Seller') {
                        String? subaccountCode = await createSellerSubaccount(
                          uid: FirebaseAuth.instance.currentUser!.uid,
                          businessName: '${name}\' s Shopping',
                          email: email,
                          accountNumber: accountNumber,
                          bankCode:bankCode, // get this from user input
                        );

                        if (subaccountCode != null) {
                          print('Subaccount created: $subaccountCode');
                          
                        } else {
                          // Handle failure
                          print('Failed to create Paystack subaccount');
                        }
                      }
      await user?.sendEmailVerification();

      Navigator.pop(context);

                      // AdManager().showRewardedInterstitialAd((ad, reward) {
                      //   print(
                      //     'User earned reward: ${reward.amount} ${reward.type}',
                      //   );
                      // });
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

  // Future<void> sendEmail(

  // String recipientEmail, String subject, String body) async {

  // final smtpServer = gmail('accomate33@gmail.com', 'nhle ndut leqq baho');

  // final message = Message()

  // ..from = Address('accomate33@gmail.com', 'Accomate')

  // ..recipients.add(recipientEmail)

  // ..subject = subject

  // ..html = body;

  // try {

  // await send(message, smtpServer);

  // print('Email sent successfully');

  // } catch (e) {

  // print('Error sending email: $e');

  // }}

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

// Assuming your Song model is in lib/Components/song.dart

// You'll need to modify it as well to include 'localFilePath'

// If you haven't, please update your Song class first:

/*

class Song {

final String? id;

final String? songName;

final String? artist;

final String? songUrl; // URL to the song on Firebase Storage

final Timestamp? createdAt;

final String? localFilePath; // NEW: Path to the locally downloaded file



Song({

this.id,

this.songName,

this.artist,

this.songUrl,

this.createdAt,

this.localFilePath,

});



factory Song.fromMap(Map<String, dynamic> map) {

return Song(

id: map['id'] as String?,

songName: map['songName'] as String?,

artist: map['artist'] as String?,

songUrl: map['songUrl'] as String?,

createdAt: map['createdAt'] is Timestamp

? map['createdAt'] as Timestamp

: (map['createdAt'] != null

? Timestamp.fromDate(DateTime.parse(map['createdAt']))

: null),

localFilePath: map['localFilePath'] as String?,

);

}



Map<String, dynamic> toMap() {

return {

'id': id,

'songName': songName,

'artist': artist,

'songUrl': songUrl,

'createdAt': createdAt,

'localFilePath': localFilePath,

};

}

}

*/

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

          localFilePath: filePath, // Store the local path
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
