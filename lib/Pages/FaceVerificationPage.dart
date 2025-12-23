import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' hide AudioPlayer;
import 'package:permission_handler/permission_handler.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Admin/Admin_Portal.dart';
import 'package:ttact/Pages/Overseer/Overseer_Page.dart';
import 'package:ttact/Pages/User/Tactso_Branches_Applications.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String entityUid; // Kept for reference, but verification is now dynamic
  final String role; // 'Admin', 'Overseer', or 'Tactso Branch'
  final CameraDescription camera;

  // Optional params (can be null now that we fetch dynamically)
  final List<String>? authorizedFaceUrls;
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl;

  const FaceVerificationScreen({
    super.key,
    required this.entityUid,
    required this.camera,
    required this.email,
    required this.password,
    this.role = 'Tactso Branch',
    this.authorizedFaceUrls,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.faceUrl,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  late CameraController _cameraController;
  late FlutterTts _flutterTts;
  late AudioPlayer _audioPlayer;
  final Api _api = Api();

  bool _isVerifying = false;
  String _statusMessage = 'Initializing camera...';

  // --- NEW: List to hold all potential staff members ---
  List<Map<String, dynamic>> _allStaffList = [];
  bool _isLoadingStaff = true;

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
    _flutterTts = FlutterTts();

    // --- NEW: Load all staff members immediately ---
    if (widget.role == 'Admin') {
      _fetchAllStaffMembers();
    } else {
      // If not Admin, we might rely on the old method or just skip this
      setState(() => _isLoadingStaff = false);
    }
  }

  // --- NEW: Fetch Logic ---
  Future<void> _fetchAllStaffMembers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_members')
          .get();

      List<Map<String, dynamic>> tempStaff = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Only add if they have a faceUrl
        if (data['faceUrl'] != null && data['faceUrl'].toString().isNotEmpty) {
          tempStaff.add({
            'fullName':
                data['fullName'] ?? "${data['name']} ${data['surname']}",
            'portfolio': data['portfolio'] ?? 'Staff',
            'province': data['province'] ?? 'Unknown',
            'faceUrl': data['faceUrl'],
            'role': data['role'] ?? 'Admin',
            'uid': data['uid'], // Useful if you need to reference the doc later
          });
        }
      }

      if (mounted) {
        setState(() {
          _allStaffList = tempStaff;
          _isLoadingStaff = false;
        });
        print("Loaded ${_allStaffList.length} staff members for verification.");
      }
    } catch (e) {
      print("Error fetching staff: $e");
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  Future<void> playSound(bool isSuccess) async {
    try {
      String fileName = isSuccess ? 'success.mp3' : 'denied.mp3';
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
      setState(() => _statusMessage = 'Camera ready. Align your face.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Camera Error: $e');
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

    // Check if we have staff loaded
    if (widget.role == 'Admin' && _allStaffList.isEmpty) {
      // Fallback to widget.authorizedFaceUrls if list is empty
      if (widget.authorizedFaceUrls == null ||
          widget.authorizedFaceUrls!.isEmpty) {
        _api.showMessage(
          context,
          'No staff members found in database.',
          'Error',
          Colors.red,
        );
        return;
      }
    }

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Verifying Identity...';
    });

    try {
      final XFile capturedFile = await _cameraController.takePicture();

      Map<String, dynamic>? matchedUser;

      // --- UPDATED LOOP: Iterate through _allStaffList ---
      if (widget.role == 'Admin' && _allStaffList.isNotEmpty) {
        for (var staffMember in _allStaffList) {
          String refUrl = staffMember['faceUrl'];

          // Compare against API
          final result = await _compareFaces(capturedFile, refUrl);

          if (result['matched'] == true) {
            matchedUser = staffMember;
            break; // Stop loop immediately on match
          }
        }
      } else {
        // Fallback for other roles or if local list is empty (using passed List)
        if (widget.authorizedFaceUrls != null) {
          for (String refUrl in widget.authorizedFaceUrls!) {
            final result = await _compareFaces(capturedFile, refUrl);
            if (result['matched'] == true) {
              // Create a dummy user map since we don't have details

      final snapshot = await FirebaseFirestore.instance
          .collection('staff_members').where(   'faceUrl', isEqualTo: refUrl)
          .get();

              matchedUser = { 
                'fullName': snapshot.docs.isNotEmpty
                    ? snapshot.docs.first.data()['fullName']
                    : 'Authorized User',
                'portfolio': snapshot.docs.isNotEmpty
                    ? snapshot.docs.first.data()['portfolio']
                    : 'Staff',
                'province': snapshot.docs.isNotEmpty
                    ? snapshot.docs.first.data()['province']
                    : 'Unknown',
                'faceUrl': refUrl,
              };
              break;
            }
          }
        }
      }

      if (matchedUser != null) {
        await _finalizeLogin(matchedUser);
      } else {
        _handleFailure();
      }
    } catch (e) {
      print("Verification Error: $e");
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
        return json['matched'] == true ? {'matched': true} : {'matched': false};
      }
      return {'matched': false};
    } catch (e) {
      return {'matched': false};
    }
  }

  // --- NEW: Finalize Login with Specific Data ---
  Future<void> _finalizeLogin(Map<String, dynamic> userData) async {
    setState(() => _statusMessage = "Logging in...");

    try {
      // Ensure Auth session exists
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );
      }

      if (!mounted) return;
      await playSound(true);

      _api.showMessage(
        context,
        'Welcome, ${userData['fullName']}',
        'Access Granted',
        Colors.green,
      );

      // Navigate
      Widget nextScreen;
      if (widget.role == 'Admin') {
        nextScreen = AdminPortal(
          // Pass the specific data we found in the list!
          fullName: userData['fullName'],
          portfolio: userData['portfolio'],
          province: userData['province'],
          faceUrl: userData['faceUrl'],
        );
      } else if (widget.role == 'Overseer') {
        nextScreen = OverseerPage(
          loggedMemberName: userData['fullName'],
          loggedMemberRole: userData['portfolio'],
          faceUrl: userData['faceUrl'],
        );
      } else {
        nextScreen = TactsoBranchesApplications(
          loggedMemberName: userData['fullName'],
          loggedMemberRole: userData['portfolio'],
          faceUrl: userData['faceUrl'],
        );
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => nextScreen),
        (route) => false,
      );
    } catch (e) {
      print("Login Error: $e");
      _handleFailure();
    }
  }

  void _handleFailure() async {
    if (!mounted) return;
    await playSound(false);
    setState(() {
      _isVerifying = false;
      _statusMessage = "Face not recognized. Try again.";
    });
    // Optional: Sign out if you want strict security
    await FirebaseAuth.instance.signOut();
    _api.showMessage(
      context,
      "Access denied. Face not authorized.",
      'Denied',
      Colors.red,
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

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
        title: Text(
          '${widget.role} Verification 📸',
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
      navigationBar: CupertinoNavigationBar(
        middle: Text('${widget.role} Check'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
        border: null,
      ),
      child: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 20),
            Text(_statusMessage),
          ],
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

                // Show loading indicator if fetching staff
                if (_isLoadingStaff && widget.role == 'Admin')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      "Loading Staff Database...",
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    text: _isVerifying ? 'Verifying...' : 'Verify Face',
                    onPressed: (_isVerifying || _isLoadingStaff)
                        ? null
                        : _verifyFace,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      );
    }
  }
}
