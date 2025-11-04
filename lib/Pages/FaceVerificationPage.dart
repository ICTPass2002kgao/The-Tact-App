import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Tactso_Branches_Applications.dart' hide Api;

class FaceVerificationScreen extends StatefulWidget {
  final List<String> authorizedFaceUrls;
  final String universityUID;
  final CameraDescription camera;

  const FaceVerificationScreen({
    super.key,
    required this.authorizedFaceUrls,
    required this.universityUID,
    required this.camera,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  late CameraController _cameraController;
  final Api _api = Api();
  bool _isVerifying = false;
  String _statusMessage = 'Initializing camera...';

  static const String _verificationApiEndpoint =
      'https://tact-api.up.railway.app/api/verify_faces/';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // MODIFIED: Handles runtime permission request
  Future<void> _initializeCamera() async {
    // 1. REQUEST CAMERA PERMISSION
    var status = await Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Permission denied. Tap to open settings.';
        });
        _api.showMessage(
          context,
          'Camera access is required for face verification. Please grant permission in settings.',
          'Permission Denied',
          Colors.red,
        );
      }
      if (status.isPermanentlyDenied) {
        await Future.delayed(const Duration(milliseconds: 500));
        await openAppSettings();
      }
      return;
    }

    // 2. CAMERA SELECTION LOGIC
    CameraDescription selectedCamera = widget.camera;

    if (selectedCamera.lensDirection != CameraLensDirection.front) {
      final available = await availableCameras();
      try {
        selectedCamera = available.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        debugPrint("Switched to front camera for face verification.");
      } catch (e) {
        if (mounted) {
          _api.showMessage(
            context,
            'Front camera not found. Using default camera.',
            'Warning',
            Colors.orange,
          );
        }
      }
    }

    // 3. CAMERA INITIALIZATION LOGIC (Increased resolution for better face detection)
    _cameraController = CameraController(
      selectedCamera,
      ResolutionPreset.high, // Set to high for better HOG/CNN input
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Selfie camera ready. Tap to start verification.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error initializing camera: $e';
      });
      _api.showMessage(context, 'Camera Init Failed: $e', 'Error', Colors.red);
    }
  }

  // MODIFIED: Logic now ONLY checks the first authorized face URL
  Future<void> _verifyFace() async {
    if (_isVerifying || !_cameraController.value.isInitialized) {
      if (_statusMessage.contains('Permission denied')) {
        await openAppSettings();
      }
      return;
    }

    if (widget.authorizedFaceUrls.isEmpty) {
      if (!mounted) return;
      _api.showMessage(
        context,
        'No authorized faces are stored for this university. Access denied.',
        'Configuration Error',
        Colors.red,
      );
      setState(() {
        _statusMessage = 'Verification Failed: No face URLs stored.';
        _isVerifying = false;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Capturing image and verifying face...';
    });

    try {
      final XFile file = await _cameraController.takePicture();
      final File capturedImage = File(file.path);

      // MODIFICATION: Only check the first face URL
      final String refImageUrl = widget.authorizedFaceUrls.first;
      bool matchFound = false;
      String lastErrorMessage = 'No match found for the authorized user.';

      final result = await _compareFaces(capturedImage, refImageUrl);

      if (result['matched'] == true) {
        matchFound = true;
        debugPrint("✅ MATCH SUCCESS on face: $refImageUrl");
      } else if (result['error_message'] != null) {
        lastErrorMessage = result['error_message'];
        debugPrint(
          "❌ Match attempt failed. Reason: ${result['error_message']}",
        );
      }

      if (matchFound) {
        if (!mounted) return;
        _api.showMessage(
          context,
          'Face matched! Access granted.',
          'Success',
          Colors.green,
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const TactsoBranchesApplications(),
          ),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        _api.showMessage(
          context,
          lastErrorMessage,
          'Access Denied',
          Colors.red,
        );
        setState(() {
          _statusMessage =
              'Verification Failed: ${lastErrorMessage.split(':')[0]}. Tap to try again.';
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _api.showMessage(
        context,
        'Application Error: ${e.toString()}',
        'Error',
        Colors.red,
      );
      setState(() {
        _statusMessage = 'Verification failed. App Error: ${e.runtimeType}';
        _isVerifying = false;
      });
    }
  }

  Future<Map<String, dynamic>> _compareFaces(
    File capturedImage,
    String referenceImageUrl,
  ) async {
    debugPrint('Comparing live image against: $referenceImageUrl');

    try {
      var request =
          http.MultipartRequest('POST', Uri.parse(_verificationApiEndpoint))
            ..fields['reference_url'] = referenceImageUrl
            ..files.add(
              await http.MultipartFile.fromPath(
                'live_image',
                capturedImage.path,
              ),
            );

      var response = await request.send();
      final respJsonString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final respJson = jsonDecode(respJsonString);

        if (respJson['matched'] == true) {
          return {'matched': true, 'error_message': null};
        } else {
          // MODIFIED: Ensure we check 'error' key from Python API
          final message =
              respJson['error'] ?? respJson['message'] ?? 'No face match.';
          return {
            'matched': false,
            'error_message': 'Verification Failed: $message',
          };
        }
      } else {
        debugPrint('API Error ${response.statusCode}: $respJsonString');
        String apiError =
            'API Error ${response.statusCode}. Check server logs.';
        try {
          final errorJson = jsonDecode(respJsonString);
          apiError = errorJson['error'] ?? errorJson['message'] ?? apiError;
        } catch (_) {}
        return {
          'matched': false,
          'error_message': 'API Call Failed: $apiError',
        };
      }
    } catch (e) {
      return {
        'matched': false,
        'error_message':
            'Network Error: Check internet connection or API domain.',
      };
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    // FIX: Handle Initialization State
    if (!_cameraController.value.isInitialized) {
      final bool isPermissionIssue = _statusMessage.contains(
        'Permission denied',
      );

      return Scaffold(
        appBar: AppBar(title: const Text('Face Verification')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isPermissionIssue) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPermissionIssue ? Colors.red : Colors.black,
                  fontWeight: isPermissionIssue
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              if (isPermissionIssue) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open App Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // --- CAMERA SCALING CALCULATION (Unchanged) ---
    final double containerWidth = 250;
    final double containerHeight = 350;

    final previewAspectRatio = _cameraController.value.aspectRatio;
    final desiredAspectRatio = containerWidth / containerHeight;

    double scale = 1.0;

    if (previewAspectRatio > desiredAspectRatio) {
      scale = containerHeight / (containerWidth / previewAspectRatio);
    } else {
      scale = containerWidth / (containerHeight * previewAspectRatio);
    }
    // --- END CAMERA SCALING CALCULATION ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Biometric Check 📸'),
        centerTitle: true,
        foregroundColor: color.scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Camera Preview in a rounded container
              Container(
                width: 250,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(300),
                  border: Border.all(color: Colors.green, width: 4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(300),
                  child: SizedBox(
                    width: containerWidth,
                    height: containerHeight,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..scale(-1.0, 1.0),
                        child: AspectRatio(
                          aspectRatio: _cameraController.value.aspectRatio,
                          child: CameraPreview(_cameraController),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _isVerifying ? Colors.orange : Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              // Verification Button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton.icon(
                  onPressed: _isVerifying ? null : _verifyFace,
                  icon: Icon(_isVerifying ? Icons.lock_clock : Icons.face),
                  label: Text(
                    _isVerifying ? 'Verifying...' : 'Capture & Verify Face',
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: _isVerifying
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),

                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Authorized User: ${widget.authorizedFaceUrls.isNotEmpty ? '1 face targeted' : 'No face stored'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
