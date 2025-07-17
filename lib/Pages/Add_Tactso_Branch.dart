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
  final TextEditingController nameController = TextEditingController();
  final TextEditingController applicationLinkController =
      TextEditingController();
  final TextEditingController institutionAddressController =
      TextEditingController();
  List<XFile> imageFiles = [];
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

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
    if (nameController.text.isEmpty || imageFiles.isEmpty) return;

    List<String> imageUrls = [];
    Api().showLoading(context);
    for (var file in imageFiles) {
      final ref = FirebaseStorage.instance.ref(
        "Tactso Brances/${DateTime.now().millisecondsSinceEpoch}_${nameController.text}",
      );
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }
    final color = Theme.of(context);
    var user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text,
      password: passwordController.text,
    );
    await FirebaseFirestore.instance.collection('tactso_branches').add({
      'institutionName': nameController.text,
      'applicationLink': applicationLinkController.text,
      'email': user.user!.email,
      'uid': user.user!.uid,
      'address': institutionAddressController.text,
      'imageUrl': imageUrls,
      'isOpplicationOpen': isApplicationOpen,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Navigator.pop(context);
    Api().showMessage(
      context,
      'Institution added successfully',
      'Successful',
      color.splashColor,
    );
    institutionAddressController.clear();
    nameController.clear();
    applicationLinkController.clear();
    emailController.clear();
    passwordController.clear();
    setState(() {
      imageFiles = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text('Add TACTSO Branch', style: TextStyle(fontSize: 18)),
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
                        ? Icons.add
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
            placeholder: 'Institution Name',
            controller: nameController,
          ),

          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'Institution Address',
            controller: institutionAddressController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'Institution Application link',
            controller: applicationLinkController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.email,
            placeholder: 'Email',
            controller: emailController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.password,
            placeholder: 'Password',
            controller: passwordController,
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Is Application Open?', style: TextStyle(fontSize: 16)),
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
            text: "Add Institution",
            backgroundColor: color.primaryColor,
            foregroundColor: color.scaffoldBackgroundColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
