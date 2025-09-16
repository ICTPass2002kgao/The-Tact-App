import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';  
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'dart:io';

import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/ViewApplicationsBottomSheet.dart';
 
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

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: CupertinoTextField(
            controller: emailController,
            placeholder: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.systemGrey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(12.0),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(
                CupertinoIcons.mail,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: CupertinoTextField(
            controller: passwordController,
            placeholder: 'Password',
            obscureText: true,
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.systemGrey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(12.0),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(
                CupertinoIcons.lock,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ),
        CustomOutlinedButton(
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
          foregroundColor: color.scaffoldBackgroundColor,
          width: double.infinity,
        ),
        SizedBox(height: 60),
      ],
    );
  }
}
 
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseStorage _storage = FirebaseStorage.instance; 
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
  bool _hasExistingApplication =
      false; 

  final _formKey =
      GlobalKey<
        FormState
      >();  
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _idPassportController = TextEditingController();
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
  final TextEditingController _parent2IncomeController =
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
 
  File? _idPassportFile;
  File? _schoolResultsFile;
  File? _proofOfRegistrationFile;
  List<File> _otherQualificationFiles = [];
  File? _passportPhotoFile; 
  String? _idPassportUrl;
  String? _schoolResultsUrl;
  String? _passportPhotoUrl;
  AdManager adManager = AdManager();
  @override
  void initState() {
    super.initState();
    _checkCurrentUserAndApplications();
    adManager.loadRewardedInterstitialAd();
    adManager.loadInterstitialAd();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _idPassportController.dispose();
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
    _parent2IncomeController.dispose();
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
      if (userDoc.exists &&
          userDoc.data()!.containsKey('isFirstApplication') &&
          userDoc.data()!['isFirstApplication'] == false) {
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
 
        _fullNameController.text = userData['fullName'] ?? '';
        _idPassportController.text = userData['idPassport'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _physicalAddressController.text = userData['physicalAddress'] ?? '';
        _previousSchoolsController.text = userData['previousSchools'] ?? '';
        _yearCompletionController.text = userData['yearOfCompletion'] ?? '';
        _parent1NameController.text = userData['parent1Name'] ?? '';
        _parent1OccupationController.text = userData['parent1Occupation'] ?? '';
        _parent1IncomeController.text = userData['parent1Income'] ?? '';
        _parent2NameController.text = userData['parent2Name'] ?? '';
        _parent2OccupationController.text = userData['parent2Occupation'] ?? '';
        _parent2IncomeController.text = userData['parent2Income'] ?? '';
 
        final Map<String, dynamic>? profileDocs = userData['profileDocuments'];
        if (profileDocs != null) {
          _idPassportUrl = profileDocs['idPassportUrl'];
          _schoolResultsUrl = profileDocs['schoolResultsUrl'];
          _passportPhotoUrl = profileDocs['passportPhotoUrl'];
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
          .where('applicationDetails.uid', isEqualTo: uid)  
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
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: _LoginBottomSheet(
            onLoginSuccess: () {
              Navigator.pop(context);  
              _checkCurrentUserAndApplications(); 
            },
          ),
        );
      },
    ).whenComplete(() { 
      if (!_isLoggedIn) {
        Navigator.pop(context);  
      }
    });
  }
 
  Future<void> _pickImage(ImageSource source, Function(File?) onPicked) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      onPicked(File(pickedFile.path));
    } else {
      onPicked(null);
      print('No image selected.');
    }
    setState(() {});
  }

  Future<void> _pickFile(Function(File?) onPicked) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      onPicked(File(result.files.single.path!));
    } else {
      onPicked(null);
      print('No file selected.');
    }
    setState(() {});
  }

  Future<void> _pickMultipleFiles(Function(List<File>) onPicked) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      onPicked(result.files.map((file) => File(file.path!)).toList());
    } else {
      onPicked([]);
      print('No files selected.');
    }
    setState(() {});
  }

  // --- Firebase Upload Logic ---
  Future<String?> _uploadFile(File file, String path) async {
    try {
      UploadTask uploadTask = _storage.ref(path).putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _submitApplication() async {
    // Manual validation for CupertinoTextFields

    if (_fullNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _physicalAddressController.text.isEmpty ||
        _yearCompletionController.text.isEmpty ||
        _highestQualification == null ||
        _primaryProgram == null) {
      Api().showMessage(
        context,
        'Please fill all required fields.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    // Additional validation for "Other" program fields
    if (_primaryProgram == 'Other' &&
        _otherPrimaryProgramController.text.isEmpty) {
      Api().showMessage(
        context,
        'Please enter the primary course name.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (_secondChoiceProgram == 'Other' &&
        _otherSecondChoiceProgramController.text.isEmpty) {
      Api().showMessage(
        context,
        'Please enter the second choice course name.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (_thirdChoiceProgram == 'Other' &&
        _otherThirdChoiceProgramController.text.isEmpty) {
      // New validation
      Api().showMessage(
        context,
        'Please enter the third choice course name.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
 
    if (int.tryParse(_yearCompletionController.text) == null) {
      Api().showMessage(
        context,
        'Invalid Year',
        'Please enter a valid year for completion.',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text)) {
      Api().showMessage(
        context,
        'Invalid Email',
        'Please enter a valid email address.',
        Theme.of(context).primaryColorDark,
      );
      return;
    }

    if (_applyingForFunding == true) {
      if (_parent1NameController.text.isEmpty ||
          _parent1OccupationController.text.isEmpty) {
        Api().showMessage(
          context,
          'Missing Funding Details',
          'Parent/Guardian 1 details and income are required for funding.',
          Theme.of(context).primaryColorDark,
        );
        return;
      }
    }

    // Basic file validation
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
    if (_passportPhotoFile == null && _passportPhotoUrl == null) {
      Api().showMessage(
        context,
        'Please upload a passport-sized photo.',
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
      // 1. Upload new documents if they don't already exist
      String storagePathPrefix = 'applications/${_fullNameController.text}/';

      String? idPassportUrl =
          _idPassportUrl ??
          await _uploadFile(
            _idPassportFile!,
            '${storagePathPrefix}id_passport.pdf',
          );
      String? schoolResultsUrl =
          _schoolResultsUrl ??
          await _uploadFile(
            _schoolResultsFile!,
            '${storagePathPrefix}school_results.pdf',
          );
      String? passportPhotoUrl =
          _passportPhotoUrl ??
          await _uploadFile(
            _passportPhotoFile!,
            '${storagePathPrefix}passport_photo.jpg',
          );

      String? proofOfRegistrationUrl = _proofOfRegistrationFile != null
          ? await _uploadFile(
              _proofOfRegistrationFile!,
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

      // 1.1 Save user's personal and academic data to their main profile
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'fullName': _fullNameController.text,
        'idPassport': _idPassportController.text,
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
        'parent2Income': _parent2IncomeController.text,
        'profileDocuments': {
          'idPassportUrl': idPassportUrl,
          'schoolResultsUrl': schoolResultsUrl,
          'passportPhotoUrl': passportPhotoUrl,
        },
        'isFirstApplication': false,
      }, SetOptions(merge: true));
 
      String finalPrimaryProgram = _primaryProgram == 'Other'
          ? _otherPrimaryProgramController.text
          : _primaryProgram!;
      String? finalSecondChoiceProgram = _secondChoiceProgram == 'Other'
          ? _otherSecondChoiceProgramController.text
          : _secondChoiceProgram;
      String? finalThirdChoiceProgram =
          _thirdChoiceProgram ==
              'Other' // New final program
          ? _otherThirdChoiceProgramController.text
          : _thirdChoiceProgram; 
      final String? uid = widget.universityData['uid'];

      if (uid == null) {
        Api().showMessage(
          context,
          'Error: University UID not found for this application.',
          'Please ensure the university data passed has a "uid" field.',
          Theme.of(context).primaryColorDark,
        );
        Navigator.pop(context);
        return;   }
 
      Map<String, dynamic> applicationData = {
        'userId': _currentUser!.uid,
        'email': _emailController.text,
        'fullName': _fullNameController.text,
        'phone': _phoneController.text,
        'physicalAddress': _physicalAddressController.text,
        'previousSchools': _previousSchoolsController.text,
        'highestQualification': _highestQualification,
        'yearOfCompletion': _yearCompletionController.text,
        'primaryProgram': finalPrimaryProgram, // Use final program name
        'secondChoiceProgram':
            finalSecondChoiceProgram, // Use final program name
        'thirdChoiceProgram':
            finalThirdChoiceProgram, // New field for third choice
        'preferredStartDate': _preferredStartDate,
        'applyingForResidence': _applyingForResidence,
        'applyingForFunding': _applyingForFunding,
        'parent1Name': _parent1NameController.text,
        'parent1Occupation': _parent1OccupationController.text,
        'parent1Income': _parent1IncomeController.text,
        'parent2Name': _parent2NameController.text,
        'parent2Occupation': _parent2OccupationController.text,
        'parent2Income': _parent2IncomeController.text,
        'documents': {
          'idPassportUrl': idPassportUrl,
          'schoolResultsUrl': schoolResultsUrl,
          'proofOfRegistrationUrl': proofOfRegistrationUrl,
          'otherQualificationUrls': otherQualificationUrls,
          'passportPhotoUrl': passportPhotoUrl,
        },
        'submissionDate': FieldValue.serverTimestamp(),
        'status': 'Submitted', // Initial status for user's record
        'uid': uid, // Use university's UID here
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
          .collection(
            'application_requests',
          )  
          .doc(
            globalApplicationRequestRef.id,
          )  
          .set({
            'userId': _currentUser!.uid,
            'applicationDetails': applicationData,
            'universityName': widget.universityData['universityName'],
            'campus': widget.universityData['campusName'],
            'primaryProgram':
                widget.universityData['primaryProgram'] ,
            'submissionDate': FieldValue.serverTimestamp(),
            'status': 'New',
            'uid': uid, 
            'globalApplicationRequestId': globalApplicationRequestRef
                .id,  
          }); 
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('university_applications')
          .add({
            'applicationDetails': applicationData,
            'universityName': widget.universityData['universityName'],
            'campus': widget.universityData['campusName'],
            'primaryProgram':
                widget.universityData['primaryProgram'], 
            'submissionDate': FieldValue.serverTimestamp(),
            'status': 'Submitted',  
            'applicationRequestId':
                globalApplicationRequestRef.id, 
          });
      Navigator.pop(context);
      adManager.showRewardedInterstitialAd((ad, reward) {
        print('User earned reward: ${reward.amount} ${reward.type}');
      });
      Api().showMessage(
        context,
        'Application Submitted Successfully!',
        'Your application for ${widget.universityData['name'] ?? 'the university'} has been sent.',
        Theme.of(context).splashColor,
      ); 
      setState(() {
        _hasExistingApplication = true;
      }); 
      Navigator.pop(context);  
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Error submitting your application: ${e.toString()}',
        '',
        Theme.of(context).primaryColorDark,
      );
      print('Submission error: $e');
    }
  }

  // Helper widgets (keep these as private methods of your State class)
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.activeBlue, // Example color
        ),
      ),
    );
  }

  Widget _buildExpansionTile({
    required String title,
    required List<Widget> children,
    required String? currentValue,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        title: Text(title),
        trailing: Text(currentValue ?? 'Select'),
        children: children,
      ),
    );
  }

  Widget _buildCupertinoTextField({
    required TextEditingController controller,
    required String placeholder,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool readOnly = false,
    int? maxLines = 1,
  }) {
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
  }

  Widget _buildFilePickerTile({
    required String title,
    required File? file,
    required String? url, // Added url parameter
    required Function(File?) onPick,
    bool isOptional = false,
  }) {
    final bool hasFile = file != null || url != null;
    final String subtitleText = hasFile
        ? 'Already uploaded'
        : 'No file selected';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: CupertinoListTile(
        title: Text(title + (isOptional ? ' (Optional)' : '')),
        subtitle: Text(subtitleText),
        trailing: Icon(
          hasFile
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.paperclip,
          color: hasFile
              ? CupertinoColors.activeGreen
              : CupertinoColors.systemGrey,
        ),
        onTap: hasFile
            ? null
            : () async {
                // Disable onTap if file exists
                await onPick(null);
                setState(() {});
              },
      ),
    );
  }

  Widget _buildMultipleFilePickerTile({
    required String title,
    required List<File> files,
    required Function(List<File>) onPick,
    bool isOptional = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: CupertinoListTile(
        // Using CupertinoListTile for consistency
        title: Text(title + (isOptional ? ' (Optional)' : '')),
        subtitle: Text(
          files.isNotEmpty
              ? '${files.length} file(s) selected'
              : 'No files selected',
        ),
        trailing: const Icon(CupertinoIcons.collections), // Cupertino icon
        onTap: () async {
          await onPick(
            [],
          ); // Passing empty list to indicate re-picking or clearing
          setState(() {});
        },
      ),
    );
  }

  void _showApplicationDetailsSheet() {
    if (_currentUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Makes the background transparent
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ViewApplicationBottomSheet(
            userId: _currentUser!.uid,
            universityUid: widget.universityData['uid'],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final bool hasExistingData = _currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('New University Application at'),
            Text(widget.selectedCampus?['campusName'] ?? ''),
          ],
        ),
        backgroundColor: color.primaryColor,
      ),
      body: _isLoadingAuth
          ? const Center(
              child: CupertinoActivityIndicator(),
            ) // Cupertino loading indicator
          : _isLoggedIn
          ? _hasExistingApplication
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'You have already submitted an application for ${widget.universityData['universityName'] ?? 'this university'}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 20),
                          CupertinoButton.filled(
                            // This is the button to display the bottom sheet
                            onPressed: _showApplicationDetailsSheet,
                            child: const Text('View My Application'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      // Form is still useful for semantic grouping
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('1. Personal Information'),
                          _buildCupertinoTextField(
                            controller: _fullNameController,
                            placeholder: 'Full Name (as on ID/Passport)',
                            prefixIcon: CupertinoIcons.person,
                            readOnly: hasExistingData,
                            // Validation handled manually on submit
                          ),
                          _buildCupertinoTextField(
                            controller: _phoneController,
                            placeholder: 'Phone Number',
                            prefixIcon: CupertinoIcons.phone,
                            keyboardType: TextInputType.phone,
                            readOnly: hasExistingData,
                            // Validation handled manually on submit
                          ),
                          _buildCupertinoTextField(
                            controller: _emailController,
                            placeholder: 'Email',
                            prefixIcon: CupertinoIcons.mail,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: true,
                            // Validation handled manually on submit
                          ),
                          _buildCupertinoTextField(
                            controller: _physicalAddressController,
                            placeholder: 'Physical & Postal Address',
                            prefixIcon: CupertinoIcons.location_solid,
                            maxLines: 3,
                            readOnly: hasExistingData,
                            // Validation handled manually on submit
                          ),
                          const SizedBox(height: 20),

                          // Academic History Section
                          _buildSectionTitle('2. Academic History'),
                          _buildExpansionTile(
                            title: 'Highest Qualification',
                            children: [
                              DropdownButtonFormField<String>(
                                // Keeping this as a regular dropdown for simplicity with validation
                                value: _highestQualification,
                                hint: const Text(
                                  'Select Highest Qualification',
                                ),
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
                                          (qual) => DropdownMenuItem(
                                            value: qual,
                                            child: Text(qual),
                                          ),
                                        )
                                        .toList(),
                                onChanged: hasExistingData
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _highestQualification = value;
                                        });
                                      },
                                validator: (value) =>
                                    value == null ? 'Required' : null,
                              ),
                            ],
                            currentValue: _highestQualification,
                          ),
                          // Removed _buildSubjectList() here as per request.
                          _buildCupertinoTextField(
                            controller: _yearCompletionController,
                            placeholder:
                                'Year of Completion of Last Qualification',
                            prefixIcon: CupertinoIcons.calendar,
                            keyboardType: TextInputType.number,
                            readOnly: hasExistingData,
                            // Validation handled manually on submit
                          ),
                          const SizedBox(height: 20),

                          // Supporting Documents Section
                          _buildSectionTitle('3. Supporting Documents'),
                          _buildFilePickerTile(
                            title: 'Certified Copy of ID or Passport',
                            file: _idPassportFile,
                            url: _idPassportUrl,
                            onPick: (file) =>
                                _pickFile((p0) => _idPassportFile = p0),
                          ),
                          _buildFilePickerTile(
                            title:
                                'Latest School Results or Final Grade 12 Results',
                            file: _schoolResultsFile,
                            url: _schoolResultsUrl,
                            onPick: (file) =>
                                _pickFile((p0) => _schoolResultsFile = p0),
                          ),
                          _buildFilePickerTile(
                            title: 'Proof of Registration (if transferring)',
                            file: _proofOfRegistrationFile,
                            url:
                                null, // This document is always optional and can be re-uploaded
                            onPick: (file) => _pickFile(
                              (p0) => _proofOfRegistrationFile = p0,
                            ),
                            isOptional: true,
                          ),
                          _buildMultipleFilePickerTile(
                            title:
                                'Certificates for Other Qualifications (if applicable)',
                            files: _otherQualificationFiles,
                            onPick: (files) => _pickMultipleFiles(
                              (p0) => _otherQualificationFiles = p0,
                            ),
                            isOptional: true,
                          ),
                          _buildFilePickerTile(
                            title: 'Passport-sized Photo',
                            file: _passportPhotoFile,
                            url: _passportPhotoUrl,
                            onPick: (file) => _pickImage(
                              ImageSource.gallery,
                              (p0) => _passportPhotoFile = p0,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Program Selection Section
                          _buildSectionTitle('4. Program Selection'),
                          _buildExpansionTile(
                            title: 'Primary Course/Program you’re applying for',
                            children: [
                              DropdownButtonFormField<String>(
                                value: _primaryProgram,
                                hint: const Text('Select Program'),
                                items:
                                    [
                                          'BSc Computer Science',
                                          'BA Psychology',
                                          'BCom Accounting',
                                          'BEng Civil Engineering',
                                          'Other',
                                        ]
                                        .map(
                                          (program) => DropdownMenuItem(
                                            value: program,
                                            child: Text(program),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _primaryProgram = value;
                                    if (value != 'Other') {
                                      _otherPrimaryProgramController.clear();
                                    }
                                  });
                                },
                                validator: (value) =>
                                    value == null ? 'Required' : null,
                              ),
                              if (_primaryProgram == 'Other')
                                _buildCupertinoTextField(
                                  controller: _otherPrimaryProgramController,
                                  placeholder: 'Enter Primary Course Name',
                                  prefixIcon: CupertinoIcons.text_cursor,
                                ),
                            ],
                            currentValue: _primaryProgram,
                          ),
                          _buildExpansionTile(
                            title: 'Second Choice of Course (Optional)',
                            children: [
                              DropdownButtonFormField<String>(
                                value: _secondChoiceProgram,
                                hint: const Text(
                                  'Select Second Choice (Optional)',
                                ),
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
                                          (program) => DropdownMenuItem(
                                            value: program,
                                            child: Text(program),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _secondChoiceProgram = value;
                                    if (value != 'Other') {
                                      _otherSecondChoiceProgramController
                                          .clear();
                                    }
                                  });
                                },
                              ),
                              if (_secondChoiceProgram == 'Other')
                                _buildCupertinoTextField(
                                  controller:
                                      _otherSecondChoiceProgramController,
                                  placeholder:
                                      'Enter Second Choice Course Name',
                                  prefixIcon: CupertinoIcons.text_cursor,
                                ),
                            ],
                            currentValue: _secondChoiceProgram,
                          ),
                          _buildExpansionTile(
                            // New ExpansionTile for Third Choice
                            title: 'Third Choice of Course (Optional)',
                            children: [
                              DropdownButtonFormField<String>(
                                value: _thirdChoiceProgram,
                                hint: const Text(
                                  'Select Third Choice (Optional)',
                                ),
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
                                          (program) => DropdownMenuItem(
                                            value: program,
                                            child: Text(program),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _thirdChoiceProgram = value;
                                    if (value != 'Other') {
                                      _otherThirdChoiceProgramController
                                          .clear();
                                    }
                                  });
                                },
                              ),
                              if (_thirdChoiceProgram == 'Other')
                                _buildCupertinoTextField(
                                  controller:
                                      _otherThirdChoiceProgramController,
                                  placeholder: 'Enter Third Choice Course Name',
                                  prefixIcon: CupertinoIcons.text_cursor,
                                ),
                            ],
                            currentValue: _thirdChoiceProgram,
                          ),
                          const SizedBox(height: 20),

                          // Financial & Residence Details Section
                          _buildSectionTitle(
                            '5. Financial & Residence Details',
                          ),

                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checkboxes
                              CupertinoListTile(
                                // Using CupertinoListTile with CupertinoSwitch
                                title: const Text('Applying for Residence?'),
                                trailing: CupertinoSwitch(
                                  value: _applyingForResidence,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _applyingForResidence = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              CupertinoListTile(
                                // Using CupertinoListTile with CupertinoSwitch
                                title: const Text(
                                  'Applying for Funding/Bursary?',
                                ),
                                trailing: CupertinoSwitch(
                                  value: _applyingForFunding,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _applyingForFunding = value;
                                    });
                                  },
                                ),
                              ),

                              const SizedBox(height: 10),
                              _buildCupertinoTextField(
                                controller: _parent1NameController,
                                placeholder: 'Parent/Guardian 1 Full Name',
                                prefixIcon: CupertinoIcons.person_solid,
                                readOnly: hasExistingData,
                              ),
                              _buildCupertinoTextField(
                                controller: _parent1OccupationController,
                                placeholder: 'Parent/Guardian 1 Occupation',
                                prefixIcon: CupertinoIcons.bag_fill,
                                readOnly: hasExistingData,
                              ),
                              if (_applyingForFunding)
                                _buildCupertinoTextField(
                                  controller: _parent1IncomeController,
                                  placeholder:
                                      'Parent/Guardian 1 Annual Income',
                                  prefixIcon:
                                      CupertinoIcons.money_dollar_circle_fill,
                                  keyboardType: TextInputType.number,
                                  readOnly: hasExistingData,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Submit Button
                          CustomOutlinedButton(
                            // Keeping CustomOutlinedButton, but you might want CupertinoButton.filled
                            onPressed: _submitApplication,
                            text: 'Submit Application',
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            width: double.infinity,
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
                    CupertinoButton.filled(
                      // Cupertino button
                      onPressed: _showLoginBottomSheet,
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
