// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print, unused_local_variable

// --- PLATFORM SAFETY IMPORTS ---
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'dart:io' as io show File; // Alias dart:io for native File access
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // For cross-platform image data

// Conditional path_provider import (using a stub or conditional dart:io)
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'dart:typed_data'; 
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart'; // XFile support

// --- STANDARD IMPORTS ---
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 600.0;
// --------------------------

// Helper list for video formats used to trigger API conversion
const List<String> videoExtensions = ['mp4', 'mov', 'avi', 'wmv'];

class AddMusic extends StatefulWidget {
  const AddMusic({super.key});

  @override
  State<AddMusic> createState() => _AddMusicState();
}

class _AddMusicState extends State<AddMusic> {
  TextEditingController songNameController = TextEditingController();
  TextEditingController artistController = TextEditingController();
  DateTime? _releasedDate;

  // Holds the selected file (either XFile or PlatformFile)
  dynamic _selectedFile; 

  String? _audioUrl; // Final URL for playback

  final AudioPlayer _audioPlayer = AudioPlayer();
  final bool _isWeb = kIsWeb;

  @override
  void dispose() {
    _audioPlayer.dispose();
    songNameController.dispose();
    artistController.dispose();
    super.dispose();
  }

  // --- FILE PICKER LOGIC (Platform-Agnostic) ---

  Future<void> pickFile() async {
    // Allows selection of videos and MP3s directly
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [...videoExtensions, 'mp3'],
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      setState(() {
        // Store the PlatformFile (web) or the path/name for native File creation
        _selectedFile = _isWeb ? file : io.File(file.path!);
        _audioUrl = null; 
      });
      Api().showMessage(
        context,
        'File selected: ${file.name}',
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

    // Determine file extension and whether conversion is needed
    String originalFileName;
    String fileExtension;
    
    if (_isWeb && _selectedFile is PlatformFile) {
        originalFileName = (_selectedFile as PlatformFile).name;
    } else if (!_isWeb && _selectedFile is io.File) {
        originalFileName = (_selectedFile as io.File).path.split('/').last;
    } else {
        originalFileName = 'unknown.file'; // Fallback
    }

    fileExtension = originalFileName.split('.').last.toLowerCase();
    final isVideo = videoExtensions.contains(fileExtension);
    
    try {
      Uint8List finalAudioBytes;
      
      if (isVideo) {
        // --- SCENARIO 1: VIDEO (Needs Conversion via Django API) ---
        finalAudioBytes = await _convertToAudioBytes(originalFileName);
      } else if (fileExtension == 'mp3') {
        // --- SCENARIO 2: MP3 AUDIO (Read bytes directly) ---
        if (_selectedFile is io.File) {
            finalAudioBytes = await (_selectedFile as io.File).readAsBytes();
        } else if (_selectedFile is PlatformFile && (_selectedFile as PlatformFile).bytes != null) {
            finalAudioBytes = (_selectedFile as PlatformFile).bytes!;
        } else {
            throw Exception('Could not read audio file data.');
        }
      } else {
        throw Exception('Unsupported file type: .$fileExtension');
      }

      // 2. Upload the final audio bytes to Firebase Storage
      final finalAudioUrl = await _uploadBytesToFirebase(finalAudioBytes, songNameController.text);

      // 3. Save to Firestore
      await FirebaseFirestore.instance.collection('tact_music').add({
        "songName": songNameController.text,
        "artist": artistController.text,
        "songUrl": finalAudioUrl,
        "released": _releasedDate != null ? Timestamp.fromDate(_releasedDate!) : null,
        "category": category,
      });

      // Update local state and UI
      setState(() {
        _audioUrl = finalAudioUrl;
        _selectedFile = null; 
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
      Navigator.pop(context); // Dismiss loading dialog
    }
  }

  // --- DJANGO CONVERSION API CALL (Modified to return bytes) ---
  // NOTE: This will only work on native if the selected file path is accessible (which it should be).
  // On web, this relies on the browser streaming the file contents during the Multipart request.

  Future<Uint8List> _convertToAudioBytes(String originalFileName) async {
    final uri = Uri.parse('https://tact-api.up.railway.app/extract-audio/');
    final request = http.MultipartRequest('POST', uri);

    // Platform-aware file loading for MultipartRequest
    if (_selectedFile is io.File) {
        // Native (dart:io): Use fromPath
        final fileExtension = originalFileName.split('.').last;
        request.files.add(await http.MultipartFile.fromPath(
            'video_file', _selectedFile!.path,
            contentType: MediaType('video', fileExtension)));
    } else if (_selectedFile is PlatformFile && (_selectedFile as PlatformFile).bytes != null) {
        // Web (PlatformFile): Use fromBytes
        request.files.add(http.MultipartFile.fromBytes(
            'video_file', (_selectedFile as PlatformFile).bytes!,
            filename: originalFileName,
            contentType: MediaType('video', originalFileName.split('.').last)));
    } else {
        throw Exception('File data inaccessible for conversion.');
    }

    try {
      final streamedResponse = await request.send().timeout(const Duration(minutes: 5));

      if (streamedResponse.statusCode != 201 && streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        throw Exception('Conversion failed (${streamedResponse.statusCode}): $responseBody');
      }

      // Return bytes directly without saving a local file
      return await streamedResponse.stream.toBytes();

    } on TimeoutException {
      throw Exception('Conversion timed out. The file might be too large or the server is slow.');
    } catch (e) {
      throw Exception('Conversion and download error: ${e.toString()}');
    }
  }

  // --- FIREBASE STORAGE UPLOAD (Modified for Bytes) ---
  Future<String> _uploadBytesToFirebase(Uint8List audioBytes, String songName) async {
    final cleanName = songName.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
    final fileName = '${cleanName}_${DateTime.now().millisecondsSinceEpoch}.mp3';
    
    final ref = FirebaseStorage.instance.ref().child('songs').child(fileName);

    final uploadTask = ref.putData(
      audioBytes,
      SettableMetadata(contentType: 'audio/mpeg'),
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
    'Slow Jam', 'Apostle choir', 'choreography', 'Instrumental songs',
  ];
  String category = '';

  // --- WIDGET BUILDER ---

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final selectedFileName = (_selectedFile is io.File) 
        ? (_selectedFile as io.File).path.split('/').last 
        : (_selectedFile is PlatformFile) 
            ? (_selectedFile as PlatformFile).name 
            : null;
    
    final isVideoFile = selectedFileName != null && videoExtensions.contains(selectedFileName.split('.').last.toLowerCase());

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: ListView(
            children: [
              // 1. File Picker Card
              Center(
                child: Card(
                  elevation: 10,
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: pickFile,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: SweepGradient(
                          transform: const GradientRotation(5),
                          center: Alignment.center,
                          startAngle: 0.1,
                          endAngle: 10,
                          colors: [
                            color.primaryColor.withOpacity(0.9),
                            color.hintColor,
                            color.primaryColor,
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
                            _selectedFile == null ? Ionicons.add_sharp : isVideoFile ? Ionicons.videocam_outline : Ionicons.musical_notes_outline,
                            size: 50,
                            color: color.scaffoldBackgroundColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFile == null
                                ? 'Tap to Select Video/Audio'
                                : (isVideoFile ? 'Video Selected (Needs Conversion)' : 'Audio Selected (MP3)'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color.scaffoldBackgroundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (selectedFileName != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                selectedFileName,
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
              SizedBox(height: 30),

              // 2. Input Fields
              CupertinoTextField(
                controller: songNameController,
                placeholder: 'Please enter the song name',
                keyboardType: TextInputType.name,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(width: 1, color: color.primaryColor.withOpacity(0.5)),
                  color: color.cardColor,
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
                  border: Border.all(width: 1, color: color.primaryColor.withOpacity(0.5)),
                  color: color.cardColor,
                ),
              ),
              SizedBox(height: 10),
              
              // 3. Category Selection
              ExpansionTile(
                title: Text(
                  category.isEmpty ? 'Select category' : category,
                  style: TextStyle(color: color.primaryColor, fontWeight: FontWeight.w500),
                ),
                children: [
                  ...categories.map((userRole) => RadioListTile<String>(
                        value: userRole,
                        groupValue: category,
                        onChanged: (val) {
                          setState(() => category = val as String);
                        },
                        title: Text(userRole),
                        activeColor: color.primaryColor,
                      ))
                      .toList(),
                ],
              ),

              SizedBox(height: 10),
              
              // 4. Date Picker
              GestureDetector(
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _releasedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                        // Apply custom theme to DatePicker dialog
                        return Theme(
                            data: color.copyWith(
                                colorScheme: ColorScheme.light(
                                    primary: color.primaryColor, // Header background
                                    onPrimary: color.scaffoldBackgroundColor, // Header text
                                    onSurface: color.textTheme.bodyLarge?.color ?? Colors.black, // Calendar text
                                ),
                            ), 
                            child: child!,
                        );
                    },
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
                    border: Border.all(width: 1, color: color.primaryColor.withOpacity(0.5)),
                    color: color.cardColor,
                  ),
                  child: Text(
                    _releasedDate != null
                        ? 'Released Date: ${_releasedDate!.toLocal().toString().split(' ')[0]}'
                        : 'Please select the released date',
                    style: TextStyle(color: color.primaryColor, fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // 5. Play Preview Button (Visible after successful upload)
              if (_audioUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: playAudio,
                      icon: const Icon(Ionicons.play_circle_outline),
                      label: Text('Play Audio Preview'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.splashColor,
                        foregroundColor: color.scaffoldBackgroundColor,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                ),

              // 6. Upload Button
              CustomOutlinedButton(
                onPressed: uploadSong,
                text: 'Upload Song',
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                width: double.infinity,
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}