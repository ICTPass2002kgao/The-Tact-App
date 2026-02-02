// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' hide AudioPlayer;
import 'package:permission_handler/permission_handler.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

import 'package:ttact/Pages/Admin/Admin_Portal.dart';
import 'package:ttact/Pages/Overseer/Overseer_Page.dart';
import 'package:ttact/Pages/tactso_pages/Tactso_Branches_Applications.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String entityUid;
  final String role;
  final CameraDescription camera;

  // Now we expect a SINGLE faceUrl because Django told us exactly who logged in
  final String? faceUrl;
  final String? loggedMemberName;
  final String? loggedMemberRole;

  const FaceVerificationScreen({
    super.key,
    required this.entityUid,
    required this.camera,
    required this.email,
    required this.password,
    required this.role,
    this.faceUrl,
    this.loggedMemberName,
    this.loggedMemberRole,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late FlutterTts _flutterTts;
  late AudioPlayer _audioPlayer;
  final Api _api = Api();

  bool _isVerifying = false;
  String _processStatus = "Initializing...";

  bool _isCameraInitialized = false;
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _audioPlayer = AudioPlayer();
    _flutterTts = FlutterTts();

    _initializeCamera();
  }

  // ... (Keep _initializeCamera, playSound exactly as they were) ...
  Future<void> playSound(bool isSuccess) async {
    try {
      String fileName = isSuccess ? 'success.mp3' : 'denied.mp3';
      await _audioPlayer.play(AssetSource(fileName));
    } catch (e) {
      print("Audio Error: $e");
    }
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        await Permission.camera.request();
      }
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception("No cameras found");
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _processStatus = "Ready";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _processStatus = "Camera Error: $e";
        });
      }
    }
  }

  // --- UPDATED VERIFICATION LOGIC ---
  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_isVerifying) return;

    if (widget.faceUrl == null) {
      _api.showMessage(
        context,
        'Security Error: No reference face loaded.',
        'Error',
        Colors.red,
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _processStatus = 'Scanning...';
    });

    try {
      final XFile capturedFile = await _cameraController!.takePicture();

      // 1-to-1 Match: Verify captured image against the profile image from Django
      final result = await _compareFaces(capturedFile, widget.faceUrl!);

      if (result['matched'] == true) {
        // Prepare data for routing
        Map<String, dynamic> userData = {
          'fullName': widget.loggedMemberName,
          'role': widget.loggedMemberRole ?? widget.role,
          'faceUrl': widget.faceUrl,
          'province': 'Unknown', // Django can pass this if needed
        };
        await _finalizeLogin(userData);
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
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/verify_faces/'),
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
        return json['matched'] == true ? {'matched': true} : {'matched': false};
      }
      return {'matched': false};
    } catch (e) {
      return {'matched': false};
    }
  }

  // --- ROUTING LOGIC ---
  Future<void> _finalizeLogin(Map<String, dynamic> userData) async {
    setState(() => _processStatus = "Logging in...");
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );
      }
      if (!mounted) return;
      await playSound(true);
      _api.showMessage(context, 'Welcome, ✅', 'Access Granted', Colors.green);

      Widget nextScreen;
      String displayName = userData['fullName'] ?? 'User';
      String displayRole = userData['role'] ?? 'Member';
      String displayImg = userData['faceUrl'] ?? '';
      String displayProvince = userData['province'] ?? '';

      // --- 1. ADMIN ROUTING ---
      if (widget.role == 'Admin') {
        nextScreen = AdminPortal(
          fullName: displayName,
          portfolio: displayRole,
          province: displayProvince,
          faceUrl: displayImg,
        );
      }
      // --- 2. OVERSEER ROUTING ---
      else if (widget.role == 'Overseer') {
        nextScreen = OverseerPage(
          loggedMemberName: displayName,
          loggedMemberRole: displayRole,
          faceUrl: displayImg,
        );
      }
      // --- 3. TACTSO BRANCH ROUTING ---
      else {
        nextScreen = TactsoBranchesApplications(
          loggedMemberName: displayName,
          loggedMemberRole: displayRole,
          faceUrl: displayImg,
        );
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => nextScreen),
        (route) => false,
      );
    } catch (e) {
      _handleFailure();
    }
  }

  void _handleFailure() async {
    if (!mounted) return;
    await playSound(false);
    setState(() {
      _isVerifying = false;
      _processStatus = "Face not recognized.";
    });
    await FirebaseAuth.instance.signOut();
    _api.showMessage(context, "Access denied.", 'Denied', Colors.red);
    await Future.delayed(Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _processStatus = "Ready";
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scannerController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // --- UI BUILD (EXACTLY AS PROVIDED, NO CHANGES) ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    final Color primaryColor = theme.primaryColor;
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final Color hintColor = theme.hintColor;

    return Scaffold(
      backgroundColor: neumoBaseColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: NeumorphicContainer(
              color: neumoBaseColor,
              borderRadius: 12,
              padding: const EdgeInsets.all(0),
              child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
            ),
          ),
        ),
        title: Text(
          'Verification',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDetailsPanel(neumoBaseColor, textColor, hintColor),
                const SizedBox(height: 40),
                if (_isVerifying)
                  _buildProcessingPanel(neumoBaseColor, textColor, primaryColor)
                else
                  _buildLiveCamPanel(neumoBaseColor, textColor, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... (Helper widgets _buildDetailsPanel, _buildLiveCamPanel, etc. remain unchanged)
  // [I have omitted them for brevity as requested to maintain design, but they should be pasted here from your original code]

  // PASTE _buildDetailsPanel, _buildLiveCamPanel, _buildProcessingPanel, _sectionTitle HERE from your previous code.
  Widget _buildDetailsPanel(Color baseColor, Color textColor, Color hintColor) {
    return NeumorphicContainer(
      color: baseColor,
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hintColor.withOpacity(0.1)),
            ),
            child: widget.faceUrl != null && widget.faceUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(widget.faceUrl!, fit: BoxFit.cover),
                  )
                : Icon(Icons.person, color: hintColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.role,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.loggedMemberName ?? 'Identity Verification',
                  style: GoogleFonts.poppins(color: hintColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCamPanel(
    Color baseColor,
    Color textColor,
    Color primaryColor,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      padding: const EdgeInsets.all(24),
      borderRadius: 20,
      child: Column(
        children: <Widget>[
          _sectionTitle('Live Scan', primaryColor, textColor),
          const SizedBox(height: 10),
          Text(
            _isCameraInitialized
                ? 'Align your face within the frame.'
                : 'Initializing camera system...',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 40),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [baseColor.withOpacity(0.5), baseColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 20,
                      offset: const Offset(10, 10),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(-5, -5),
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Container(
                  width: 220,
                  height: 300,
                  color: Colors.black,
                  child: _isCameraInitialized
                      ? AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        )
                      : Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                ),
              ),
              if (_isCameraInitialized)
                Positioned.fill(
                  child: ClipOval(
                    child: AnimatedBuilder(
                      animation: _scannerController,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment(
                            0,
                            _scannerController.value * 2 - 1,
                          ),
                          child: Container(
                            height: 4,
                            width: 220,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.green,
                                  Colors.green,
                                  Colors.green.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.green,
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _captureAndVerify,
            child: NeumorphicContainer(
              color: primaryColor,
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Start Face Match',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingPanel(
    Color baseColor,
    Color textColor,
    Color primaryColor,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      borderRadius: 20,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              builder: (context, val, _) {
                return Transform.scale(
                  scale: 1.0 + (0.1 * val),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.fingerprint_outlined,
                      size: 60,
                      color: primaryColor,
                    ),
                  ),
                );
              },
              onEnd: () {},
            ),
            const SizedBox(height: 40),
            Text(
              "Processing...",
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _processStatus,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                backgroundColor: baseColor,
                color: Colors.green,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color primaryColor, Color textColor) {
    return Row(
      children: [
        Container(
          height: 25,
          width: 4,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
