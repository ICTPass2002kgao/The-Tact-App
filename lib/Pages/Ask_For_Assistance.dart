import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

class UploadApplicationDocumentsPage extends StatefulWidget {
  final String universityName;
  const UploadApplicationDocumentsPage({
    super.key,
    required this.universityName,
  });

  @override
  State<UploadApplicationDocumentsPage> createState() =>
      _UploadApplicationDocumentsPageState();
}

class _UploadApplicationDocumentsPageState
    extends State<UploadApplicationDocumentsPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- Form Fields Data ---
  TextEditingController _fullNameController = TextEditingController();
  TextEditingController _idPassportController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _selectedGender;
  String? _selectedNationality;
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _physicalAddressController = TextEditingController();

  TextEditingController _previousSchoolsController = TextEditingController();
  String? _highestQualification;
  List<Map<String, String>> _subjects = [];
  TextEditingController _yearCompletionController = TextEditingController();

  File? _idPassportFile;
  File? _schoolResultsFile;
  File? _proofOfRegistrationFile;
  List<File> _otherQualificationFiles = [];
  File? _passportPhotoFile;

  String? _primaryProgram;
  String? _secondChoiceProgram;
  String? _preferredStartDate;

  bool? _applyingForResidence;
  bool? _applyingForFunding;
  TextEditingController _parent1NameController = TextEditingController();
  TextEditingController _parent1OccupationController = TextEditingController();
  TextEditingController _parent1IncomeController = TextEditingController();
  TextEditingController _parent2NameController = TextEditingController();
  TextEditingController _parent2OccupationController = TextEditingController();
  TextEditingController _parent2IncomeController = TextEditingController();

  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoadingAuth = true; // For initial auth check
  bool _hasExistingApplication = false; // To check if user already applied

  @override
  void initState() {
    super.initState();
    _checkCurrentUserAndApplications();
  }

  Future<void> _checkCurrentUserAndApplications() async {
    setState(() {
      _isLoadingAuth = true;
    });
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _isLoggedIn = true;
      await _fetchUserDetails();
      await _checkExistingApplications(); // Check for existing applications
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
      }
      setState(() {}); // Update UI with pre-filled data
    }
  }

  // New method to check for existing applications
  Future<void> _checkExistingApplications() async {
    if (_currentUser != null) {
      QuerySnapshot applicationSnapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('university_applications')
          .limit(1) // Just need to know if at least one exists
          .get();
      setState(() {
        _hasExistingApplication = applicationSnapshot.docs.isNotEmpty;
      });
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
              Navigator.pop(context); // Close bottom sheet
              _checkCurrentUserAndApplications(); // Re-check user status and applications
            },
          ),
        );
      },
    ).whenComplete(() {
      if (!_isLoggedIn) {
        Navigator.pop(context); // Go back if not logged in after closing
      }
    });
  }

  // --- File Picking Functions (Same as before) ---
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
    if (!_formKey.currentState!.validate()) {
      Api().showMessage(
        context,
        'Please fill all required fields.',
        '',
        Theme.of(context).primaryColorDark,
      );
      return;
    }
    if (_currentUser == null) {
      Api().showMessage(
        context,
        'login to submit your application',
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

    try {
      // 1. Upload Documents to Firebase Storage
      // Use _currentUser!.uid to create unique paths for each user
      String storagePathPrefix = 'applications/${_currentUser!.uid}/';

      String? idPassportUrl = await _uploadFile(
        _idPassportFile!,
        '${storagePathPrefix}id_passport.pdf',
      );
      String? schoolResultsUrl = await _uploadFile(
        _schoolResultsFile!,
        '${storagePathPrefix}school_results.pdf',
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
      String? passportPhotoUrl = await _uploadFile(
        _passportPhotoFile!,
        '${storagePathPrefix}passport_photo.jpg',
      );

      // 2. Prepare Application Data for Firestore
      Map<String, dynamic> applicationData = {
        'userId': _currentUser!.uid,
        'email': _emailController.text,
        'fullName': _fullNameController.text,
        'idPassportNumber': _idPassportController.text,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'gender': _selectedGender,
        'nationality': _selectedNationality,
        'phone': _phoneController.text,
        'physicalAddress': _physicalAddressController.text,
        'previousSchools': _previousSchoolsController.text,
        'highestQualification': _highestQualification,
        'subjectsAndMarks': _subjects,
        'yearOfCompletion': _yearCompletionController.text,
        'primaryProgram': _primaryProgram,
        'secondChoiceProgram': _secondChoiceProgram,
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
      };

      // 3. Save to `application_requests` collection (for university)
      DocumentReference applicationRequestRef = await _firestore
          .collection('application_requests')
          .add({
            'userId': _currentUser!.uid,
            'applicationDetails': applicationData, // Embed all details
            'submissionDate': FieldValue.serverTimestamp(),
            'status': 'New', // Status for university's queue
            'universityId': 'your_university_id', // Replace with actual ID
          });

      // 4. Save to user's `university_applications` sub-collection
      // Link the user's application to the central request
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('university_applications')
          .add({
            'applicationDetails': applicationData, // Embed all details
            'submissionDate': FieldValue.serverTimestamp(),
            'status': 'Submitted', // Status for user's record
            'applicationRequestId':
                applicationRequestRef.id, // Reference to central request
          });
      Api().showMessage(
        context,
        'Uploaded successfully',
        '',
        Theme.of(context).splashColor,
      );

      // Update local state to prevent re-submission from the same page
      setState(() {
        _hasExistingApplication = true;
      });

      // Optionally navigate away or provide option to view status
      Navigator.pop(context); // Go back to the previous page
    } catch (e) {
      Api().showMessage(
        context,
        'Error submitting you application ${e.toString()}',
        '',
        Theme.of(context).primaryColorDark,
      );
      print('Submission error: $e');
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return Scaffold(
        appBar: AppBar(title: const Text('Application Form')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      // This case should be handled by the bottom sheet appearing on load.
      // If user closes bottom sheet, they are popped from this page.
      return Scaffold(
        appBar: AppBar(title: const Text('Application Form')),
        body: const Center(
          child: Text('Please log in to access the application form.'),
        ),
      );
    }

    if (_hasExistingApplication) {
      final color = Theme.of(context);
      return Scaffold(
        appBar: AppBar(
          title: const Text('University Application'),
          backgroundColor: color.primaryColor,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'You have already submitted a university application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'If you need assistance or wish to apply to another university, please contact support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    // Implement logic to contact assistance, e.g., open email client
                    print('User requests assistance.');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening support contact options...'),
                      ),
                    );
                    // Example: launchUrl(Uri.parse('mailto:support@example.com?subject=University Application Assistance'));
                  },
                  icon: const Icon(Icons.help_outline, color: Colors.white),
                  label: const Text(
                    'Request Assistance',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Go back to previous page
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- Original Form UI (if no existing application) ---
    final color = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New University Application'),
        backgroundColor: color.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [ 
              _buildSectionTitle('1. Personal Information'),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name (as on ID/Passport)',
                ),
                readOnly: _currentUser != null,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _idPassportController,
                decoration: const InputDecoration(
                  labelText: 'ID Number or Passport Number',
                ),
                keyboardType: TextInputType.text,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              ListTile(
                title: Text(
                  _dateOfBirth == null
                      ? 'Date of Birth'
                      : 'Date of Birth: ${DateFormat('yyyy-MM-dd').format(_dateOfBirth!)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(
                      const Duration(days: 365 * 18),
                    ),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dateOfBirth = pickedDate;
                    });
                  }
                },
              ),
              _buildExpansionTile(
                title: 'Gender',
                children: [
                  RadioListTile<String>(
                    title: const Text('Male'),
                    value: 'Male',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Female'),
                    value: 'Female',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Prefer not to say'),
                    value: 'Prefer not to say',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                ],
                currentValue: _selectedGender,
              ),
              _buildExpansionTile(
                title: 'Nationality',
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedNationality,
                    hint: const Text('Select Nationality'),
                    items: ['South African', 'Zimbabwean', 'Botswanan', 'Other']
                        .map(
                          (country) => DropdownMenuItem(
                            value: country,
                            child: Text(country),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedNationality = value;
                      });
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
                currentValue: _selectedNationality,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
              ),
              TextFormField(
                controller: _physicalAddressController,
                decoration: const InputDecoration(
                  labelText: 'Physical & Postal Address',
                ),
                maxLines: 3,
                readOnly: _currentUser != null,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // Academic History Section
              _buildSectionTitle('2. Academic History'),
              TextFormField(
                controller: _previousSchoolsController,
                decoration: const InputDecoration(
                  labelText: 'Name(s) of previous schools/institutions',
                ),
                maxLines: 2,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
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
                              (qual) => DropdownMenuItem(
                                value: qual,
                                child: Text(qual),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _highestQualification = value;
                      });
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
                currentValue: _highestQualification,
              ),
              _buildSubjectList(),
              TextFormField(
                controller: _yearCompletionController,
                decoration: const InputDecoration(
                  labelText: 'Year of Completion of Last Qualification',
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value!.isEmpty || int.tryParse(value) == null
                    ? 'Valid year required'
                    : null,
              ),
              const SizedBox(height: 20),

              // Supporting Documents Section
              _buildSectionTitle('3. Supporting Documents'),
              _buildFilePickerTile(
                title: 'Certified Copy of ID or Passport',
                file: _idPassportFile,
                onPick: (file) => _pickFile((p0) => _idPassportFile = p0),
              ),
              _buildFilePickerTile(
                title: 'Latest School Results or Final Grade 12 Results',
                file: _schoolResultsFile,
                onPick: (file) => _pickFile((p0) => _schoolResultsFile = p0),
              ),
              _buildFilePickerTile(
                title: 'Proof of Registration (if transferring)',
                file: _proofOfRegistrationFile,
                onPick: (file) =>
                    _pickFile((p0) => _proofOfRegistrationFile = p0),
                isOptional: true,
              ),
              _buildMultipleFilePickerTile(
                title: 'Certificates for Other Qualifications (if applicable)',
                files: _otherQualificationFiles,
                onPick: (files) =>
                    _pickMultipleFiles((p0) => _otherQualificationFiles = p0),
                isOptional: true,
              ),
              _buildFilePickerTile(
                title: 'Passport-sized Photo',
                file: _passportPhotoFile,
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
                      });
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
                currentValue: _primaryProgram,
              ),
              _buildExpansionTile(
                title: 'Second Choice of Course (Optional)',
                children: [
                  DropdownButtonFormField<String>(
                    value: _secondChoiceProgram,
                    hint: const Text('Select Second Choice (Optional)'),
                    items:
                        [
                              'BSc Computer Science',
                              'BA Psychology',
                              'BCom Accounting',
                              'BEng Civil Engineering',
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
                      });
                    },
                  ),
                ],
                currentValue: _secondChoiceProgram,
              ),
              const SizedBox(height: 20),

              // Financial & Residence Details Section
              _buildSectionTitle('5. Financial & Residence Details'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you applying for university residence/accommodation?',
                    style: TextStyle(fontSize: 16),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Yes'),
                          value: true,
                          groupValue: _applyingForResidence,
                          onChanged: (value) {
                            setState(() {
                              _applyingForResidence = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('No'),
                          value: false,
                          groupValue: _applyingForResidence,
                          onChanged: (value) {
                            setState(() {
                              _applyingForResidence = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_applyingForResidence == true)
                    const Padding(
                      padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                      child: Text(
                        'Note: Complete a separate residence application.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you applying for funding/bursaries?',
                    style: TextStyle(fontSize: 16),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('Yes'),
                          value: true,
                          groupValue: _applyingForFunding,
                          onChanged: (value) {
                            setState(() {
                              _applyingForFunding = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('No'),
                          value: false,
                          groupValue: _applyingForFunding,
                          onChanged: (value) {
                            setState(() {
                              _applyingForFunding = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_applyingForFunding == true) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                      child: Text(
                        'Additional forms may be needed for financial aid.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _parent1NameController,
                      decoration: const InputDecoration(
                        labelText: 'Parent/Guardian 1 Full Name',
                      ),
                      validator: (value) =>
                          _applyingForFunding == true && value!.isEmpty
                          ? 'Required for funding'
                          : null,
                    ),
                    TextFormField(
                      controller: _parent1OccupationController,
                      decoration: const InputDecoration(
                        labelText: 'Parent/Guardian 1 Occupation',
                      ),
                      validator: (value) =>
                          _applyingForFunding == true && value!.isEmpty
                          ? 'Required for funding'
                          : null,
                    ),
                    TextFormField(
                      controller: _parent1IncomeController,
                      decoration: const InputDecoration(
                        labelText: 'Parent/Guardian 1 Annual Income',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          _applyingForFunding == true &&
                              (value!.isEmpty || double.tryParse(value) == null)
                          ? 'Required for funding'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _parent2NameController,
                      decoration: const InputDecoration(
                        labelText: 'Parent/Guardian 2 Full Name (Optional)',
                      ),
                    ),
                    TextFormField(
                      controller: _parent2OccupationController,
                      decoration: const InputDecoration(
                        labelText: 'Parent/Guardian 2 Occupation (Optional)',
                      ),
                    ),
                    TextFormField(
                      controller: _parent2IncomeController,
                      decoration: const InputDecoration(
                        labelText: 'Parent/Guardian 2 Annual Income (Optional)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              CustomOutlinedButton(
                onPressed: _submitApplication,
                text: 'Submit Application',
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                width: double.infinity,
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widgets (unchanged from previous response)
  Widget _buildSectionTitle(String title) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color.primaryColor,
        ),
      ),
    );
  }

  Widget _buildExpansionTile({
    required String title,
    required List<Widget> children,
    String? currentValue,
  }) {
    return ExpansionTile(
      title: Text(title + (currentValue != null ? ': $currentValue' : '')),
      children: children,
    );
  }

  Widget _buildFilePickerTile({
    required String title,
    required File? file,
    required Function(File?) onPick,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            title + (isOptional ? ' (Optional)' : ''),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                file != null
                    ? 'Selected: ${file.path.split('/').last}'
                    : 'No file selected',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () => onPick(file),
            ),
            if (file != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    onPick(null);
                  });
                },
              ),
          ],
        ),
        if (file != null &&
            ['.jpg', '.jpeg', '.png'].contains(
              file.path.toLowerCase().substring(file.path.lastIndexOf('.')),
            ))
          Container(
            height: 100,
            width: 100,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: Image.file(file, fit: BoxFit.cover),
          ),
      ],
    );
  }

  Widget _buildMultipleFilePickerTile({
    required String title,
    required List<File> files,
    required Function(List<File>) onPick,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            title + (isOptional ? ' (Optional)' : ''),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        ...files.map(
          (file) => Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              '- ${file.path.split('/').last}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                files.isNotEmpty
                    ? '${files.length} files selected'
                    : 'No files selected',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: () => onPick(files),
            ),
            if (files.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  setState(() {
                    onPick([]);
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubjectList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Subjects and Final Marks/Results',
            style: TextStyle(fontSize: 16),
          ),
        ),
        ..._subjects.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, String> subject = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: subject['name'],
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                    ),
                    onChanged: (value) {
                      _subjects[index]['name'] = value;
                    },
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: subject['mark'],
                    decoration: const InputDecoration(labelText: 'Mark (%)'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _subjects[index]['mark'] = value;
                    },
                    validator: (value) =>
                        value!.isEmpty || int.tryParse(value) == null
                        ? 'Required'
                        : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    setState(() {
                      _subjects.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _subjects.add({'name': '', 'mark': ''});
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
          ),
        ),
      ],
    );
  }
}

// --- Login Bottom Sheet Widget (unchanged) ---
class _LoginBottomSheet extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const _LoginBottomSheet({required this.onLoginSuccess});

  @override
  State<_LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<_LoginBottomSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      widget.onLoginSuccess();
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please check your credentials.';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Log In to Continue',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _login,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: color.primaryColor,
          ),
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: color.primaryColor),
                )
              : Text(
                  'Login',
                  style: TextStyle(fontSize: 18, color: color.primaryColor),
                ),
        ),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigate to registration page...')),
            );
          },
          child: const Text('Don\'t have an account? Register Here'),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
