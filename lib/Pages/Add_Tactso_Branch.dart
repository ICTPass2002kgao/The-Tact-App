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
  const AddTactsoBranch({super.key});

  @override
  State<AddTactsoBranch> createState() => _AddTactsoBranchState();
}

class _AddTactsoBranchState extends State<AddTactsoBranch> {
  final TextEditingController universityNameController = TextEditingController();
  final TextEditingController applicationLinkController = TextEditingController();
  final TextEditingController institutionAddressController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  final TextEditingController educationOfficerNameController = TextEditingController();

  List<XFile> imageFiles = []; // General University Images
  XFile? educationOfficerImageFile; // Officer face image

  final ImagePicker _picker = ImagePicker();
  final bool _isWeb = kIsWeb;

  bool isApplicationOpen = false;
  bool hasMultipleCampuses = false;
  List<TextEditingController> campusNamesControllers = [];
  List<Widget> campusNameInputFields = [];

  @override
  void initState() {
    super.initState();
    // Initialize one controller for the initial field if starting in single mode
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

  // --- File Upload Helper (Platform-Safe) ---
  Future<String> _uploadFile(XFile file, String path) async {
      final ref = FirebaseStorage.instance.ref(path);
      UploadTask uploadTask;

      if (_isWeb) {
          // Web: Upload using bytes
          final bytes = await file.readAsBytes();
          uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/${file.name.split('.').last}'));
      } else {
          // Native: Upload using dart:io.File
          uploadTask = ref.putFile(io.File(file.path));
      }
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
  }

  // --- Campus Logic (UNCHANGED) ---

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

  // --- Submission Logic (MODIFIED) ---

  Future<void> _addTactsoBranch() async {
    // 💥 MODIFIED: Basic validation for single officer
    if (universityNameController.text.isEmpty ||
        applicationLinkController.text.isEmpty ||
        institutionAddressController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        imageFiles.isEmpty ||
        educationOfficerImageFile == null ||
        educationOfficerNameController.text.isEmpty ||
        (hasMultipleCampuses &&
            campusNamesControllers.any((c) => c.text.isEmpty))) {
      Api().showMessage(
        context,
        'Please fill in all general fields, Education Officer details, campus names, and upload all images.',
        'Error',
        Theme.of(context).colorScheme.error,
      );
      return;
    }

    Api().showLoading(context);

    try {
      // 1. Upload University Images (PLATFORM-SAFE)
      List<String> imageUrls = [];
      for (var file in imageFiles) {
        final url = await _uploadFile(
          file,
          "Tactso Branches/${universityNameController.text}/University_Images/${DateTime.now().millisecondsSinceEpoch}_${file.name}",
        );
        imageUrls.add(url);
      }

      // 💥 MODIFIED: Upload Education Officer Face Image
      final educationOfficerImageUrl = await _uploadFile(
        educationOfficerImageFile!,
        "Tactso Branches/${universityNameController.text}/EducationOfficer/${educationOfficerNameController.text}_${DateTime.now().millisecondsSinceEpoch}",
      );

      // 3. Create Firebase Auth User (UNCHANGED)
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );

      // 4. Prepare Campus Data (UNCHANGED)
      List<Map<String, dynamic>> campusesData = [];
      for (var campusController in campusNamesControllers) {
          campusesData.add({'campusName': campusController.text});
      }

      // 5. Add University/Branch Details to Firestore
      await FirebaseFirestore.instance
          .collection('tactso_branches')
          .doc(userCredential.user!.uid)
          .set({
            'universityName': universityNameController.text,
            'email': userCredential.user!.email,
            'uid': userCredential.user!.uid,
            'imageUrl': imageUrls,
            'hasMultipleCampuses': hasMultipleCampuses,
            'campuses': campusesData,
            'createdAt': FieldValue.serverTimestamp(),
            'applicationLink': applicationLinkController.text,
            'address': institutionAddressController.text,
            'isApplicationOpen': isApplicationOpen,
            // 💥 MODIFIED: Officer Details for Biometric Access
            'educationOfficerName': educationOfficerNameController.text,
            'educationOfficerFaceUrl': educationOfficerImageUrl,
            'authorizedUserFaceUrls': [educationOfficerImageUrl],
          });

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      Api().showMessage(
        context,
        'University "${universityNameController.text}" and its campuses added successfully! Education Officer setup complete.',
        'Successful',
        Theme.of(context).splashColor,
      );

      // Clear controllers and reset state
      universityNameController.clear();
      applicationLinkController.clear();
      institutionAddressController.clear();
      emailController.clear();
      passwordController.clear();
      educationOfficerNameController.clear();

      setState(() {
        imageFiles = [];
        educationOfficerImageFile = null;
        isApplicationOpen = false;
        hasMultipleCampuses = false;
        // Reset campus controllers properly
        campusNamesControllers.forEach((c) => c.dispose());
        campusNamesControllers.clear();
        campusNameInputFields.clear();
        campusNamesControllers.add(TextEditingController()); // Add back the default single controller
      });
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        e.message ?? 'An authentication error occurred.',
        'Authentication Error',
        Theme.of(context).colorScheme.error,
      );
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Failed to add university/campus: $e',
        'Error',
        Theme.of(context).colorScheme.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // Ensure one controller exists for single campus mode, only if none exist
    if (!hasMultipleCampuses && campusNamesControllers.isEmpty) {
      campusNamesControllers.add(TextEditingController());
    }
    
    // Determine the list of fields based on multi-campus switch
    final List<Widget> campusFields = hasMultipleCampuses 
        ? campusNameInputFields 
        : (campusNamesControllers.isNotEmpty ? [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AuthTextField(
                onValidate: TextFieldValidation.name,
                placeholder: 'Campus Name (e.g., Main Campus)',
                controller: campusNamesControllers.first,
              ),
            ),
          ] : []);


    return Center(
      // FIX 2: Constrain the form width for desktop 
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
              
              // --- DESKTOP TWO-COLUMN SPLIT ---
              isDesktop 
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column 1: General Info & Campus Logic
                    Expanded(child: _buildGeneralInfoColumn(context, color, campusFields)),
                    const SizedBox(width: 20),
                    // Column 2: Officer & Auth Details
                    Expanded(child: _buildOfficerAndAuthColumn(context, color)),
                  ],
                )
                // MOBILE/VERTICAL LAYOUT
                : Column(
                  children: [
                    _buildGeneralInfoColumn(context, color, campusFields),
                    const SizedBox(height: 20),
                    _buildOfficerAndAuthColumn(context, color),
                  ],
                ),
              
              const SizedBox(height: 30),

              // --- Submit Button ---
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

  // --- Helper for General Info & Campus Fields ---
  Widget _buildGeneralInfoColumn(BuildContext context, ThemeData color, List<Widget> campusFields) {
      return Card(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text('1. University Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primaryColor)),
                const SizedBox(height: 10),
                AuthTextField(onValidate: TextFieldValidation.name, placeholder: 'University Name', controller: universityNameController),
                AuthTextField(onValidate: TextFieldValidation.url, placeholder: 'Overall Application Link', controller: applicationLinkController),
                AuthTextField(onValidate: TextFieldValidation.name, placeholder: 'University Main Address', controller: institutionAddressController),
                
                const SizedBox(height: 20),
                
                // --- General University Images Picker ---
                Text('2. University/Campus Images (Min 1)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        border: Border.all(color: color.primaryColor.withOpacity(0.5), width: 1),
                      ),
                      child: Center(
                        child: Icon(imageFiles.isNotEmpty ? Icons.check_circle_outline : Icons.add_a_photo_outlined, size: 40, color: imageFiles.isNotEmpty ? Colors.green : color.primaryColor),
                      ),
                    ),
                  ),
                ),
                if (imageFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Wrap(
                      spacing: 10, runSpacing: 10,
                      children: imageFiles.map((file) {
                          // PLATFORM-SAFE Image Preview
                          return ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildImagePreview(file, 60));
                      }).toList(),
                    ),
                  ),
                  
                const SizedBox(height: 20),
                
                // --- Campus Logic Section ---
                Text('3. Campus/Branch Structure', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primaryColor)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(child: Text('Multiple Campuses?')),
                    Switch(
                      activeTrackColor: color.splashColor,
                      value: hasMultipleCampuses,
                      onChanged: (value) {
                        setState(() {
                          hasMultipleCampuses = value;
                          // Complex state reset logic remains handled by parent functions
                          if (!hasMultipleCampuses && campusNamesControllers.length > 1) {
                            campusNamesControllers.removeRange(1, campusNamesControllers.length);
                            campusNameInputFields.clear();
                          } else if (hasMultipleCampuses && campusNamesControllers.isEmpty) {
                            _addCampusInputField();
                          }
                        });
                      },
                      activeColor: color.scaffoldBackgroundColor,
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
                
                // Application Status Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(child: Text('Applications Currently Open?')),
                    Switch(
                      activeTrackColor: color.splashColor,
                      value: isApplicationOpen,
                      onChanged: (value) => setState(() => isApplicationOpen = value),
                      activeColor: color.scaffoldBackgroundColor,
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
  }
  
  // --- Helper for Officer & Auth Details Column ---
  Widget _buildOfficerAndAuthColumn(BuildContext context, ThemeData color) {
      return Card(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text('4. Education Officer & Admin Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primaryColor)),
                const SizedBox(height: 10),
                
                // Officer Details
                AuthTextField(onValidate: TextFieldValidation.name, placeholder: 'Education Officer Full Name', controller: educationOfficerNameController),
                
                // Officer Biometric Image Picker
                _buildOfficerImagePicker(
                  context,
                  'Education Officer Face Image',
                  'Upload Officer Face (Required for Biometric Access)',
                  educationOfficerImageFile,
                  pickEducationOfficerImage,
                ),
                
                const SizedBox(height: 20),
                
                Text('Admin Login Credentials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.primaryColor)),
                const SizedBox(height: 10),
                
                // Auth Fields (Already defined in parent)
                AuthTextField(onValidate: TextFieldValidation.email, placeholder: 'University Admin Email', controller: emailController),
                AuthTextField(onValidate: TextFieldValidation.password, placeholder: 'Password for Admin Login', controller: passwordController),
            ],
          ),
        ),
      );
  }
  
  // Helper widget for officer image pickers
  Widget _buildOfficerImagePicker(
    BuildContext context,
    String title,
    String placeholder,
    XFile? file,
    VoidCallback onTap,
  ) {
    final color = Theme.of(context);
    return Card(
      color: Colors.transparent,
      elevation: 2,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.primaryColor.withOpacity(0.5), width: 1),
          ),
          child: Center(
            child: Text(
              file != null ? '$title Added! ✅' : placeholder,
              textAlign: TextAlign.center,
              style: TextStyle(color: file != null ? Colors.green.shade700 : color.hintColor),
            ),
          ),
        ),
      ),
    );
  }
  
  // FIX: Platform-safe image preview helper
  Widget _buildImagePreview(XFile file, double size) {
    if (_isWeb) {
        // Web: Cannot use File(file.path) directly; use placeholder
        return Container(
            width: size,
            height: size,
            color: Theme.of(context).dividerColor.withOpacity(0.5),
            child: Icon(Icons.photo, size: size * 0.5, color: Theme.of(context).hintColor),
        );
    } else {
        // Native: Use File(file.path)
        return Image.file(
            io.File(file.path),
            width: size,
            height: size,
            fit: BoxFit.cover,
        );
    }
  }
}