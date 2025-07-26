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
  // NEW: Controller for the overall University Name (e.g., "North-West University")
  final TextEditingController universityNameController =
      TextEditingController();
  // RENAMED for clarity: This is now the Campus Name (e.g., "Potchefstroom Campus")
  final TextEditingController campusNameController = TextEditingController();

  final TextEditingController applicationLinkController =
      TextEditingController();
  final TextEditingController institutionAddressController =
      TextEditingController();
  List<XFile> imageFiles = [];
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController =
      TextEditingController(); // This will be the campus-specific email

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  bool isApplicationOpen = false;
  Future<void> _addTactsoBranch() async {
    // Basic validation to ensure required fields are not empty
    if (universityNameController.text.isEmpty ||
        campusNameController.text.isEmpty ||
        applicationLinkController.text.isEmpty ||
        institutionAddressController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        imageFiles.isEmpty) {
      Api().showMessage(
        context,
        'Please fill in all fields and upload images.',
        'Error',
        Theme.of(context).colorScheme.error, // Use colorScheme for error color
      );
      return;
    }

    List<String> imageUrls = [];
    Api().showLoading(context); // Show loading indicator

    try {
      // Upload images to Firebase Storage
      for (var file in imageFiles) {
        // Create a more specific path for storage using university and campus names
        final ref = FirebaseStorage.instance.ref(
          "Tactso Branches/${universityNameController.text}/${campusNameController.text}_${DateTime.now().millisecondsSinceEpoch}",
        );
        await ref.putFile(File(file.path));
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // Create a Firebase user for this specific campus (branch) login
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController
                .text, // This is the campus-specific email for login
            password: passwordController.text,
          );

      // Add the campus details to Firestore
      await FirebaseFirestore.instance.collection('tactso_branches').add({
        'universityName':
            universityNameController.text, // Overall university name
        'campusName': campusNameController.text, // Specific campus name
        'applicationLink':
            applicationLinkController.text, // Campus-specific application link
        'email': userCredential
            .user!
            .email, // Campus-specific email (from the created user)
        'uid': userCredential.user!.uid, // UID for this campus's login account
        'address': institutionAddressController.text, // Campus-specific address
        'imageUrl': imageUrls, // Images for this specific campus
        'isApplicationOpen': isApplicationOpen,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Dismiss loading dialog on success
      Api().showMessage(
        context,
        'Campus "${campusNameController.text}" for "${universityNameController.text}" added successfully!',
        'Successful',
        Theme.of(context).splashColor, // Use splashColor for success
      );

      // Clear controllers and reset state after successful submission
      universityNameController.clear();
      campusNameController.clear();
      applicationLinkController.clear();
      institutionAddressController.clear();
      emailController.clear();
      passwordController.clear();
      setState(() {
        imageFiles = [];
        isApplicationOpen = false; // Reset the switch state
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
        'Failed to add campus: $e',
        'Error',
        Theme.of(context).colorScheme.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context); // Get theme colors dynamically
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Updated title to reflect adding a campus/branch
          Text('Add TACTSO Campus Branch', style: TextStyle(fontSize: 18)),
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
                        ? Icons
                              .check_circle_outline // Changed to a check icon if images are picked
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
          // NEW Text Field for the overall University Name
          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'University Name (e.g., North-West University)',
            controller: universityNameController,
          ),
          // RENAMED Text Field for the specific Campus Name
          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'Campus Name (e.g., Potchefstroom Campus)',
            controller: campusNameController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation
                .name, // Consider using a more specific validation for address if available
            placeholder:
                'Campus Address', // This address is for the specific campus
            controller: institutionAddressController,
          ),
          AuthTextField(
            onValidate:
                TextFieldValidation.url, // Changed validation to URL for links
            placeholder:
                'Campus Application Link', // This link is for the specific campus
            controller: applicationLinkController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.email,
            placeholder:
                'Campus Specific Email (e.g., tactsoNWUPotchefstroom@tact.com)',
            controller: emailController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.password,
            placeholder:
                'Password for this Campus Login', // This password is for the Firebase user of this campus
            controller: passwordController,
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Updated text for clarity
              Text(
                'Is Application Open for this Campus?',
                style: TextStyle(fontSize: 16),
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
            text: "Add Campus Branch", // Updated button text
            backgroundColor: color.primaryColor,
            foregroundColor: color.scaffoldBackgroundColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
