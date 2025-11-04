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

// Helper list for video formats used to trigger API conversion
const List<String> videoExtensions = ['mp4', 'mov', 'avi', 'wmv'];

class _AddMusicState extends State<AddMusic> {
  TextEditingController songNameController = TextEditingController();
  TextEditingController artistController = TextEditingController();
  DateTime? _releasedDate;

  // Holds the selected file (either video or audio)
  File? _selectedFile;

  String? _audioUrl; // Final URL for playback

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    songNameController.dispose();
    artistController.dispose();
    super.dispose();
  }

  // --- FILE PICKER LOGIC (Simplified) ---

  Future<void> pickFile() async {
    // Allows selection of videos and MP3s directly
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [...videoExtensions, 'mp3'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _audioUrl = null; // Clear previous audio URL preview
      });
      Api().showMessage(
        context,
        'File selected: ${result.files.single.name}',
        'Success',
        Theme.of(context).primaryColor,
      );
    } else if (result == null) {
      Api().showMessage(
        context,
        'File selection cancelled.',
        'Info',
        Theme.of(context).hintColor,
      );
    }
  }

  // --- UPLOAD LOGIC (Central Handler) ---

  Future<void> uploadSong() async {
    if (_selectedFile == null ||
        category.isEmpty ||
        songNameController.text.isEmpty ||
        artistController.text.isEmpty) {
      Api().showMessage(
        context,
        'Please select a file, enter song details, and choose a category.',
        'Validation Error',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    Api().showLoading(context);

    File audioToUpload;
    String finalAudioUrl;

    // Determine file type based on extension
    final fileName = _selectedFile!.path.split('/').last;
    final fileExtension = fileName.split('.').last.toLowerCase();
    final isVideo = videoExtensions.contains(fileExtension);

    try {
      if (isVideo) {
        // --- SCENARIO 1: VIDEO (Needs Conversion via Django API) ---
        audioToUpload = await _convertToAudio(_selectedFile!.path);
      } else if (fileExtension == 'mp3') {
        // --- SCENARIO 2: MP3 AUDIO (Direct Upload) ---
        audioToUpload = _selectedFile!;
      } else {
        // Handles unexpected file types, though FilePicker should prevent this
        throw Exception('Unsupported file type: .$fileExtension');
      }

      // 2. Upload the final audio file to Firebase Storage
      finalAudioUrl = await _uploadToFirebase(audioToUpload);

      // 3. Save to Firestore
      await FirebaseFirestore.instance.collection('tact_music').add({
        "songName": songNameController.text,
        "artist": artistController.text,
        "songUrl": finalAudioUrl,
        // Ensure Timestamp conversion handles null dates
        "released": _releasedDate != null
            ? Timestamp.fromDate(_releasedDate!)
            : null,
        "category": category,
      });

      // Update local state for immediate playback preview
      setState(() {
        _audioUrl = finalAudioUrl;
        _selectedFile = null; // Clear the selected file after successful upload
        songNameController.clear();
        artistController.clear();
        _releasedDate = null;
        category = '';
      });

      Api().showMessage(
        context,
        'Song Uploaded Successfully',
        'Success',
        Theme.of(context).splashColor,
      );
    } catch (e) {
      Api().showMessage(
        context,
        'Error: ${e.toString()}',
        'Upload Failed',
        Theme.of(context).primaryColorDark,
      );
    } finally {
      // Dismiss loading dialog
      Navigator.pop(context);
    }
  }

  // --- DJANGO CONVERSION API CALL ---

  Future<File> _convertToAudio(String videoPath) async {
    final uri = Uri.parse('https://tact-api.up.railway.app/extract-audio/');
    final request = http.MultipartRequest('POST', uri);

    final fileExtension = videoPath.split('.').last;

    request.files.add(
      await http.MultipartFile.fromPath(
        'video_file',
        videoPath,
        // Dynamically set video type based on extension
        contentType: MediaType('video', fileExtension),
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
      );

      if (streamedResponse.statusCode != 201 &&
          streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        throw Exception(
          'Conversion failed (${streamedResponse.statusCode}): $responseBody',
        );
      }

      final audioBytes = await streamedResponse.stream.toBytes();

      final dir = await getTemporaryDirectory();
      final audioFile = File(
        '${dir.path}/converted_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );

      await audioFile.writeAsBytes(audioBytes);

      return audioFile;
    } on TimeoutException {
      throw Exception(
        'Conversion timed out. The video file might be too large or the server is slow.',
      );
    } catch (e) {
      throw Exception('Conversion and download error: ${e.toString()}');
    }
  }

  // --- FIREBASE STORAGE UPLOAD ---

  Future<String> _uploadToFirebase(File audioFile) async {
    final fileName = audioFile.path.split('/').last;
    final ref = FirebaseStorage.instance.ref().child('songs').child(fileName);

    final uploadTask = ref.putFile(
      audioFile,
      SettableMetadata(contentType: 'audio/mpeg'), // Set MIME type explicitly
    );
    final snapshot = await uploadTask;

    return await snapshot.ref.getDownloadURL();
  }

  // --- AUDIO PLAYBACK ---

  Future<void> playAudio() async {
    if (_audioUrl != null) {
      await _audioPlayer.play(
        UrlSource(_audioUrl!),
        mode: PlayerMode.mediaPlayer,
      );
    }
  }

  List categories = [
    'Slow Jam',
    'Apostle choir',
    'choreography',
    'Instrumental songs',
  ];
  String category = '';

  // --- WIDGET BUILDER ---

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final selectedFileName = _selectedFile?.path.split('/').last;

    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: ListView(
        children: [
          Center(
            child: Card(
              elevation: 10,
              color: Colors.transparent,
              child: GestureDetector(
                onTap: pickFile, // Simplified: Tap to open picker directly
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: SweepGradient(
                      transform: const GradientRotation(5),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedFile == null
                            ? Ionicons.add_sharp
                            : Ionicons.document_text_outline,
                        size: 50,
                        color: color.scaffoldBackgroundColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFile == null
                            ? 'Tap to Select Video/Audio'
                            : (videoExtensions.contains(
                                    selectedFileName
                                        ?.split('.')
                                        .last
                                        .toLowerCase(),
                                  )
                                  ? 'Video Selected (Needs Conversion)'
                                  : 'Audio Selected (Direct Upload)'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color.scaffoldBackgroundColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_selectedFile != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            selectedFileName ?? '',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: color.scaffoldBackgroundColor,
                            ),
                          ),
                        ),
                    ],
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
            padding: const EdgeInsets.all(14),
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
            padding: const EdgeInsets.all(14),
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
              padding: const EdgeInsets.all(14),
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
              icon: const Icon(Ionicons.musical_notes_outline),
            ),
          SizedBox(height: 20),
          CustomOutlinedButton(
            onPressed: uploadSong,
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


