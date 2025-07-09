import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/TextField.dart';

class AdminAddProduct extends StatefulWidget {
  const AdminAddProduct({super.key});

  @override
  State<AdminAddProduct> createState() => _AdminAddProductState();
}

class _AdminAddProductState extends State<AdminAddProduct> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  List<XFile> imageFiles = [];

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  Future<void> uploadProduct() async {
    if (nameController.text.isEmpty || imageFiles.isEmpty) return;
    Api().showLoading(context);
    List<String> imageUrls = [];

    for (var file in imageFiles) {
      final ref = FirebaseStorage.instance.ref(
        "products/${DateTime.now().millisecondsSinceEpoch}_${file.name}",
      );
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }

    await FirebaseFirestore.instance.collection('products').add({
      'name': nameController.text,
      'description': descController.text,
      'imageUrl': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final color = Theme.of(context);

    Api().showMessage(
      context,
      'The ${nameController.text} have been added',
      '',
      color.splashColor,
    );
    Navigator.of(context);

    nameController.clear();
    descController.clear();
    setState(() {
      imageFiles = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Products', style: TextStyle(fontSize: 18)),
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
            placeholder: 'Product Name',
            controller: nameController,
          ),
          AuthTextField(
            onValidate: TextFieldValidation.name,
            placeholder: 'Product Description',
            controller: descController,
          ),
          SizedBox(height: 20),
          CustomOutlinedButton(
            onPressed: () async => await uploadProduct(),
            text: "Upload Product",
            backgroundColor: color.primaryColor,
            foregroundColor: color.scaffoldBackgroundColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
