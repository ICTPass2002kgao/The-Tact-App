import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:ttact/Components/API.dart'; // Assuming API.dart is the file name
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/TextFields.dart';

class AddTactsoBranch extends StatefulWidget {
  const AddTactsoBranch({super.key});

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

  // 💥 MODIFIED: Education Officer Details Controllers ONLY
  final TextEditingController educationOfficerNameController =
      TextEditingController();

  List<XFile> imageFiles = []; // General University Images
  // 💥 MODIFIED: Single officer face image file
  XFile? educationOfficerImageFile;

  final ImagePicker _picker = ImagePicker();

  bool isApplicationOpen = false;
  bool hasMultipleCampuses = false;
  List<TextEditingController> campusNamesControllers = [];
  List<Widget> campusNameInputFields = [];

  @override
  void initState() {
    super.initState();
    // Start with a single campus controller if needed, but the build() handles it
  }

  @override
  void dispose() {
    universityNameController.dispose();
    applicationLinkController.dispose();
    institutionAddressController.dispose();
    passwordController.dispose();
    emailController.dispose();

    // 💥 MODIFIED: Dispose ONLY the Education Officer controller
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

  // 💥 MODIFIED: New function for Education Officer Image
  Future<void> pickEducationOfficerImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        educationOfficerImageFile = picked;
      });
    }
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
        (campusNamesControllers.isEmpty && !hasMultipleCampuses) ||
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
      // 1. Upload University Images (UNCHANGED)
      List<String> imageUrls = [];
      for (var file in imageFiles) {
        final ref = FirebaseStorage.instance.ref(
          "Tactso Branches/${universityNameController.text}/University_Images/${DateTime.now().millisecondsSinceEpoch}_${file.name}",
        );
        await ref.putFile(File(file.path));
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // 💥 MODIFIED: Upload Education Officer Face Image ONLY
      final educationOfficerRef = FirebaseStorage.instance.ref(
        "Tactso Branches/${universityNameController.text}/EducationOfficer/${educationOfficerNameController.text}_${DateTime.now().millisecondsSinceEpoch}",
      );
      await educationOfficerRef.putFile(File(educationOfficerImageFile!.path));
      final educationOfficerImageUrl = await educationOfficerRef
          .getDownloadURL();

      // 3. Create Firebase Auth User (UNCHANGED)
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );

      // 4. Prepare Campus Data (UNCHANGED)
      List<Map<String, dynamic>> campusesData = [];
      if (campusNamesControllers.isNotEmpty) {
        for (var campusController in campusNamesControllers) {
          campusesData.add({'campusName': campusController.text});
        }
      }

      // 5. Add University/Branch Details to Firestore (MODIFIED)
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
            // 💥 MODIFIED: Officer Details for Biometric Access (ONLY Education Officer)
            'educationOfficerName': educationOfficerNameController.text,
            'educationOfficerFaceUrl': educationOfficerImageUrl,
            'authorizedUserFaceUrls': [educationOfficerImageUrl],
          });

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
        for (var controller in campusNamesControllers) {
          controller.dispose();
        }
        campusNamesControllers.clear();
        campusNameInputFields.clear();
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

    // Ensure one controller exists for single campus mode, only if none exist
    if (!hasMultipleCampuses && campusNamesControllers.isEmpty) {
      campusNamesControllers.add(TextEditingController());
    } else if (hasMultipleCampuses && campusNamesControllers.isEmpty) {
      // If multiple is enabled but no fields, add one
      _addCampusInputField();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text(
            'Add TACTSO University & Campus Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // --- General University Images Picker ---
          Text(
            'University/Campus Images:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Card(
            color: Colors.transparent,
            elevation: 10,
            child: GestureDetector(
              onTap: () => pickImages(),
              child: Container(
                alignment: Alignment.center,
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.primaryColor,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignCenter,
                  ),
                ),
                child: Center(
                  child: Icon(
                    imageFiles.isNotEmpty
                        ? Icons.check_circle_outline
                        : Icons.add_a_photo_outlined,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
          if (imageFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: imageFiles.map((file) {
                  return Image.file(
                    File(file.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 20),

          // --- General University Fields ---
          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'University Name (e.g., North-West University)',
            controller: universityNameController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.url,
            placeholder: 'Overall University Application Link',
            controller: applicationLinkController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'University Main Address',
            controller: institutionAddressController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.email,
            placeholder: 'University Admin Email (e.g., admin@university.com)',
            controller: emailController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.password,
            placeholder: 'Password for University Admin Login',
            controller: passwordController,
          ),
          const SizedBox(height: 20),

          // 💥 MODIFIED: Education Officer Details for Biometric Access
          Text(
            'Biometric Access Officer (Education Officer)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
          ),
          const SizedBox(height: 10),

          // Education Officer Details
          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'Education Officer Full Name',
            controller: educationOfficerNameController,
          ),
          _buildOfficerImagePicker(
            context,
            'Education Officer Face Image',
            'Upload Education Officer Face (From Gallery/Files)',
            educationOfficerImageFile,
            pickEducationOfficerImage,
          ),
          const SizedBox(height: 20),

          // --- Campus Logic Section (UNCHANGED) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Does this University have multiple Campuses?',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              Switch(
                activeTrackColor: color.splashColor,
                value: hasMultipleCampuses,
                onChanged: (value) {
                  setState(() {
                    hasMultipleCampuses = value;
                    if (!hasMultipleCampuses) {
                      // Clear all but one controller/field
                      if (campusNamesControllers.length > 1) {
                        for (
                          var i = 1;
                          i < campusNamesControllers.length;
                          i++
                        ) {
                          campusNamesControllers[i].dispose();
                        }
                      }
                      campusNamesControllers.removeRange(
                        1,
                        campusNamesControllers.length,
                      );
                      campusNameInputFields.clear();
                      // The single remaining controller will be handled below
                    } else if (campusNamesControllers.isEmpty) {
                      _addCampusInputField(); // Ensure at least one field if switching to multiple
                    }
                  });
                },
                activeColor: color.scaffoldBackgroundColor,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Conditional display for adding campus names
          if (hasMultipleCampuses) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Campus Names:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...campusNameInputFields,
            CustomOutlinedButton(
              onPressed: _addCampusInputField,
              text: "Add Another Campus",
              backgroundColor: color.primaryColor,
              foregroundColor: color.scaffoldBackgroundColor,
              width: double.infinity,
            ),
          ] else if (campusNamesControllers.isNotEmpty) // Single campus field
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AuthTextField(
                onValidate: TextFieldValidation.name,
                placeholder:
                    'Campus Name (e.g., Main Campus or Potchefstroom Campus)',
                controller: campusNamesControllers.first,
              ),
            ),

          const SizedBox(height: 10),

          // --- Application Open Switch ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Is Application Open for this University/Campuses?',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              Switch(
                activeTrackColor: color.splashColor,
                value: isApplicationOpen,
                onChanged: (value) {
                  setState(() {
                    isApplicationOpen = value;
                  });
                },
                activeColor: color.scaffoldBackgroundColor,
              ),
            ],
          ),
          const SizedBox(height: 20),

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
    );
  }

  // Helper widget for officer image pickers (MODIFIED placeholder text)
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
      elevation: 5,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.primaryColor, width: 1),
          ),
          child: Center(
            child: Text(
              file != null ? '$title Added! ✅' : placeholder,
              textAlign: TextAlign.center,
              style: TextStyle(color: color.textTheme.bodyLarge?.color),
            ),
          ),
        ),
      ),
    );
  }
}
