// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io show File;

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class AdminAddProduct extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const AdminAddProduct({super.key, this.uid, this.portfolio, this.fullName, this.province});

  @override
  State<AdminAddProduct> createState() => _AdminAddProductState();
}

class _AdminAddProductState extends State<AdminAddProduct> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  List<XFile> imageFiles = [];

  final ImagePicker _picker = ImagePicker();
  final bool _isWeb = kIsWeb;

  // --- 1. State to track Item Type ---
  String _selectedType = 'Product'; // Default to Product
  String _selectedCategory = '';

  // --- 2. Separate Category Lists ---
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
        Colors.red,
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

      // --- 3. Save 'type' field to Firestore ---
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
        Colors.green,
      );

      _clearForm();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Error uploading: ${e.toString()}',
        'Error',
        Colors.red,
      );
    }
  }

  void _clearForm() {
    nameController.clear();
    descController.clear();
    setState(() {
      imageFiles = [];
      _selectedCategory = '';
    });
  }

  // --- NEUMORPHIC TEXT FIELD HELPER ---
  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String placeholder,
    required Color baseColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: NeumorphicContainer(
        isPressed: true, // Inset (Sunken) Look
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: baseColor,
        child: TextField(
          controller: controller,
          style: TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: theme.hintColor),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color baseColor = Color.alphaBlend(
      theme.scaffoldBackgroundColor,
      theme.primaryColor,
    );
    final primaryColor = theme.primaryColor;

    // Determine which list to show based on type
    final currentCategories = _selectedType == 'Product'
        ? _productCategories
        : _serviceCategories;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Listing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 20),

              // --- 4. Type Selector (Neumorphic Toggle) ---
              NeumorphicContainer(
                isPressed: true, // Track is sunken
                borderRadius: 12,
                padding: EdgeInsets.all(4),
                color: baseColor,
                child: Row(
                  children: [
                    _buildTypeOption('Product', Icons.shopping_bag),
                    _buildTypeOption('Service', Icons.handyman),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // --- Image Picker (Neumorphic Inset Drop Zone) ---
              GestureDetector(
                onTap: () => pickImages(),
                child: NeumorphicContainer(
                  isPressed: true, // Sunken zone
                  borderRadius: 16,
                  padding: EdgeInsets.zero,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(16),
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
                                : primaryColor,
                          ),
                          SizedBox(height: 8),
                          Text(
                            imageFiles.isNotEmpty
                                ? '${imageFiles.length} Images Selected'
                                : 'Tap to upload ${_selectedType.toLowerCase()} images',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Image Preview (Horizontal List)
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
                          padding: const EdgeInsets.only(right: 12),
                          child: NeumorphicContainer(
                            borderRadius: 12,
                            padding: EdgeInsets.all(2), // Slight border effect
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _isWeb
                                  ? Container(
                                      width: 76,
                                      height: 76,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.image),
                                    )
                                  : Image.file(
                                      io.File(file.path),
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              SizedBox(height: 15),

              // --- Form Fields ---
              _buildNeumorphicTextField(
                baseColor: baseColor,
                controller: nameController,
                placeholder: _selectedType == 'Product'
                    ? 'Product Name (e.g. Navy Suit)'
                    : 'Service Name (e.g. 50-Seater Bus)',
              ),

              // --- Category Dropdown (Neumorphic Popped) ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: NeumorphicContainer(
                  isPressed: false, // Popped
                  borderRadius: 12,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  color: baseColor,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value:
                          _selectedCategory.isNotEmpty &&
                              currentCategories.contains(_selectedCategory)
                          ? _selectedCategory
                          : null,
                      hint: Text(
                        "Select Category",
                        style: TextStyle(color: theme.hintColor),
                      ),
                      isExpanded: true,
                      dropdownColor: baseColor,
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
                    ),
                  ),
                ),
              ),

              _buildNeumorphicTextField(
                baseColor: baseColor,
                controller: descController,
                placeholder: _selectedType == 'Product'
                    ? 'Description (Material, Size, etc.)'
                    : 'Description (Capacity, Terms, Features)',
              ),

              SizedBox(height: 30),

              // --- Upload Button (Neumorphic Popped) ---
              GestureDetector(
                onTap: uploadItem,
                child: NeumorphicContainer(
                  isPressed: false,
                  borderRadius: 12,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  color: baseColor,
                  child: Center(
                    child: Text(
                      "Add $_selectedType",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
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
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final baseColor = Color.alphaBlend(
      theme.scaffoldBackgroundColor,
      theme.primaryColor,
    );

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedCategory = ''; // Reset category on switch
          });
        },
        child: NeumorphicContainer(
          // If selected -> Popped (Active look). If not -> Transparent/Flat inside the track
          isPressed: !isSelected,
          borderRadius: 10,
          padding: EdgeInsets.symmetric(vertical: 12),
          // Add color to selected state to make it stand out
          color: isSelected ? baseColor : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : Colors.grey,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                type,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? primaryColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
