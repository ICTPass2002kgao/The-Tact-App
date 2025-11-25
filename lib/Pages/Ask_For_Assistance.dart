// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print, use_key_in_widget_constructors, unused_import, prefer_final_fields

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:flutter/foundation.dart';

// FIX: Use io.File alias for platform safety
import 'dart:io' as io show File;

// Assuming CustomOutlinedButton is defined, but we will use local platform builders for buttons
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/ViewApplicationsBottomSheet.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseStorage _storage = FirebaseStorage.instance;

// --- LOGIN BOTTOM SHEET ---
class _LoginBottomSheet extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const _LoginBottomSheet({required this.onLoginSuccess});

  @override
  State<_LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<_LoginBottomSheet> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Widget _buildPlatformTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    if (isIOSPlatform) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          keyboardType: keyboardType,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(icon, color: CupertinoColors.systemGrey),
          ),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: placeholder,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }
  }

  Widget _buildPlatformButton({
    required VoidCallback onPressed,
    required String text,
    required Color backgroundColor,
  }) {
    if (isIOSPlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          disabledColor: CupertinoColors.quaternarySystemFill,
          child: Text(text, style: TextStyle(color: CupertinoColors.white)),
          color: backgroundColor,
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 20, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlatformTextField(
            controller: emailController,
            placeholder: 'Enter your email',
            icon: isIOSPlatform ? CupertinoIcons.mail : Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          _buildPlatformTextField(
            controller: passwordController,
            placeholder: 'Password',
            icon: isIOSPlatform ? CupertinoIcons.lock : Icons.lock,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _buildPlatformButton(
            onPressed: () async {
              try {
                await _auth.signInWithEmailAndPassword(
                  email: emailController.text,
                  password: passwordController.text,
                );
                widget.onLoginSuccess();
              } on FirebaseAuthException catch (e) {
                Api().showMessage(
                  context,
                  'Login Failed',
                  e.message ?? 'An error occurred',
                  color.primaryColorDark,
                );
              } catch (e) {
                Api().showMessage(
                  context,
                  'Login Failed',
                  e.toString(),
                  color.primaryColorDark,
                );
              }
            },
            text: "Login",
            backgroundColor: color.primaryColor,
          ),
          SizedBox(height: 60),
        ],
      ),
    );
  }
}

// --- MAIN APPLICATION SCREEN ---

class UniversityApplicationScreen extends StatefulWidget {
  final Map<String, dynamic> universityData;
  final Map<String, dynamic>? selectedCampus;

  const UniversityApplicationScreen({
    Key? key,
    required this.universityData,
    this.selectedCampus,
  }) : super(key: key);

  @override
  _UniversityApplicationScreenState createState() =>
      _UniversityApplicationScreenState();
}

class _UniversityApplicationScreenState
    extends State<UniversityApplicationScreen> {
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoadingAuth = false;
  bool _hasExistingApplication = false;
  bool _isFirstApplication = true;

  final _formKey = GlobalKey<FormState>();

  // Files
  dynamic _idPassportFile;
  dynamic _schoolResultsFile;
  dynamic _proofOfRegistrationFile;
  List<dynamic> _otherQualificationFiles = [];
  dynamic _passportPhotoFile;

  // Stored URLs
  String? _idPassportUrl;
  String? _schoolResultsUrl;

  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _physicalAddressController =
      TextEditingController();
  final TextEditingController _previousSchoolsController =
      TextEditingController();
  final TextEditingController _yearCompletionController =
      TextEditingController();
  final TextEditingController _parent1NameController = TextEditingController();
  final TextEditingController _parent1OccupationController =
      TextEditingController();
  final TextEditingController _parent1IncomeController =
      TextEditingController();
  final TextEditingController _parent2NameController = TextEditingController();
  final TextEditingController _parent2OccupationController =
      TextEditingController();
  final TextEditingController _otherPrimaryProgramController =
      TextEditingController();
  final TextEditingController _otherSecondChoiceProgramController =
      TextEditingController();
  final TextEditingController _otherThirdChoiceProgramController =
      TextEditingController();

  String? _highestQualification;
  String? _primaryProgram;
  String? _secondChoiceProgram;
  String? _thirdChoiceProgram;
  String? _preferredStartDate;
  bool _applyingForResidence = false;
  bool _applyingForFunding = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUserAndApplications();
  }

  @override
  void dispose() {
    // Dispose controllers
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _physicalAddressController.dispose();
    _previousSchoolsController.dispose();
    _yearCompletionController.dispose();
    _parent1NameController.dispose();
    _parent1OccupationController.dispose();
    _parent1IncomeController.dispose();
    _parent2NameController.dispose();
    _parent2OccupationController.dispose();
    _otherPrimaryProgramController.dispose();
    _otherSecondChoiceProgramController.dispose();
    _otherThirdChoiceProgramController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUserAndApplications() async {
    setState(() {
      _isLoadingAuth = true;
    });
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _isLoggedIn = true;
      await _fetchUserDetails();
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && userDoc.data()!.containsKey('isFirstApplication')) {
        _isFirstApplication = userDoc.data()!['isFirstApplication'];
      }

      if (!_isFirstApplication) {
        await _preFillApplicationData();
      }

      await _checkExistingApplications();
    } else {
      _isLoggedIn = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginBottomSheet();
      });
    }
    setState(() {
      _isLoadingAuth = false;
    });
  }

  Future<void> _fetchUserDetails() async {
    if (_currentUser != null) {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        _fullNameController.text =
            '${userData['name'] ?? ''} ${userData['surname'] ?? ''}';
        _emailController.text = userData['email'] ?? '';
        _physicalAddressController.text = userData['address'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
      }
      setState(() {});
    }
  }

  Future<void> _preFillApplicationData() async {
    if (_currentUser != null) {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        _previousSchoolsController.text = userData['previousSchools'] ?? '';
        _yearCompletionController.text = userData['yearOfCompletion'] ?? '';
        _parent1NameController.text = userData['parent1Name'] ?? '';
        _parent1OccupationController.text = userData['parent1Occupation'] ?? '';
        _parent1IncomeController.text = userData['parent1Income'] ?? '';
        _parent2NameController.text = userData['parent2Name'] ?? '';
        _parent2OccupationController.text = userData['parent2Occupation'] ?? '';

        final Map<String, dynamic>? profileDocs = userData['profileDocuments'];
        if (profileDocs != null) {
          _idPassportUrl = profileDocs['idPassportUrl'];
          _schoolResultsUrl = profileDocs['schoolResultsUrl'];
        }

        setState(() {
          _highestQualification = userData['highestQualification'];
        });
      }
    }
  }

  Future<void> _checkExistingApplications() async {
    if (_currentUser != null && widget.universityData.containsKey('uid')) {
      final String uid = widget.universityData['uid'];
      QuerySnapshot applicationSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('university_applications')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      setState(() {
        _hasExistingApplication = applicationSnapshot.docs.isNotEmpty;
      });
    } else {
      print(
        "Warning: universityData does not contain 'uid'. Cannot check for existing applications.",
      );
    }
  }

  void _showLoginBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => _LoginBottomSheet(
        onLoginSuccess: () {
          Navigator.pop(context);
          _checkCurrentUserAndApplications();
        },
      ),
    ).whenComplete(() {
      if (!_isLoggedIn) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _pickFile(Function(dynamic) onPicked) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null) {
      if (kIsWeb) {
        onPicked(result.files.first);
      } else {
        onPicked(io.File(result.files.single.path!));
      }
    } else {
      onPicked(null);
    }
    setState(() {});
  }

  Future<String?> _uploadFile(dynamic file, String path) async {
    if (file == null) return null;
    try {
      UploadTask uploadTask;
      if (file is io.File) {
        uploadTask = _storage.ref(path).putFile(file);
      } else if (file is XFile) {
        final bytes = await file.readAsBytes();
        uploadTask = _storage.ref(path).putData(bytes);
      } else if (file is PlatformFile) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception("File data is missing.");
        uploadTask = _storage.ref(path).putData(bytes);
      } else {
        throw Exception("Unsupported file type for upload.");
      }
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _submitApplication() async {
    if (_fullNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _physicalAddressController.text.isEmpty ||
        _yearCompletionController.text.isEmpty ||
        _highestQualification == null ||
        _primaryProgram == null ||
        _primaryProgram == 'Other') {
      Api().showMessage(
        context,
        'Please fill all required fields.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (_idPassportFile == null && _idPassportUrl == null) {
      Api().showMessage(
        context,
        'Please upload a certified copy of your ID or Passport.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (_schoolResultsFile == null && _schoolResultsUrl == null) {
      Api().showMessage(
        context,
        'Please upload your latest school or final Grade 12 results.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (_currentUser == null) {
      Api().showMessage(
        context,
        'Please login to submit your application.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    Api().showMessage(
      context,
      'Application Submitting...',
      '',
      Theme.of(context).primaryColor,
    );
    Api().showLoading(context);

    try {
      String storagePathPrefix = 'applications/${_fullNameController.text}/';
      String? idPassportUrl =
          _idPassportUrl ??
          await _uploadFile(
            _idPassportFile,
            '${storagePathPrefix}id_passport.pdf',
          );
      String? schoolResultsUrl =
          _schoolResultsUrl ??
          await _uploadFile(
            _schoolResultsFile,
            '${storagePathPrefix}school_results.pdf',
          );
      String? proofOfRegistrationUrl = _proofOfRegistrationFile != null
          ? await _uploadFile(
              _proofOfRegistrationFile,
              '${storagePathPrefix}proof_registration.pdf',
            )
          : null;

      List<String> otherQualificationUrls = [];
      for (int i = 0; i < _otherQualificationFiles.length; i++) {
        String? url = await _uploadFile(
          _otherQualificationFiles[i],
          '${storagePathPrefix}other_qual_${i}.pdf',
        );
        if (url != null) otherQualificationUrls.add(url);
      }

      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'fullName': _fullNameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'physicalAddress': _physicalAddressController.text,
        'highestQualification': _highestQualification,
        'previousSchools': _previousSchoolsController.text,
        'yearOfCompletion': _yearCompletionController.text,
        'parent1Name': _parent1NameController.text,
        'parent1Occupation': _parent1OccupationController.text,
        'parent1Income': _parent1IncomeController.text,
        'parent2Name': _parent2NameController.text,
        'parent2Occupation': _parent2OccupationController.text,
        'profileDocuments': {
          'idPassportUrl': idPassportUrl,
          'schoolResultsUrl': schoolResultsUrl,
        },
        'isFirstApplication': false,
      }, SetOptions(merge: true));

      String finalPrimaryProgram = _primaryProgram == 'Other'
          ? _otherPrimaryProgramController.text
          : _primaryProgram!;
      String? finalSecondChoiceProgram = _secondChoiceProgram == 'Other'
          ? _otherSecondChoiceProgramController.text
          : _secondChoiceProgram;
      String? finalThirdChoiceProgram = _thirdChoiceProgram == 'Other'
          ? _otherThirdChoiceProgramController.text
          : _thirdChoiceProgram;
      final String? uid = widget.universityData['uid'];

      if (uid == null) {
        Api().showMessage(
          context,
          'Error: University UID not found.',
          'Please ensure the university data passed has a "uid" field.',
          Theme.of(context).primaryColorDark,
        );
        Navigator.pop(context);
        return;
      }

      Map<String, dynamic> applicationData = {
        'userId': _currentUser!.uid,
        'email': _emailController.text,
        'fullName': _fullNameController.text,
        'phone': _phoneController.text,
        'physicalAddress': _physicalAddressController.text,
        'previousSchools': _previousSchoolsController.text,
        'highestQualification': _highestQualification,
        'yearOfCompletion': _yearCompletionController.text,
        'primaryProgram': finalPrimaryProgram,
        'secondChoiceProgram': finalSecondChoiceProgram,
        'thirdChoiceProgram': finalThirdChoiceProgram,
        'preferredStartDate': _preferredStartDate,
        'applyingForResidence': _applyingForResidence,
        'applyingForFunding': _applyingForFunding,
        'parent1Name': _parent1NameController.text,
        'parent1Occupation': _parent1OccupationController.text,
        'parent1Income': _parent1IncomeController.text,
        'parent2Name': _parent2NameController.text,
        'parent2Occupation': _parent2OccupationController.text,
        'documents': {
          'idPassportUrl': idPassportUrl,
          'schoolResultsUrl': schoolResultsUrl,
          'proofOfRegistrationUrl': proofOfRegistrationUrl,
          'otherQualificationUrls': otherQualificationUrls,
        },
        'submissionDate': FieldValue.serverTimestamp(),
        'status': 'Submitted',
        'uid': uid,
        'selectedUniversity': widget.selectedCampus,
      };

      DocumentReference globalApplicationRequestRef = await _firestore
          .collection('application_requests')
          .add({
            'userId': _currentUser!.uid,
            'universityName': widget.universityData['universityName'],
            'campus': widget.universityData['campusName'],
            'primaryProgram': widget.universityData['primaryProgram'],
            'applicationDetails': applicationData,
            'submissionDate': FieldValue.serverTimestamp(),
            'status': 'New',
            'uid': uid,
          });
      await _firestore
          .collection('tactso_branches')
          .doc(uid)
          .collection('application_requests')
          .doc(globalApplicationRequestRef.id)
          .set({
            'userId': _currentUser!.uid,
            'applicationDetails': applicationData,
            'universityName': widget.universityData['universityName'],
            'campus': widget.universityData['campusName'],
            'primaryProgram': widget.universityData['primaryProgram'],
            'submissionDate': FieldValue.serverTimestamp(),
            'status': 'New',
            'uid': uid,
            'globalApplicationRequestId': globalApplicationRequestRef.id,
          });
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('university_applications')
          .add({
            'applicationDetails': applicationData,
            'universityName': widget.universityData['universityName'],
            'campus': widget.universityData['campusName'],
            'primaryProgram': widget.universityData['primaryProgram'],
            'submissionDate': FieldValue.serverTimestamp(),
            'status': 'Submitted',
            'applicationRequestId': globalApplicationRequestRef.id,
          });

      Navigator.pop(context);
      Api().showMessage(
        context,
        'Application Submitted Successfully!',
        'Your application for ${widget.universityData['name'] ?? 'the university'} has been sent.',
        Theme.of(context).splashColor,
      );

      Api().sendEmail(
        _emailController.text,
        "Application Submitted Successfully! ✅",
        "<p>Dear Applicant,</p><p>We are pleased to inform you that your application has been successfully submitted.</p>",
        context,
      );
      Api().sendEmail(
        widget.selectedCampus?['email'] ?? '',
        "New Application Received 📥",
        "<p>A new application has just been submitted.</p>",
        context,
      );

      setState(() {
        _hasExistingApplication = true;
      });
      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Error submitting your application: $e',
        '',
        Theme.of(context).primaryColorDark,
      );
      print('Submission error: $e');
    }
  }

  // --- HELPERS: Platform-Aware Builders ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildPlatformTextField({
    required TextEditingController controller,
    required String placeholder,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool readOnly = false,
    int? maxLines = 1,
    IconData? icon,
  }) {
    if (isIOSPlatform) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.all(12.0),
          prefix: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(prefixIcon, color: CupertinoColors.systemGrey),
                )
              : null,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: placeholder,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 12,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildPlatformButton({
    required VoidCallback onPressed,
    required String text,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    if (isIOSPlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          color: backgroundColor,
          onPressed: onPressed,
          disabledColor: Theme.of(context).splashColor,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      // Android Material
      return CustomOutlinedButton(
        onPressed: onPressed,
        text: text,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        width: double.infinity,
      );
    }
  }

  Widget _buildExpansionTile({
    required String title,
    required List<Widget> children,
    required String? currentValue,
  }) {
    // Keeps original layout but content inside will be adaptive
    return Card(
      color: Theme.of(context).scaffoldBackgroundColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: ExpansionTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text(
          currentValue ?? 'Select',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerTile({
    required String title,
    required dynamic file,
    required String? url,
    required Function(dynamic) onPick,
    bool isOptional = false,
  }) {
    final bool hasFile = file != null || url != null;
    String subtitleText;
    if (file is XFile) {
      subtitleText = file.name;
    } else if (file is PlatformFile) {
      subtitleText = file.name;
    } else if (file is io.File) {
      subtitleText = file.path.split('/').last;
    } else {
      subtitleText = hasFile ? 'File uploaded' : 'No file selected';
    }

    final icon = hasFile
        ? (isIOSPlatform
              ? CupertinoIcons.check_mark_circled_solid
              : Icons.check_circle)
        : (isIOSPlatform ? CupertinoIcons.paperclip : Icons.attach_file);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),

      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 10,
      child: ListTile(
        title: Text(title + (isOptional ? ' (Optional)' : '')),
        subtitle: Text(
          subtitleText,
          style: TextStyle(color: hasFile ? Colors.green : Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: hasFile ? Colors.green : Colors.grey),
            SizedBox(width: 8),
            GestureDetector(
              onTap: () => onPick(null),
              child: Text(
                hasFile ? 'REPLACE' : 'PICK FILE',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => onPick(null),
      ),
    );
  }

  Widget _buildMultipleFilePickerTile({
    required String title,
    required List<dynamic> files,
    required Function(List<dynamic>) onPick,
    bool isOptional = false,
  }) {
    final bool hasFiles = files.isNotEmpty;
    return Card(
      color: Theme.of(context).scaffoldBackgroundColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: ListTile(
        title: Text(title + (isOptional ? ' (Optional)' : '')),
        subtitle: Text(
          hasFiles ? '${files.length} file(s) selected' : 'No files selected',
          style: TextStyle(color: hasFiles ? Colors.green : Colors.grey),
        ),
        trailing: Icon(
          isIOSPlatform ? CupertinoIcons.collections : Icons.library_books,
        ),
        onTap: () => onPick([]),
      ),
    );
  }

  void _showApplicationDetailsSheet() {
    if (_currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final double maxWidth = 600;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
              ),
              child: ViewApplicationBottomSheet(
                userId: _currentUser!.uid,
                universityUid: widget.universityData['uid'],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardSection({
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      color: color,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildSectionTitle(title), Divider(), ...children],
        ),
      ),
    );
  }

  Widget _buildProgramDropdown(String type) {
    String? currentValue;
    ValueChanged<String?> onChanged;

    switch (type) {
      case 'primary':
        currentValue = _primaryProgram;
        onChanged = (value) => setState(() {
          _primaryProgram = value;
          if (value != 'Other') _otherPrimaryProgramController.clear();
        });
        break;
      case 'second':
        currentValue = _secondChoiceProgram;
        onChanged = (value) => setState(() {
          _secondChoiceProgram = value;
          if (value != 'Other') _otherSecondChoiceProgramController.clear();
        });
        break;
      case 'third':
        currentValue = _thirdChoiceProgram;
        onChanged = (value) => setState(() {
          _thirdChoiceProgram = value;
          if (value != 'Other') _otherThirdChoiceProgramController.clear();
        });
        break;
      default:
        return SizedBox.shrink();
    }

    final bool canEditForm = _isFirstApplication;
    return DropdownButtonFormField<String>(
      value: currentValue,
      hint: Text('Select Program'),
      items:
          [
                'BSc Computer Science',
                'BA Psychology',
                'BCom Accounting',
                'BEng Civil Engineering',
                'Other',
                'None',
              ]
              .map(
                (program) =>
                    DropdownMenuItem(value: program, child: Text(program)),
              )
              .toList(),
      onChanged: canEditForm ? onChanged : null,
      validator: type == 'primary'
          ? (value) => value == null ? 'Required' : null
          : null,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final bool canEditForm = _isFirstApplication;
    final double constrainedWidth = 1000;
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    // --- Column 1 Widgets ---
    final Widget personalInfoCard = _buildCardSection(
      title: '1. Personal & Contact Information',
      color: color.scaffoldBackgroundColor,
      children: [
        _buildPlatformTextField(
          controller: _fullNameController,
          placeholder: 'Full Name',
          icon: isIOSPlatform ? CupertinoIcons.person : Icons.person,
          readOnly: !canEditForm,
        ),
        _buildPlatformTextField(
          controller: _phoneController,
          placeholder: 'Phone Number',
          icon: isIOSPlatform ? CupertinoIcons.phone : Icons.phone,
          keyboardType: TextInputType.phone,
          readOnly: !canEditForm,
        ),
        _buildPlatformTextField(
          controller: _emailController,
          placeholder: 'Email',
          icon: isIOSPlatform ? CupertinoIcons.mail : Icons.email,
          keyboardType: TextInputType.emailAddress,
          readOnly: true,
        ),
        _buildPlatformTextField(
          controller: _physicalAddressController,
          placeholder: 'Physical & Postal Address',
          icon: isIOSPlatform
              ? CupertinoIcons.location_solid
              : Icons.location_on,
          maxLines: 3,
          readOnly: !canEditForm,
        ),
      ],
    );

    final Widget academicHistoryCard = _buildCardSection(
      title: '2. Academic History',
      color: color.scaffoldBackgroundColor,
      children: [
        _buildExpansionTile(
          title: 'Highest Qualification',
          children: [
            DropdownButtonFormField<String>(
              value: _highestQualification,
              hint: const Text('Select Highest Qualification'),
              items:
                  [
                        'Grade 12/Matric',
                        'National Senior Certificate (NSC)',
                        'Diploma',
                        'Bachelor\'s Degree',
                        'Master\'s Degree',
                        'Doctorate',
                        'Other',
                      ]
                      .map(
                        (qual) =>
                            DropdownMenuItem(value: qual, child: Text(qual)),
                      )
                      .toList(),
              onChanged: canEditForm
                  ? (value) => setState(() => _highestQualification = value)
                  : null,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
          currentValue: _highestQualification,
        ),
        _buildPlatformTextField(
          controller: _previousSchoolsController,
          placeholder: 'Previous School(s) Attended',
          icon: isIOSPlatform ? CupertinoIcons.building_2_fill : Icons.school,
          readOnly: !canEditForm,
        ),
        _buildPlatformTextField(
          controller: _yearCompletionController,
          placeholder: 'Year of Completion of Last Qualification',
          icon: isIOSPlatform ? CupertinoIcons.calendar : Icons.calendar_today,
          keyboardType: TextInputType.number,
          readOnly: !canEditForm,
        ),
      ],
    );

    // --- Column 2 Widgets ---
    final Widget supportingDocumentsCard = _buildCardSection(
      title: '3. Supporting Documents',
      color: color.scaffoldBackgroundColor,
      children: [
        _buildFilePickerTile(
          title: 'Certified Copy of ID or Passport',
          file: _idPassportFile,
          url: _idPassportUrl,
          onPick: (file) => _pickFile((p0) => _idPassportFile = p0),
        ),
        _buildFilePickerTile(
          title: 'Latest School Results or Final Grade 12 Results',
          file: _schoolResultsFile,
          url: _schoolResultsUrl,
          onPick: (file) => _pickFile((p0) => _schoolResultsFile = p0),
        ),
        _buildFilePickerTile(
          title: 'Proof of Registration (if transferring)',
          file: _proofOfRegistrationFile,
          url: null,
          onPick: (file) => _pickFile((p0) => _proofOfRegistrationFile = p0),
          isOptional: true,
        ),
        _buildMultipleFilePickerTile(
          title: 'Certificates for Other Qualifications (if applicable)',
          files: _otherQualificationFiles,
          onPick: (files) => setState(() => _otherQualificationFiles = files),
          isOptional: true,
        ),
      ],
    );

    final Widget programSelectionCard = _buildCardSection(
      title: '4. Program Selection',
      color: color.scaffoldBackgroundColor,
      children: [
        _buildExpansionTile(
          title: 'Primary Course/Program',
          children: [_buildProgramDropdown('primary')],
          currentValue: _primaryProgram,
        ),
        if (_primaryProgram == 'Other')
          _buildPlatformTextField(
            controller: _otherPrimaryProgramController,
            placeholder: 'Enter Primary Course Name',
            icon: isIOSPlatform
                ? CupertinoIcons.text_cursor
                : Icons.text_fields,
          ),
        _buildExpansionTile(
          title: 'Second Choice of Course (Optional)',
          children: [_buildProgramDropdown('second')],
          currentValue: _secondChoiceProgram,
        ),
        if (_secondChoiceProgram == 'Other')
          _buildPlatformTextField(
            controller: _otherSecondChoiceProgramController,
            placeholder: 'Enter Second Choice Course Name',
            icon: isIOSPlatform
                ? CupertinoIcons.text_cursor
                : Icons.text_fields,
          ),
        _buildExpansionTile(
          title: 'Third Choice of Course (Optional)',
          children: [_buildProgramDropdown('third')],
          currentValue: _thirdChoiceProgram,
        ),
        if (_thirdChoiceProgram == 'Other')
          _buildPlatformTextField(
            controller: _otherThirdChoiceProgramController,
            placeholder: 'Enter Third Choice Course Name',
            icon: isIOSPlatform
                ? CupertinoIcons.text_cursor
                : Icons.text_fields,
          ),
      ],
    );

    final Widget financialDetailsCard = _buildCardSection(
      title: '5. Financial & Residence Details',
      color: color.scaffoldBackgroundColor,
      children: [
        ListTile(
          title: const Text('Applying for Residence?'),
          trailing: Switch.adaptive(
            value: _applyingForResidence,
            onChanged: (bool value) =>
                setState(() => _applyingForResidence = value),
            activeColor: color.primaryColor,
          ),
        ),
        ListTile(
          title: const Text('Applying for Funding/Bursary?'),
          trailing: Switch.adaptive(
            value: _applyingForFunding,
            onChanged: (bool value) =>
                setState(() => _applyingForFunding = value),
            activeColor: color.primaryColor,
          ),
        ),
        _buildPlatformTextField(
          controller: _parent1NameController,
          placeholder: 'Parent/Guardian 1 Full Name',
          icon: isIOSPlatform ? CupertinoIcons.person_solid : Icons.person,
          readOnly: !canEditForm,
        ),
        _buildPlatformTextField(
          controller: _parent1OccupationController,
          placeholder: 'Parent/Guardian 1 Occupation',
          icon: isIOSPlatform ? CupertinoIcons.bag_fill : Icons.work,
          readOnly: !canEditForm,
        ),
        if (_applyingForFunding)
          _buildPlatformTextField(
            controller: _parent1IncomeController,
            placeholder: 'Parent/Guardian 1 Annual Income',
            icon: isIOSPlatform
                ? CupertinoIcons.money_dollar_circle_fill
                : Icons.attach_money,
            keyboardType: TextInputType.number,
            readOnly: !canEditForm,
          ),
      ],
    );

    return Scaffold(
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
                  middle: Column(
                    children: [
                      const Text(
                        'New University Application at',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        widget.selectedCampus?['campusName'] ??
                            'Selected Campus',
                      ),
                    ],
                  ),
                  backgroundColor: color.primaryColor,
                )
                as PreferredSizeWidget
          : AppBar(
              title: Column(
                children: [
                  const Text(
                    'New University Application at',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    widget.selectedCampus?['campusName'] ?? 'Selected Campus',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              backgroundColor: color.primaryColor,
              foregroundColor: color.scaffoldBackgroundColor,
            ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: constrainedWidth),
          child: _isLoadingAuth
              ? Center(
                  child: isIOSPlatform
                      ? const CupertinoActivityIndicator()
                      : const CircularProgressIndicator(),
                )
              : _isLoggedIn
              ? _hasExistingApplication
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isIOSPlatform
                                    ? CupertinoIcons.check_mark_circled_solid
                                    : Icons.check_circle,
                                size: 80,
                                color: Colors.green,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'You have already submitted an application...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: color.cardColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildPlatformButton(
                                onPressed: _showApplicationDetailsSheet,
                                text: 'View My Application',
                                backgroundColor: color.primaryColor,
                                foregroundColor: color.cardColor,
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Responsive Layout Switch
                              isDesktop
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              personalInfoCard,
                                              academicHistoryCard,
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              supportingDocumentsCard,
                                              programSelectionCard,
                                              financialDetailsCard,
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        personalInfoCard,
                                        academicHistoryCard,
                                        supportingDocumentsCard,
                                        programSelectionCard,
                                        financialDetailsCard,
                                      ],
                                    ),

                              const SizedBox(height: 20),
                              _buildPlatformButton(
                                onPressed: _submitApplication,
                                text: 'Submit Application',
                                backgroundColor: color.primaryColor,
                                foregroundColor: color.cardColor,
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'You need to be logged in to apply for universities.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        _buildPlatformButton(
                          onPressed: _showLoginBottomSheet,
                          text: 'Login',
                          backgroundColor: color.primaryColor,
                          foregroundColor: color.cardColor,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
