// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, unnecessary_null_comparison, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/TextFields.dart';
import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb

// FIX: Alias dart:io for platform safety
import 'dart:io' as io show File;

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 700.0;
// --------------------------

class AddTactsoBranch extends StatefulWidget {

  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const AddTactsoBranch({super.key, this.uid, this.portfolio, this.fullName, this.province});

  @override
  State<AddTactsoBranch> createState() => _AddTactsoBranchState();
}

class _AddTactsoBranchState extends State<AddTactsoBranch> {
  final TextEditingController universityNameController =
      TextEditingController();
  final TextEditingController applicationLinkController =
      TextEditingController();
  final TextEditingController institutionAddressController =
      TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // 1. EDUCATION OFFICER CONTROLLERS
  final TextEditingController educationOfficerNameController =
      TextEditingController();
  XFile? educationOfficerImageFile;

  // 2. CHAIRPERSON CONTROLLERS (NEW)
  final TextEditingController chairpersonNameController =
      TextEditingController();
  XFile? chairpersonImageFile;

  List<XFile> imageFiles = []; // General University Images

  final ImagePicker _picker = ImagePicker();
  final bool _isWeb = kIsWeb;

  bool isApplicationOpen = false;
  bool hasMultipleCampuses = false;
  List<TextEditingController> campusNamesControllers = [];
  List<Widget> campusNameInputFields = [];

  @override
  void initState() {
    super.initState();
    if (!hasMultipleCampuses && campusNamesControllers.isEmpty) {
      campusNamesControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    universityNameController.dispose();
    applicationLinkController.dispose();
    institutionAddressController.dispose();
    passwordController.dispose();
    emailController.dispose();
    educationOfficerNameController.dispose();
    chairpersonNameController.dispose(); // Dispose new controller

    for (var controller in campusNamesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- Image Pickers ---

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  Future<void> pickEducationOfficerImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        educationOfficerImageFile = picked;
      });
    }
  }

  // NEW: Picker for Chairperson
  Future<void> pickChairpersonImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        chairpersonImageFile = picked;
      });
    }
  }

  // --- File Upload Helper (Platform-Safe) ---
  Future<String> _uploadFile(XFile file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    UploadTask uploadTask;

    if (_isWeb) {
      final bytes = await file.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/${file.name.split('.').last}'),
      );
    } else {
      uploadTask = ref.putFile(io.File(file.path));
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // --- Campus Logic ---
  void _addCampusInputField() {
    final newController = TextEditingController();
    campusNamesControllers.add(newController);
    setState(() {
      campusNameInputFields.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: AuthTextField(
                  onValidate: TextFieldValidation.name,
                  placeholder: 'Campus Name (e.g., Potchefstroom Campus)',
                  controller: newController,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _removeCampusInputField(newController),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _removeCampusInputField(TextEditingController controllerToRemove) {
    setState(() {
      campusNamesControllers.remove(controllerToRemove);
      campusNameInputFields.removeWhere(
        (widget) =>
            (widget is Padding &&
            (widget.child as Row).children.any(
              (child) =>
                  (child is Expanded &&
                  (child.child as AuthTextField).controller ==
                      controllerToRemove),
            )),
      );
      controllerToRemove.dispose();
    });
  }

  // --- Submission Logic ---
  Future<void> _addTactsoBranch() async {
    // Validation: Now checks for BOTH Officer and Chairperson
    if (universityNameController.text.isEmpty ||
        applicationLinkController.text.isEmpty ||
        institutionAddressController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        imageFiles.isEmpty ||
        educationOfficerImageFile == null ||
        educationOfficerNameController.text.isEmpty ||
        chairpersonImageFile == null ||
        chairpersonNameController.text.isEmpty ||
        (hasMultipleCampuses &&
            campusNamesControllers.any((c) => c.text.isEmpty))) {
      Api().showMessage(
        context,
        'Please fill in all details including Education Officer AND Chairperson (Images & Names).',
        'Error',
        Theme.of(context).colorScheme.error,
      );
      return;
    }

    Api().showLoading(context);

    try {
      // 1. Upload University Images
      List<String> imageUrls = [];
      for (var file in imageFiles) {
        final url = await _uploadFile(
          file,
          "Tactso Branches/${universityNameController.text}/University_Images/${DateTime.now().millisecondsSinceEpoch}_${file.name}",
        );
        imageUrls.add(url);
      }

      // 2. Upload Education Officer Face
      final educationOfficerImageUrl = await _uploadFile(
        educationOfficerImageFile!,
        "Tactso Branches/${universityNameController.text}/Committee/${educationOfficerNameController.text}_${DateTime.now().millisecondsSinceEpoch}",
      );

      // 3. Upload Chairperson Face
      final chairpersonImageUrl = await _uploadFile(
        chairpersonImageFile!,
        "Tactso Branches/${universityNameController.text}/Committee/${chairpersonNameController.text}_${DateTime.now().millisecondsSinceEpoch}",
      );

      // 4. Create Firebase Auth User (Shared Login)
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );

      List<Map<String, dynamic>> campusesData = [];
      for (var campusController in campusNamesControllers) {
        campusesData.add({'campusName': campusController.text});
      }

      String uid = userCredential.user!.uid;

      // 5. Add Main Branch Document
      await FirebaseFirestore.instance
          .collection('tactso_branches')
          .doc(uid)
          .set({
            'universityName': universityNameController.text,
            'email': userCredential.user!.email,
            'uid': uid,
            'imageUrl': imageUrls,
            'hasMultipleCampuses': hasMultipleCampuses,
            'campuses': campusesData,
            'createdAt': FieldValue.serverTimestamp(),
            'applicationLink': applicationLinkController.text,
            'address': institutionAddressController.text,
            'isApplicationOpen': isApplicationOpen,

            // Primary Contact (Usually Officer)
            'educationOfficerName': educationOfficerNameController.text,
            'educationOfficerFaceUrl': educationOfficerImageUrl,

            // Authorized Faces (Bot Officer AND Chair)
            'authorizedUserFaceUrls': [
              educationOfficerImageUrl,
              chairpersonImageUrl,
            ],
          });

      // 6. Add Committee Sub-Collection Entries (So they appear in the Dashboard list immediately)
      final committeeRef = FirebaseFirestore.instance
          .collection('tactso_branches')
          .doc(uid)
          .collection('committee_members');

      // Add Officer
      await committeeRef.add({
        'name': educationOfficerNameController.text,
        'email':
            'Education Officer', // Placeholder or add specific email field if needed
        'role': 'Education Officer',
        'faceUrl': educationOfficerImageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Add Chairperson
      await committeeRef.add({
        'name': chairpersonNameController.text,
        'email': 'Chairperson',
        'role': 'Chairperson',
        'faceUrl': chairpersonImageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      Navigator.pop(context);
      Api().showMessage(
        context,
        'University added! Officer & Chairperson registered for biometric access.',
        'Successful',
        Theme.of(context).splashColor,
      );

      // Reset
      _clearForm();
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        e.message ?? 'Auth Error',
        'Error',
        Theme.of(context).colorScheme.error,
      );
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Failed: $e',
        'Error',
        Theme.of(context).colorScheme.error,
      );
    }
  }

  void _clearForm() {
    universityNameController.clear();
    applicationLinkController.clear();
    institutionAddressController.clear();
    emailController.clear();
    passwordController.clear();
    educationOfficerNameController.clear();
    chairpersonNameController.clear();

    setState(() {
      imageFiles = [];
      educationOfficerImageFile = null;
      chairpersonImageFile = null;
      isApplicationOpen = false;
      hasMultipleCampuses = false;
      campusNamesControllers.forEach((c) => c.dispose());
      campusNamesControllers.clear();
      campusNameInputFields.clear();
      campusNamesControllers.add(TextEditingController());
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (!hasMultipleCampuses && campusNamesControllers.isEmpty) {
      campusNamesControllers.add(TextEditingController());
    }

    final List<Widget> campusFields = hasMultipleCampuses
        ? campusNameInputFields
        : (campusNamesControllers.isNotEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: AuthTextField(
                      onValidate: TextFieldValidation.name,
                      placeholder: 'Campus Name (e.g., Main Campus)',
                      controller: campusNamesControllers.first,
                    ),
                  ),
                ]
              : []);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Text(
                'Add TACTSO University Branch',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildGeneralInfoColumn(
                            context,
                            color,
                            campusFields,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildOfficerAndAuthColumn(context, color),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildGeneralInfoColumn(context, color, campusFields),
                        const SizedBox(height: 20),
                        _buildOfficerAndAuthColumn(context, color),
                      ],
                    ),

              const SizedBox(height: 30),

              CustomOutlinedButton(
                onPressed: _addTactsoBranch,
                text: "Add University & Campuses",
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                width: double.infinity,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Components ---
  Widget _buildGeneralInfoColumn(
    BuildContext context,
    ThemeData color,
    List<Widget> campusFields,
  ) {
    return Card(
      color: color.scaffoldBackgroundColor,
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. University Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            AuthTextField(
              onValidate: TextFieldValidation.name,
              placeholder: 'University Name',
              controller: universityNameController,
            ),
            AuthTextField(
              onValidate: TextFieldValidation.url,
              placeholder: 'Overall Application Link',
              controller: applicationLinkController,
            ),
            AuthTextField(
              onValidate: TextFieldValidation.name,
              placeholder: 'University Main Address',
              controller: institutionAddressController,
            ),

            const SizedBox(height: 20),
            Text(
              '2. University Images (Min 1)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Card(
              color: Colors.transparent,
              elevation: 2,
              child: GestureDetector(
                onTap: pickImages,
                child: Container(
                  alignment: Alignment.center,
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: color.primaryColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      imageFiles.isNotEmpty
                          ? Icons.check_circle_outline
                          : Icons.add_a_photo_outlined,
                      size: 40,
                      color: imageFiles.isNotEmpty
                          ? Colors.green
                          : color.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            if (imageFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: imageFiles.map((file) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImagePreview(file, 60),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 20),
            Text(
              '3. Campus Structure',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(child: Text('Multiple Campuses?')),
                Switch(
                  value: hasMultipleCampuses,
                  onChanged: (value) {
                    setState(() {
                      hasMultipleCampuses = value;
                      if (!hasMultipleCampuses &&
                          campusNamesControllers.length > 1) {
                        campusNamesControllers.removeRange(
                          1,
                          campusNamesControllers.length,
                        );
                        campusNameInputFields.clear();
                      } else if (hasMultipleCampuses &&
                          campusNamesControllers.isEmpty) {
                        _addCampusInputField();
                      }
                    });
                  },
                  activeColor: color.scaffoldBackgroundColor,
                  activeTrackColor: color.primaryColor,
                ),
              ],
            ),
            ...campusFields,
            if (hasMultipleCampuses)
              CustomOutlinedButton(
                onPressed: _addCampusInputField,
                text: "Add Another Campus",
                backgroundColor: color.primaryColor.withOpacity(0.1),
                foregroundColor: color.primaryColor,
                width: double.infinity,
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(child: Text('Applications Open?')),
                Switch(
                  value: isApplicationOpen,
                  onChanged: (value) =>
                      setState(() => isApplicationOpen = value),
                  activeColor: color.scaffoldBackgroundColor,
                  activeTrackColor: color.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficerAndAuthColumn(BuildContext context, ThemeData color) {
    return Card(
      elevation: 5,
      color: color.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. Committee (Biometric Access)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            const SizedBox(height: 10),

            // --- EDUCATION OFFICER ---
            Text(
              "Education Officer",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            AuthTextField(
              onValidate: TextFieldValidation.name,
              placeholder: 'Officer Full Name',
              controller: educationOfficerNameController,
            ),
            _buildOfficerImagePicker(
              context,
              'Officer Face',
              'Upload Officer Face',
              educationOfficerImageFile,
              pickEducationOfficerImage,
            ),

            const SizedBox(height: 15),

            // --- CHAIRPERSON ---
            Text(
              "Chairperson",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            AuthTextField(
              onValidate: TextFieldValidation.name,
              placeholder: 'Chairperson Full Name',
              controller: chairpersonNameController,
            ),
            _buildOfficerImagePicker(
              context,
              'Chairperson Face',
              'Upload Chairperson Face',
              chairpersonImageFile,
              pickChairpersonImage,
            ),

            const SizedBox(height: 20),
            Divider(),
            const SizedBox(height: 10),

            Text(
              '5. Shared Login Credentials',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            Text(
              'Used by all committee members to access the biometric check.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            AuthTextField(
              onValidate: TextFieldValidation.email,
              placeholder: 'Branch Email Address',
              controller: emailController,
            ),
            AuthTextField(
              onValidate: TextFieldValidation.password,
              placeholder: 'Shared Password',
              controller: passwordController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficerImagePicker(
    BuildContext context,
    String title,
    String placeholder,
    XFile? file,
    VoidCallback onTap,
  ) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Card(
        color: Colors.transparent,
        elevation: 2,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.primaryColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  file != null ? Icons.check_circle : Icons.face,
                  color: file != null ? Colors.green : color.hintColor,
                ),
                SizedBox(width: 8),
                Text(
                  file != null ? '$title Added' : placeholder,
                  style: TextStyle(
                    color: file != null ? Colors.green : color.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(XFile file, double size) {
    if (_isWeb) {
      return Container(
        width: size,
        height: size,
        color: Theme.of(context).dividerColor.withOpacity(0.5),
        child: Icon(
          Icons.photo,
          size: size * 0.5,
          color: Theme.of(context).hintColor,
        ),
      );
    } else {
      return Image.file(
        io.File(file.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
  }
}
