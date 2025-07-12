import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

class AddMusic extends StatefulWidget {
  const AddMusic({super.key});

  @override
  State<AddMusic> createState() => _AddMusicState();
}

class _AddMusicState extends State<AddMusic> {
  TextEditingController songNameController = TextEditingController();
  TextEditingController artistController = TextEditingController();
  DateTime? _releasedDate;
  File? _videoFile;
  String? _audioUrl;
  bool _isLoading = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _videoFile = File(result.files.single.path!);
      });
    }
  }

Future<void> uploadVideo() async {
  if (_videoFile == null) return;

  Api().showLoading(context);
  setState(() => _isLoading = true);

  try {
    // 1. Convert video to audio via Django
    final audioFile = await _convertToAudio(_videoFile!.path);
    
    // 2. Upload to Firebase Storage
    final audioUrl = await _uploadToFirebase(audioFile);
    
    // 3. Save to Firestore
    await FirebaseFirestore.instance.collection('tact_music').add({
      "songName": songNameController.text,
      "artist": artistController.text,
      "songUrl": audioUrl,
      "released": _releasedDate,
    });
    
    Api().showMessage(
      context,
      'Song Uploaded Successfully',
      '',
      Theme.of(context).splashColor,
    );
  } catch (e) {
    Api().showMessage(
      context,
      'Error: ${e.toString()}',
      '',
      Theme.of(context).primaryColorDark,
    );
  } finally {
    Navigator.pop(context);
    setState(() => _isLoading = false);
  }
}
Future<File> _convertToAudio(String videoPath) async {
  final uri = Uri.parse('https://tactapi-production.up.railway.app/extract-audio/');
  final request = http.MultipartRequest('POST', uri);
  
  request.files.add(await http.MultipartFile.fromPath(
    'video',
    videoPath,
    contentType: MediaType('video', 'mp4'),
  ));
  
  try {
    final response = await request.send().timeout(Duration(minutes: 2));
    
    if (response.statusCode != 200) {
      throw Exception('Conversion failed: ${response.statusCode}');
    }
    
    // Save to temp file
    final dir = await getTemporaryDirectory();
    final audioFile = File('${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
    await audioFile.writeAsBytes(await response.stream.toBytes());
    
    return audioFile;
  } on TimeoutException {
    throw Exception('Conversion timed out');
  } catch (e) {
    throw Exception('Conversion error: ${e.toString()}');
  }
}
Future<String> _uploadToFirebase(File audioFile) async {
  final ref = FirebaseStorage.instance
      .ref()
      .child('songs')
      .child('${DateTime.now().millisecondsSinceEpoch}.mp3');
  
  final uploadTask = ref.putFile(audioFile);
  final snapshot = await uploadTask;
  
  return await snapshot.ref.getDownloadURL();
}
  // Future<void> uploadVideo() async {
  //   Api().showLoading(context);
  //   if (_videoFile == null) return;

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   final request = http.MultipartRequest(
  //     'POST',
  //     Uri.parse('https://tactapi-production.up.railway.app/extract-audio/'),
  //   );
  //   request.files.add(
  //     await http.MultipartFile.fromPath('video', _videoFile!.path),
  //   );

  //   final response = await request.send();

  //   if (response.statusCode == 201) {
  //     Navigator.pop(context);
  //     final responseBody = await response.stream.bytesToString();
  //     final audioUrl = RegExp(
  //       r'"audio":"(.*?)"',
  //     ).firstMatch(responseBody)?.group(1);
  //     if (audioUrl != null) {
  //       // Replace any escaped slashes
  //       final cleanUrl = audioUrl.replaceAll(r'\/', '/');

  //       // Make sure full URL is correct
  //       final fullAudioUrl = cleanUrl.startsWith('http')
  //           ? cleanUrl
  //           : 'https://tactapi-production.up.railway.app/extract-audio/$cleanUrl';

  //       setState(() {
  //         _audioUrl = fullAudioUrl;
  //       });
  //       FirebaseFirestore.instance.collection('tact_music').add({
  //         "songName": songNameController.text,
  //         "artist": artistController.text,
  //         "songUrl": _audioUrl!,
  //         "released": _releasedDate,
  //       });
  //       Api().showMessage(
  //         context,
  //         'Song Uploaded Successfully',
  //         '',
  //         Theme.of(context).splashColor,
  //       );
  //     }
  //   } else {
  //     Navigator.pop(context);
  //     Api().showMessage(
  //       context,
  //       '${response.statusCode}',
  //       '',
  //       Theme.of(context).primaryColorDark,
  //     );
  //     debugPrint('Failed: ${response.statusCode}');
  //   }

  //   setState(() {
  //     _isLoading = false;
  //   });
  // }

  Future<void> playAudio() async {
    if (_audioUrl != null) {
      await _audioPlayer.play(
        UrlSource(_audioUrl!),
        mode: PlayerMode.mediaPlayer,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: ListView(
        children: [
          Center(
            child: Card(
              elevation: 10,
              color: Colors.transparent,
              child: GestureDetector(
                onTap: pickVideo,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: SweepGradient(
                      transform: GradientRotation(5),
                      center: AlignmentGeometry.directional(1, 0.009),
                      startAngle: 0.1,
                      endAngle: 10,
                      colors: [
                        color.hintColor,
                        color.primaryColor,
                        color.splashColor.withOpacity(0.5),
                        color.primaryColorDark,
                      ],
                    ),
                  ),
                  height: 200,
                  width: 200,
                  child: Icon(
                    Ionicons.add_sharp,
                    size: 70,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            controller: songNameController,
            placeholder: 'Please enter the song name',
            keyboardType: TextInputType.name,
            padding: EdgeInsetsGeometry.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(width: 1, color: color.primaryColor),
              shape: BoxShape.rectangle,
            ),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            controller: artistController,
            placeholder: 'Please enter the artist\'s name',
            keyboardType: TextInputType.name,
            padding: EdgeInsetsGeometry.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(width: 1, color: color.primaryColor),
              shape: BoxShape.rectangle,
            ),
          ),
          GestureDetector(
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                setState(() {
                  _releasedDate = pickedDate;
                });
              }
            },
            child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(width: 1, color: color.primaryColor),
                shape: BoxShape.rectangle,
              ),
              child: Text(
                _releasedDate != null
                    ? 'Released Date: ${_releasedDate!.toLocal()}'.split(' ')[0]
                    : 'Please select the released date',
                style: TextStyle(color: color.primaryColor, fontSize: 16),
              ),
            ),
          ),
          SizedBox(height: 20),
          if (_audioUrl != null)
            IconButton.outlined(
              onPressed: playAudio,
              icon: Icon(Ionicons.musical_notes_outline),
            ),
          SizedBox(height: 20),
          CustomOutlinedButton(
            onPressed: uploadVideo,
            text: 'Upload Song',
            backgroundColor: color.scaffoldBackgroundColor,
            foregroundColor: color.primaryColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
