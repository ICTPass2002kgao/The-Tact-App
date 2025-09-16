import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:ttact/Components/API.dart';
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

  List<XFile> imageFiles = [];
  final ImagePicker _picker = ImagePicker();

  bool isApplicationOpen = false;

  // NEW: State for handling multiple campuses
  bool hasMultipleCampuses = false;
  List<TextEditingController> campusNamesControllers = [];
  List<Widget> campusNameInputFields =
      []; // To hold the actual TextField widgets

  @override
  void initState() {
    super.initState();
    // Initially add one campus input field if not using the single campus logic
    // or if hasMultipleCampuses is true by default (though it's false here).
    // If you always want at least one campus field, uncomment this:
    // _addCampusInputField();
  }

  @override
  void dispose() {
    universityNameController.dispose();
    applicationLinkController.dispose();
    institutionAddressController.dispose();
    passwordController.dispose();
    emailController.dispose();
    for (var controller in campusNamesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  // NEW: Method to add a new campus input field dynamically
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

  // NEW: Method to remove a campus input field dynamically
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
      controllerToRemove.dispose(); // Dispose the controller when removed
    });
  }

  Future<void> _addTactsoBranch() async {
    // Basic validation to ensure required fields are not empty
    if (universityNameController.text.isEmpty ||
        applicationLinkController.text.isEmpty ||
        institutionAddressController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        imageFiles.isEmpty) {
      Api().showMessage(
        context,
        'Please fill in all general fields and upload images.',
        'Error',
        Theme.of(context).colorScheme.error,
      );
      return;
    }

    // Validate campus names if multiple campuses are enabled

    Api().showLoading(context); // Show loading indicator

    try {
      // Upload images to Firebase Storage
      List<String> imageUrls = [];
      for (var file in imageFiles) {
        final ref = FirebaseStorage.instance.ref(
          "Tactso Branches/${universityNameController.text}/${DateTime.now().millisecondsSinceEpoch}_${file.name}",
        );
        await ref.putFile(File(file.path));
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // Create a Firebase user for this specific branch (email/password)
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );

      // Prepare campus data to be stored
      List<Map<String, dynamic>> campusesData = [];
      if (hasMultipleCampuses) {
        for (var campusController in campusNamesControllers) {
          campusesData.add({'campusName': campusController.text});
        }
      } else {
        // If not multiple campuses, add a single campus using the university name
        // or a default campus name if that's your logic.
        // For now, we'll add the first campus name from the controllers,
        // which should be available if validation passed.
        if (campusNamesControllers.isNotEmpty) {
          campusesData.add({
            'campusName':
                campusNamesControllers.first.text, // Use the single campus name
          });
        }
      }

      // Add the university and campus details to Firestore
      await FirebaseFirestore.instance.collection('tactso_branches').add({
        'universityName': universityNameController.text,
        'email': userCredential.user!.email,
        'uid': userCredential.user!.uid,
        'imageUrl': imageUrls,
        'hasMultipleCampuses': hasMultipleCampuses,
        'campuses': campusesData, // Store the list of campuses
        'createdAt': FieldValue.serverTimestamp(),
        'applicationLink': applicationLinkController.text,
        'address': institutionAddressController.text,
        'isApplicationOpen': isApplicationOpen,
      });

      Navigator.pop(context); // Dismiss loading dialog on success
      Api().showMessage(
        context,
        'University "${universityNameController.text}" and its campuses added successfully!',
        'Successful',
        Theme.of(context).splashColor,
      );

      // Clear controllers and reset state after successful submission
      universityNameController.clear();
      applicationLinkController.clear();
      institutionAddressController.clear();
      emailController.clear();
      passwordController.clear();
      setState(() {
        imageFiles = [];
        isApplicationOpen = false;
        hasMultipleCampuses = false;
        for (var controller in campusNamesControllers) {
          controller.dispose(); // Dispose each controller
        }
        campusNamesControllers.clear();
        campusNameInputFields.clear();
      });
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context); // Dismiss loading dialog on FirebaseAuth error
      Api().showMessage(
        context,
        e.message ?? 'An authentication error occurred.',
        'Authentication Error',
        Theme.of(context).colorScheme.error,
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss loading dialog on any other error
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text(
            'Add TACTSO University & Campus Details',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 20),
          Card(
            color: Colors.transparent,
            elevation: 10,
            child: GestureDetector(
              onTap: () => pickImages(),
              child: Container(
                alignment: Alignment.center,
                height: 250,
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
                children: imageFiles.map((file) {
                  return Image.file(
                    File(file.path),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  );
                }).toList(),
              ),
            ),
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
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Does this University have multiple Campuses?',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              Switch(
                activeTrackColor: color.splashColor,
                inactiveTrackColor: color.primaryColorDark,
                inactiveThumbColor: color.scaffoldBackgroundColor,
                focusColor: color.scaffoldBackgroundColor,
                value: hasMultipleCampuses,
                onChanged: (value) {
                  setState(() {
                    hasMultipleCampuses = value;
                    if (!hasMultipleCampuses) {
                      // Clear campus fields if switch is turned off
                      for (var controller in campusNamesControllers) {
                        controller.dispose();
                      }
                      campusNamesControllers.clear();
                      campusNameInputFields.clear();
                      // Add one default campus field if you want one to always exist
                      // _addCampusInputField(); // uncomment if you always want one default
                    } else {
                      // If enabling multiple campuses, ensure at least one input field exists
                      if (campusNamesControllers.isEmpty) {
                        _addCampusInputField();
                      }
                    }
                  });
                },
                activeColor: color.scaffoldBackgroundColor,
              ),
            ],
          ),
          SizedBox(height: 10),
          // Conditional display for adding campus names
          if (hasMultipleCampuses) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add Campus Names:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...campusNameInputFields, // Display dynamically added campus fields
            CustomOutlinedButton(
              onPressed: _addCampusInputField,
              text: "Add Another Campus",
              backgroundColor: color.primaryColor,
              foregroundColor: color.scaffoldBackgroundColor,
              width: double.infinity,
            ),
          ] else if (campusNamesControllers
              .isEmpty) // If not multiple campuses, but no campus field exists, add one.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: AuthTextField(
                onValidate: TextFieldValidation.name,
                placeholder: 'Campus Name (e.g., Main Campus)',
                controller: () {
                  // Ensure there's always one controller for single campus mode
                  if (campusNamesControllers.isEmpty) {
                    campusNamesControllers.add(TextEditingController());
                  }
                  return campusNamesControllers.first;
                }(),
              ),
            ),

          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Is Application Open for this University/Campuses?',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              Switch(
                activeTrackColor: color.splashColor,
                inactiveTrackColor: color.primaryColorDark,
                inactiveThumbColor: color.scaffoldBackgroundColor,
                focusColor: color.scaffoldBackgroundColor,
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
          SizedBox(height: 20),
          CustomOutlinedButton(
            onPressed: _addTactsoBranch,
            text: "Add University & Campuses",
            backgroundColor: color.primaryColor,
            foregroundColor: color.scaffoldBackgroundColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
