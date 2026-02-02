// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print, use_key_in_widget_constructors, unused_import, prefer_final_fields

import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http; // Django API
import 'package:firebase_auth/firebase_auth.dart'; // Auth State Only
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:flutter/foundation.dart';
import 'package:ttact/Components/AdBanner.dart';

import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/ViewApplicationsBottomSheet.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

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

// --- LOGIN BOTTOM SHEET (Unchanged, uses Firebase Auth for Identity) ---
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
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
  bool _isFirstApplication = true; // Handled by checking profile completeness

  final _formKey = GlobalKey<FormState>();

  // Files
  dynamic _idPassportFile;
  dynamic _schoolResultsFile;
  dynamic _proofOfRegistrationFile;
  List<dynamic> _otherQualificationFiles = [];

  // Stored URLs (To check if existing files are present)
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
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUserAndApplications();
  }

  @override
  void dispose() {
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
    setState(() => _isLoadingAuth = true);
    _currentUser = _auth.currentUser;

    if (_currentUser != null) {
      _isLoggedIn = true;
      await _fetchUserDetails();
      await _checkExistingApplications();
    } else {
      _isLoggedIn = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginBottomSheet();
      });
    }
    setState(() => _isLoadingAuth = false);
  }

  // --- 1. FETCH USER DETAILS (DJANGO) ---
  Future<void> _fetchUserDetails() async {
    if (_currentUser != null) {
      try {
        final url = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/users/${_currentUser!.uid}/',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          _fullNameController.text =
              '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim();
          _emailController.text = data['email'] ?? '';
          _physicalAddressController.text = data['address'] ?? '';
          _phoneController.text = data['phone'] ?? '';

          // Map Django snake_case to UI logic
          _previousSchoolsController.text = data['previous_schools'] ?? '';
          _yearCompletionController.text = data['year_of_completion'] ?? '';
          _highestQualification = data['highest_qualification'];

          _parent1NameController.text = data['parent1_name'] ?? '';
          _parent1OccupationController.text = data['parent1_occupation'] ?? '';
          _parent1IncomeController.text = data['parent1_income'] ?? '';

          _parent2NameController.text = data['parent2_name'] ?? '';
          _parent2OccupationController.text = data['parent2_occupation'] ?? '';

          // Existing Documents
          _idPassportUrl = data['id_passport_url'];
          _schoolResultsUrl = data['school_results_url'];

          // Determine if first application based on existing data
          if (_idPassportUrl != null && _schoolResultsUrl != null) {
            _isFirstApplication = false;
          }
        }
      } catch (e) {
        print("Error fetching user details: $e");
      }
      setState(() {});
    }
  }

  // --- 2. CHECK EXISTING APPLICATIONS (DJANGO) ---
  Future<void> _checkExistingApplications() async {
    if (_currentUser != null && widget.universityData.containsKey('uid')) {
      try {
        final String uniUid = widget.universityData['uid'];
        // URL: /api/university_applications/?user_uid=X&university_uid=Y
        final url = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/university_applications/?user_uid=${_currentUser!.uid}&university_uid=$uniUid',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          List apps = json.decode(response.body);
          setState(() {
            _hasExistingApplication = apps.isNotEmpty;
          });
        }
      } catch (e) {
        print("Error checking applications: $e");
      }
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

  // --- 3. SUBMIT APPLICATION (DJANGO MULTIPART) ---
  Future<void> _submitApplication() async {
    // 1. Validation
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
        'Please fill required fields.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    if (_idPassportFile == null && _idPassportUrl == null) {
      Api().showMessage(
        context,
        'Upload ID/Passport.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (_schoolResultsFile == null && _schoolResultsUrl == null) {
      Api().showMessage(
        context,
        'Upload School Results.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    Api().showMessage(
      context,
      'Submitting...',
      '',
      Theme.of(context).primaryColor,
    );
    Api().showLoading(context);

    try {
      final String uid = _currentUser!.uid;
      final String universityUid = widget.universityData['uid'] ?? '';

      // --- STEP A: Update User Profile (Files + Info) ---
      // We do this first to save the core documents permanently to the user profile
      var userRequest = http.MultipartRequest(
        'PATCH',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/users/$uid/'),
      );

      // Add User Text Fields (Map to Django models)
      userRequest.fields['phone'] = _phoneController.text;
      userRequest.fields['address'] = _physicalAddressController.text;
      userRequest.fields['previous_schools'] = _previousSchoolsController.text;
      userRequest.fields['year_of_completion'] = _yearCompletionController.text;
      userRequest.fields['highest_qualification'] = _highestQualification!;

      userRequest.fields['parent1_name'] = _parent1NameController.text;
      userRequest.fields['parent1_occupation'] =
          _parent1OccupationController.text;
      userRequest.fields['parent1_income'] = _parent1IncomeController.text;
      userRequest.fields['parent2_name'] = _parent2NameController.text;
      userRequest.fields['parent2_occupation'] =
          _parent2OccupationController.text;

      // Add Profile Files (ID & School Results) if new ones selected
      if (_idPassportFile != null) {
        if (kIsWeb) {
          userRequest.files.add(
            http.MultipartFile.fromBytes(
              'id_passport',
              _idPassportFile.bytes,
              filename: _idPassportFile.name,
            ),
          );
        } else {
          userRequest.files.add(
            await http.MultipartFile.fromPath(
              'id_passport',
              _idPassportFile.path,
            ),
          );
        }
      }
      if (_schoolResultsFile != null) {
        if (kIsWeb) {
          userRequest.files.add(
            http.MultipartFile.fromBytes(
              'school_results',
              _schoolResultsFile.bytes,
              filename: _schoolResultsFile.name,
            ),
          );
        } else {
          userRequest.files.add(
            await http.MultipartFile.fromPath(
              'school_results',
              _schoolResultsFile.path,
            ),
          );
        }
      }

      await userRequest.send(); // Send Profile Update

      // --- STEP B: Create Application (App Data + Specific Files) ---

      var appRequest = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/university_applications/'),
      );

      // Core Linkage
      appRequest.fields['user_uid'] = uid;
      appRequest.fields['university_uid'] = universityUid;
      appRequest.fields['university_name'] =
          widget.universityData['universityName'] ?? 'Unknown';
      appRequest.fields['campus_name'] =
          widget.universityData['campusName'] ?? 'Main';
      appRequest.fields['status'] = 'Submitted';

      // Programs
      String finalPrimary = _primaryProgram == 'Other'
          ? _otherPrimaryProgramController.text
          : _primaryProgram!;
      String finalSecond = _secondChoiceProgram == 'Other'
          ? _otherSecondChoiceProgramController.text
          : _secondChoiceProgram ?? '';
      String finalThird = _thirdChoiceProgram == 'Other'
          ? _otherThirdChoiceProgramController.text
          : _thirdChoiceProgram ?? '';

      appRequest.fields['primary_program'] = finalPrimary;
      appRequest.fields['second_choice_program'] = finalSecond;
      appRequest.fields['third_choice_program'] = finalThird;

      appRequest.fields['applying_for_residence'] = _applyingForResidence
          .toString();
      appRequest.fields['applying_for_funding'] = _applyingForFunding
          .toString();

      // Application Specific Files (Proof of Reg, etc.)
      if (_proofOfRegistrationFile != null) {
        if (kIsWeb) {
          appRequest.files.add(
            http.MultipartFile.fromBytes(
              'proof_of_registration',
              _proofOfRegistrationFile.bytes,
              filename: _proofOfRegistrationFile.name,
            ),
          );
        } else {
          appRequest.files.add(
            await http.MultipartFile.fromPath(
              'proof_of_registration',
              _proofOfRegistrationFile.path,
            ),
          );
        }
      }

      // Handle Multiple "Other" Files
      // Django standard multipart expects list handling or individual keys.
      // For simplicity here, assuming backend accepts 'other_documents' list
      // Note: Standard Django Rest Framework might need a custom view to handle list of files on one key easily.
      // Alternatively, we loop.
      for (int i = 0; i < _otherQualificationFiles.length; i++) {
        var f = _otherQualificationFiles[i];
        if (kIsWeb) {
          appRequest.files.add(
            http.MultipartFile.fromBytes(
              'other_documents',
              f.bytes,
              filename: f.name,
            ),
          );
        } else {
          appRequest.files.add(
            await http.MultipartFile.fromPath('other_documents', f.path),
          );
        }
      }

      final streamedResponse = await appRequest.send();
      final response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // Close Loading

      if (response.statusCode == 201) {
        Api().showMessage(
          context,
          'Application Submitted!',
          'Your application has been sent successfully.',
          Colors.green,
        );

        // Emails (Optional: Move this logic to backend for security)
        Api().sendEmail(
          _emailController.text,
          "Application Submitted ✅",
          "<p>Success.</p>",
          context,
        );

        setState(() => _hasExistingApplication = true);
        Navigator.pop(context); // Close Screen
      } else {
        Api().showMessage(
          context,
          'Submission Failed: ${response.statusCode}',
          'Error',
          Colors.red,
        );
        print("Server Response: ${response.body}");
      }
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(context, 'Error: $e', 'Error', Colors.red);
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
    final bool hasFile = file != null || (url != null && url.isNotEmpty);
    String subtitleText;
    if (file is io.File) {
      subtitleText = file.path.split('/').last;
    } else if (file != null) {
      // Web PlatformFile or XFile
      subtitleText = "File Selected";
    } else {
      subtitleText = hasFile ? 'File uploaded previously' : 'No file selected';
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

    final bool canEditForm = true;
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

  // ⭐️ PREMIUM NEUMORPHIC APP BAR ⭐️
  Widget _buildPremiumNeumorphicAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: baseColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.5)
                : Colors.black.withOpacity(0.05),
            offset: Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.5)
                        : Colors.white,
                    offset: Offset(-4, -4),
                    blurRadius: 10,
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.3),
                    offset: Offset(4, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                isIOSPlatform ? CupertinoIcons.back : Icons.arrow_back_rounded,
                color: theme.hintColor,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "APPLICATION",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  widget.selectedCampus?['campusName'] ?? 'Selected Campus',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: theme.primaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    final bool canEditForm = true;
    final double constrainedWidth = 1000;
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

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

    final Widget supportingDocumentsCard = _buildCardSection(
      title: '3. Supporting Documents',
      color: color.scaffoldBackgroundColor,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[800],
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Important: Please ensure all uploaded documents are CERTIFIED copies and not older than 3 months.",
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
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
      backgroundColor: baseColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildPremiumNeumorphicAppBar(context),
            Expanded(
              child: Center(
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
                                            ? CupertinoIcons
                                                  .check_mark_circled_solid
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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

                                      // Privacy Notice
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 20.0,
                                        ),
                                        padding: const EdgeInsets.all(15.0),
                                        decoration: BoxDecoration(
                                          color: color.primaryColor.withOpacity(
                                            0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: color.primaryColor
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              isIOSPlatform
                                                  ? CupertinoIcons
                                                        .lock_shield_fill
                                                  : Icons
                                                        .verified_user_outlined,
                                              color: color.primaryColor,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Data Usage & Privacy Notice",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: color.primaryColor,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    "We value your privacy. By submitting this form, you acknowledge that your uploaded documents and personal details will be used STRICTLY for the purpose of facilitating this university application on your behalf. Your data is secure and will not be shared with unauthorized third parties.",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      height: 1.4,
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color
                                                          ?.withOpacity(0.8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: _agreedToTerms,
                                            onChanged: (bool? value) =>
                                                setState(
                                                  () => _agreedToTerms =
                                                      value ?? false,
                                                ),
                                            activeColor: color.primaryColor,
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                () => _agreedToTerms =
                                                    !_agreedToTerms,
                                              ),
                                              child: const Text(
                                                'I confirm that all information provided is accurate and truthful to the best of my knowledge, and I authorize the use of my documents for this application.',
                                                style: TextStyle(height: 1.5),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      _buildPlatformButton(
                                        onPressed: _agreedToTerms
                                            ? _submitApplication
                                            : () => Api().showMessage(
                                                context,
                                                'Please agree to the terms to continue.',
                                                '',
                                                Theme.of(
                                                  context,
                                                ).primaryColorDark,
                                              ),
                                        text: 'Submit Application',
                                        backgroundColor: color.primaryColor,
                                        foregroundColor: color.cardColor,
                                      ),
                                      const SizedBox(height: 40),
                                      AdManager().bannerAdWidget(),
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
            ),
          ],
        ),
      ),
    );
  }
}
