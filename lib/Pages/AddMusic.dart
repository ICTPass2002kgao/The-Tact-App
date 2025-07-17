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
      "category":category
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
  Future<void> playAudio() async {
    if (_audioUrl != null) {
      await _audioPlayer.play(
        UrlSource(_audioUrl!),
        mode: PlayerMode.mediaPlayer,
      );
    }
  }

  List categories = ['Slow Jam', 'Apostle choir','choreography','Instrumental songs'];
  String category = '';
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
          SizedBox(height: 10),
           ExpansionTile(
                        title: Text(
                          category.isEmpty ? 'Select category' : category,
                          style: TextStyle(color: color.primaryColor),
                        ),
                        children: [
                          ...categories
                              .map(
                                (userRole) => RadioListTile<String>(
                                  value: userRole,
                                  groupValue: category,
                                  onChanged: (val) {
                                    setState(() {
                                      category = val as String;
                                      
                                    });
                                  },
                                  title: Text(userRole),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                     
          SizedBox(height: 10),
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
