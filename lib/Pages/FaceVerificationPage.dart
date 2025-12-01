import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb and defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Required for iOS widgets
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' hide AudioPlayer;
import 'package:permission_handler/permission_handler.dart';

// Keep your existing imports
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Tactso_Branches_Applications.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final List<String> authorizedFaceUrls;
  final String universityUID;
  final CameraDescription camera;

  const FaceVerificationScreen({
    super.key,
    required this.authorizedFaceUrls,
    required this.universityUID,
    required this.camera,
    required this.email,
    required this.password,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  late CameraController _cameraController;

  // 1. UPDATE: Define TTS as a class variable
  late FlutterTts _flutterTts;
  late AudioPlayer _audioPlayer;
  final Api _api = Api();
  bool _isVerifying = false;
  String _statusMessage = 'Initializing camera...';

  // Helper to check if we should use iOS style
  bool get _isIOS =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static const String _verificationApiEndpoint =
      'https://tact-api.up.railway.app/api/verify_faces/';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _audioPlayer = AudioPlayer();
  }

  Future<void> playSound(bool isSuccess) async {
    try {
      // Assuming you put files in assets/sounds/
      String fileName = isSuccess ? 'success.mp3' : 'denied.mp3';

      // Play the file
      await _audioPlayer.play(AssetSource(fileName));
    } catch (e) {
      print("Audio Error (Ignored): $e");
    }
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      var status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        _handlePermissionDenied(status.isPermanentlyDenied);
        return;
      }
    }

    CameraDescription selectedCamera = widget.camera;
    if (selectedCamera.lensDirection != CameraLensDirection.front) {
      try {
        final available = await availableCameras();
        selectedCamera = available.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => widget.camera,
        );
      } catch (_) {}
    }

    _cameraController = CameraController(
      selectedCamera,
      kIsWeb ? ResolutionPreset.high : ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Camera ready. Align your face.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Camera Error: $e';
      });
    }
  }

  void _handlePermissionDenied(bool isPermanent) {
    if (mounted) {
      setState(() => _statusMessage = 'Permission denied.');
      _api.showMessage(
        context,
        'Camera permission is required.',
        'Error',
        Colors.red,
      );
    }
  }

  Future<void> _verifyFace() async {
    if (_isVerifying || !_cameraController.value.isInitialized) return;

    if (widget.authorizedFaceUrls.isEmpty) {
      _api.showMessage(
        context,
        'No authorized faces found.',
        'Error',
        Colors.red,
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Verifying...';
    });

    try {
      final XFile capturedFile = await _cameraController.takePicture();
      final String refImageUrl = widget.authorizedFaceUrls.first;

      final result = await _compareFaces(capturedFile, refImageUrl);

      if (result['matched'] == true) {
        // 4. UPDATE: Await the success handler
        await _handleSuccess();
      } else {
        _handleFailure();
      }
    } catch (e) {
      _handleFailure();
    }
  }

  Future<Map<String, dynamic>> _compareFaces(
    XFile capturedImage,
    String referenceImageUrl,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(_verificationApiEndpoint),
      );
      request.fields['reference_url'] = referenceImageUrl;

      final Uint8List imageBytes = await capturedImage.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'live_image',
          imageBytes,
          filename: 'face_scan.jpg',
        ),
      );

      var response = await request.send();
      final respString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(respString);
        return json['matched'] == true
            ? {'matched': true}
            : {
                'matched': false,
                'error_message': json['message'] ?? json['error'],
              };
      }
      return {
        'matched': false,
        'error_message': 'Server Error: ${response.statusCode}',
      };
    } catch (e) {
      return {'matched': false, 'error_message': 'Connection Error'};
    }
  }

  // 6. UPDATE: Make this async and wait for speech
  Future<void> _handleSuccess() async {
    if (!mounted) return;
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: widget.email,
      password: widget.password,
    );
    // Speak FIRST
    await playSound(true);

    // Then show message
    _api.showMessage(context, 'Identity Verified.', 'Success', Colors.green);

    // Then navigate
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const TactsoBranchesApplications(),
        ),
        (route) => false,
      );
    }
  }

  void _handleFailure() async {
    if (!mounted) return;

    // We don't await here because we aren't navigating away instantly
    await playSound(true);

    setState(() {
      _isVerifying = false;
    });
    _api.showMessage(context, "Access denied", 'Denied', Colors.red);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _flutterTts.stop(); // Good practice to stop TTS
    super.dispose();
  }

  // --- BUILD METHODS (UNCHANGED) ---

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return _buildCupertinoPage(context);
    } else {
      return _buildMaterialPage(context);
    }
  }

  Widget _buildMaterialPage(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Biometric Check 📸',
          style: TextStyle(color: Colors.black87),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBodyContent(context),
    );
  }

  Widget _buildCupertinoPage(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Biometric Check'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        border: null,
      ),
      child: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      final color = Theme.of(context);
      return Center(
        child: Container(
          decoration: BoxDecoration(
            color: color.primaryColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: color.primaryColor.withOpacity(0.7),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator.adaptive(),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  style: _isIOS
                      ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          color: CupertinoColors.systemGrey,
                        )
                      : Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final color = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.primaryColor, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Container(
                    height: 250,
                    width: 180,
                    child: ClipOval(child: CameraPreview(_cameraController)),
                  ),
                ),

                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: _isIOS
                        ? CupertinoTheme.of(
                            context,
                          ).textTheme.navLargeTitleTextStyle.copyWith(
                            fontSize: 18,
                            color: _isVerifying
                                ? CupertinoColors.systemGrey
                                : CupertinoColors.black,
                            fontWeight: FontWeight.w600,
                          )
                        : Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            color: _isVerifying
                                ? Colors.grey.shade600
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                  ),
                ),

                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  child: _buildAdaptiveButton(
                    context: context,
                    text: _isVerifying
                        ? 'Verifying Identity...'
                        : 'Verify Face',
                    onPressed: _isVerifying ? null : _verifyFace,
                    isLoading: _isVerifying,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveButton({
    required BuildContext context,
    required String text,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    if (_isIOS) {
      final size = MediaQuery.of(context).size.width;
      return CupertinoButton.filled(
        minimumSize: Size(size > 600 ? 400 : double.infinity, 60),
        sizeStyle: CupertinoButtonSize.large,
        color: Theme.of(context).primaryColor,
        onPressed: onPressed,
        disabledColor: CupertinoColors.systemGrey3,
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: isLoading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.face_retouching_natural, size: 28),
        label: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          elevation: 4,
          shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      );
    }
  }
}
