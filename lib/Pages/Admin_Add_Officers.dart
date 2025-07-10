import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; 
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
  File? _videoFile;
  File? _audioFile;
  String? _downloadUrl;
  bool _isProcessing = false;
  DateTime? _releasedDate;

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _videoFile = File(result.files.single.path!);
        _audioFile = null;
        _downloadUrl = null;
      });
    }
  }

  Future<void> extractAndUpload() async {
    final color = Theme.of(context);
    if (_videoFile == null) return;

    setState(() {
      _isProcessing = true;
    });
    Api().showLoading(context);
    final dir = await getTemporaryDirectory();
    final audioPath = '${dir.path}/output_audio.mp3';

    final command = '-i "${_videoFile!.path}" -q:a 0 -map a "$audioPath"';

    await FFmpegKit.execute(command);

    final audioFile = File(audioPath);
    if (await audioFile.exists()) {
      setState(() {
        _audioFile = audioFile;
      });

      final storageRef = FirebaseStorage.instance.ref().child(
        'Tact_songs/${DateTime.now().millisecondsSinceEpoch}.mp3',
      );

      final uploadTask = storageRef.putFile(audioFile);
      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('tact_music').add({
        'songName': songNameController.text,
        'artist': artistController.text,
        'released_date': _releasedDate,
        'audioUrl': url,
      });
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Song Uploaded successfully',
        '',
        color.splashColor,
      );
    }

    setState(() {
      _isProcessing = false;
    });
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
          SizedBox(height: 20),
          CustomOutlinedButton(
            onPressed: extractAndUpload,
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
