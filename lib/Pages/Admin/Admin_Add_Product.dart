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
  final bool _isWeb = kIsWeb;

  // --- 1. NEW: State to track Item Type ---
  String _selectedType = 'Product'; // Default to Product
  String _selectedCategory = '';

  // --- 2. NEW: Separate Category Lists ---
  final List<String> _productCategories = [
    'Shirts & Polos',
    'Suits & Jackets',
    'Trousers & Skirts',
    'Footwear',
    'Accessories',
    'Hats',
    'Shoes',
  ];

  final List<String> _serviceCategories = [
    'Transportation (Bus/Taxi)',
    'Tents & Marquees',
    'Sound System & DJ',
    'Mobile Toilets',
    'Chairs & Tables',
    'Catering & Food',
    'Decor & Flowers',
    'Photography & Video',
    'Security Services',
  ];

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  Future<void> uploadItem() async {
    final color = Theme.of(context);

    if (nameController.text.isEmpty ||
        descController.text.isEmpty ||
        _selectedCategory.isEmpty ||
        imageFiles.isEmpty) {
      Api().showMessage(
        context,
        'Missing Fields',
        'Please fill in name, description, category, and select at least one image.',
        color.primaryColorDark,
      );
      return;
    }

    Api().showLoading(context);
    List<String> imageUrls = [];

    try {
      for (var file in imageFiles) {
        final fileName =
            "$_selectedType/${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = FirebaseStorage.instance.ref(fileName);

        if (_isWeb) {
          final bytes = await file.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(io.File(file.path));
        }

        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // --- 3. NEW: Save 'type' field to Firestore ---
      await FirebaseFirestore.instance.collection('products').add({
        'name': nameController.text.trim(),
        'description': descController.text.trim(),
        'imageUrl': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'category': _selectedCategory,
        'type': _selectedType, // 'Product' or 'Service'
        'isAvailable': true,
      });

      if (!context.mounted) return;
      Navigator.pop(context); // Dismiss loading

      Api().showMessage(
        context,
        '${nameController.text} added successfully!',
        'Success',
        color.splashColor,
      );

      _clearForm();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Error uploading: ${e.toString()}',
        'Error',
        color.primaryColorDark,
      );
    }
  }

  void _clearForm() {
    nameController.clear();
    descController.clear();
    setState(() {
      imageFiles = [];
      _selectedCategory = '';
      // Keep selected type same for convenience
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    // Determine which list to show based on type
    final currentCategories = _selectedType == 'Product'
        ? _productCategories
        : _serviceCategories;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Listing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.primaryColor,
                ),
              ),
              SizedBox(height: 20),

              // --- 4. NEW: Type Selector Toggle ---
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTypeOption('Product', Icons.shopping_bag),
                    _buildTypeOption('Service', Icons.handyman),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // --- Image Picker ---
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GestureDetector(
                  onTap: () => pickImages(),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            imageFiles.isNotEmpty
                                ? Icons.check_circle
                                : Icons.add_photo_alternate,
                            size: 45,
                            color: imageFiles.isNotEmpty
                                ? Colors.green
                                : color.primaryColor,
                          ),
                          SizedBox(height: 8),
                          Text(
                            imageFiles.isNotEmpty
                                ? '${imageFiles.length} Images Selected'
                                : 'Tap to upload ${_selectedType.toLowerCase()} images',
                            style: TextStyle(
                              color: color.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Image Preview
              if (imageFiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageFiles.length,
                      itemBuilder: (context, index) {
                        final file = imageFiles[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _isWeb
                                ? Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[300],
                                    child: Icon(Icons.image),
                                  )
                                : Image.file(
                                    io.File(file.path),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              SizedBox(height: 15),

              // --- Form Fields ---
              AuthTextField(
                onValidate: TextFieldValidation.name,
                placeholder: _selectedType == 'Product'
                    ? 'Product Name (e.g. Navy Suit)'
                    : 'Service Name (e.g. 50-Seater Bus)',
                controller: nameController,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value:
                      _selectedCategory.isNotEmpty &&
                          currentCategories.contains(_selectedCategory)
                      ? _selectedCategory
                      : null,
                  items: currentCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? '';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  dropdownColor: Colors.white,
                ),
              ),

              AuthTextField(
                onValidate: TextFieldValidation.name,
                placeholder: _selectedType == 'Product'
                    ? 'Description (Material, Size, etc.)'
                    : 'Description (Capacity, Terms, Features)',
                controller: descController,
              ),

              SizedBox(height: 25),

              // --- Upload Button ---
              CustomOutlinedButton(
                onPressed: uploadItem,
                text: "Add $_selectedType",
                backgroundColor: color.primaryColor,
                foregroundColor: Colors.white,
                width: double.infinity,
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for the toggle button
  Widget _buildTypeOption(String type, IconData icon) {
    final isSelected = _selectedType == type;
    final color = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedCategory = ''; // Reset category on switch
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black12, blurRadius: 4)]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? color.primaryColor : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                type,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color.primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
