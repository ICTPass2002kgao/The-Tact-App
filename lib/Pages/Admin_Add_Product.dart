// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/TextField.dart';
import 'package:flutter/foundation.dart';

// FIX: Alias dart:io for platform safety
import 'dart:io' as io show File;

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
  final bool _isWeb = kIsWeb; // Determine platform once

  Future<void> pickImages() async {
    // ImagePicker works cross-platform for multi-image picking
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  Future<void> uploadProduct() async {
    final color = Theme.of(context);

    if (nameController.text.isEmpty ||
        descController.text.isEmpty ||
        selectedCategory.isEmpty ||
        imageFiles.isEmpty) {
      Api().showMessage(
        context,
        'Missing Fields',
        'Please fill in product name, description, category, and select at least one image.',
        color.primaryColorDark,
      );
      return;
    }

    Api().showLoading(context);
    List<String> imageUrls = [];

    try {
      for (var file in imageFiles) {
        final fileName =
            "products/${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = FirebaseStorage.instance.ref(fileName);

        if (_isWeb) {
          // FIX 1a: Upload using bytes for web safety
          final bytes = await file.readAsBytes();
          await ref.putData(bytes);
        } else {
          // FIX 1b: Upload using File for native
          await ref.putFile(io.File(file.path));
        }

        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      await FirebaseFirestore.instance.collection('products').add({
        'name': nameController.text,
        'description': descController.text,
        'imageUrl': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'category': selectedCategory,
        'isAvailable': true, // New field for stock status
      });

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading

      Api().showMessage(
        context,
        'The ${nameController.text} have been added',
        'Success',
        color.splashColor,
      );

      nameController.clear();
      descController.clear();
      setState(() {
        imageFiles = [];
        selectedCategory = '';
      });
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading
      Api().showMessage(
        context,
        'Error uploading product: ${e.toString()}',
        'Error',
        color.primaryColorDark,
      );
      print('Upload error: $e');
    }
  }

  String selectedCategory = '';
  List categories = [
    'Shirts & Polos',
    'Suits & Jackets',
    'Trousers & Skirts',
    'Footwear',
    'Accessories',
    'Hats',
    'Shoes',
  ];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Center(
      // FIX 2: Constrain the form width for desktop
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload New Product',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.primaryColor,
                ),
              ),
              SizedBox(height: 20),

              // --- Image Picker Area ---
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: GestureDetector(
                  onTap: () => pickImages(),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color.scaffoldBackgroundColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: color.primaryColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            imageFiles.isNotEmpty
                                ? Icons.check_circle_outline
                                : Icons.add_a_photo_outlined,
                            size: 50,
                            color: imageFiles.isNotEmpty
                                ? Colors.green
                                : color.primaryColor,
                          ),
                          SizedBox(height: 8),
                          Text(
                            imageFiles.isNotEmpty
                                ? '${imageFiles.length} Image(s) Selected'
                                : 'Tap to Select Images',
                            style: TextStyle(color: color.hintColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10),

              // --- Image Preview ---
              if (imageFiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: imageFiles.map((file) {
                      // FIX 3: Conditional image display
                      Widget imagePreview;
                      if (_isWeb) {
                        // Web: Cannot use File(file.path) directly; use placeholder
                        imagePreview = Container(
                          width: 80,
                          height: 80,
                          color: color.dividerColor.withOpacity(0.5),
                          child: Icon(
                            Icons.photo,
                            size: 40,
                            color: color.hintColor,
                          ),
                        );
                      } else {
                        // Native: Use File(file.path)
                        imagePreview = Image.file(
                          io.File(file.path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imagePreview,
                      );
                    }).toList(),
                  ),
                ),
              SizedBox(height: 10),

              // --- Form Fields ---
              AuthTextField(
                onValidate: TextFieldValidation.name,
                placeholder: 'Product Name',
                controller: nameController,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value: selectedCategory.isNotEmpty ? selectedCategory : null,
                  items: categories
                      .map<DropdownMenuItem<String>>(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value ?? '';
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Select Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Category is required'
                      : null,
                ),
              ),

              AuthTextField(
                onValidate: TextFieldValidation.name,
                placeholder: 'Product Description',
                controller: descController,
              ),

              SizedBox(height: 20),

              // --- Upload Button ---
              CustomOutlinedButton(
                onPressed: () async => await uploadProduct(),
                text: "Upload Product",
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                width: double.infinity,
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
