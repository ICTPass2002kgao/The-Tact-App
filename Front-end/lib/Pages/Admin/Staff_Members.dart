// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';

// ⭐️ IMPORT YOUR DESIGN COMPONENT
import '../../Components/NeuDesign.dart';

class StaffMembers extends StatefulWidget {
  final String? faceUrl;
  final String? name;
  final String? portfolio;
  final String? province;
  const StaffMembers({
    super.key,
    this.faceUrl,
    this.name,
    this.portfolio,
    this.province,
  });

  @override
  State<StaffMembers> createState() => _StaffMembersState();
}

class _StaffMembersState extends State<StaffMembers> {
  // --- CONTROLLERS ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController otherPortfolioController =
      TextEditingController();

  // --- STATE ---
  XFile? _faceImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final bool _isWeb = kIsWeb;

  // --- SELECTION VARIABLES ---
  String? _selectedPortfolio;
  String? _selectedProvince;

  // --- DATA LISTS ---
  final List<String> _provinces = [
    "Eastern Cape",
    "Free State",
    "Gauteng",
    "KwaZulu-Natal",
    "Limpopo",
    "Mpumalanga",
    "Northern Cape",
    "North West",
    "Western Cape",
  ];

  final List<String> _portfolios = [
    "Media Officer",
    "HOD Of Education",
    "UpperHouse Chairperson",
    "Apostle Board",
    "Other",
  ];

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    otherPortfolioController.dispose();
    super.dispose();
  }

  // --- LOGIC: IMAGE PICKER ---
  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _faceImageFile = picked;
        });
      }
    } catch (e) {
      print("Image Picker Error: $e");
    }
  }

  // --- LOGIC: UPLOAD & ADD ---
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

  Future<void> _addStaffMember() async {
    String finalPortfolio = "";

    if (_selectedPortfolio == "Other") {
      finalPortfolio = otherPortfolioController.text.trim();
    } else {
      finalPortfolio = _selectedPortfolio ?? "";
    }

    if (nameController.text.isEmpty ||
        surnameController.text.isEmpty ||
        _selectedPortfolio == null ||
        _selectedProvince == null ||
        finalPortfolio.isEmpty) {
      Api().showMessage(
        context,
        'Missing Info',
        'Please fill all fields.',
        Colors.orange,
      );
      return;
    }

    if (_faceImageFile == null) {
      Api().showMessage(
        context,
        'Face Required',
        'Upload face for biometric login.',
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String fileName =
          "${nameController.text}_${DateTime.now().millisecondsSinceEpoch}";
      String imageUrl = await _uploadFile(
        _faceImageFile!,
        "Staff_Faces/$fileName",
      );

      await FirebaseFirestore.instance.collection('staff_members').add({
        'name': nameController.text.trim(),
        'surname': surnameController.text.trim(),
        'fullName': "${nameController.text} ${surnameController.text}",
        'portfolio': finalPortfolio,
        'province': _selectedProvince,
        'faceUrl': imageUrl,
        'email': 'admin@dankie.co.za',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'role': "Admin",
      });

      if (mounted) {
        Api().showMessage(
          context,
          'Success',
          'Staff Member Added Successfully',
          Colors.green,
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        Api().showMessage(context, 'Error', e.toString(), Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    nameController.clear();
    surnameController.clear();
    otherPortfolioController.clear();
    setState(() {
      _selectedPortfolio = null;
      _selectedProvince = null;
      _faceImageFile = null;
    });
  }

  Future<void> _deleteStaff(String docId) async {
    try {
      Api().isIOSPlatform
          ? Api().showIosLoading(context)
          : Api().showLoading(context);
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_members')
          .get();
      if (snapshot.docs.length <= 1) {
        Api().showMessage(
          context,
          "Action Denied",
          "At least one staff member must remain.",
          Colors.orange,
        );
        Navigator.of(context).pop();
        return;
      }
      await FirebaseFirestore.instance
          .collection('staff_members')
          .doc(docId)
          .delete();
      Api().showMessage(
        context,
        "Deleted",
        "Staff member removed.",
        Colors.grey,
      );
      Navigator.of(context).pop();
    } catch (e) {
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  // --- ⭐️ NEUMORPHIC WIDGET HELPERS ---

  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color baseColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        NeumorphicContainer(
          isPressed: true, // ⭐️ Inset look for inputs
          color: baseColor,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter $label",
              prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeumorphicDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    required Color baseColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        NeumorphicContainer(
          isPressed: true, // ⭐️ Inset look for dropdowns
          color: baseColor,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(icon, color: Theme.of(context).primaryColor, size: 24),
                  SizedBox(width: 12),
                  Text("Select $label"),
                ],
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).primaryColor,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      // Little spacing to align with input text if needed
                      if (value != null) ...[
                        Icon(
                          icon,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                      ],
                      Text(item),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              dropdownColor: baseColor, // Match bg
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerBox(Color baseColor) {
    return GestureDetector(
      onTap: _pickImage,
      child: NeumorphicContainer(
        color: baseColor,
        borderRadius: 15,
        padding: EdgeInsets.all(4), // small padding for "border" effect
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _faceImageFile == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      color: Theme.of(context).primaryColor,
                      size: 30,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Add Photo",
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isWeb
                      ? Image.network(_faceImageFile!.path, fit: BoxFit.cover)
                      : Image.file(
                          io.File(_faceImageFile!.path),
                          fit: BoxFit.cover,
                        ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ⭐️ Calculate Base Color
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 800;
          final double gridCardWidth = isMobile ? double.infinity : 350;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    Text(
                      "Add New Staff Member",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 20),

                    // --- INPUT FORM (Neumorphic Card) ---
                    NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 20,
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (isMobile) ...[
                            // MOBILE LAYOUT
                            Center(child: _buildImagePickerBox(neumoBaseColor)),
                            SizedBox(height: 20),
                            _buildNeumorphicTextField(
                              controller: nameController,
                              label: "Name",
                              icon: Icons.person,
                              baseColor: neumoBaseColor,
                            ),
                            SizedBox(height: 15),
                            _buildNeumorphicTextField(
                              controller: surnameController,
                              label: "Surname",
                              icon: Icons.person_outline,
                              baseColor: neumoBaseColor,
                            ),
                            SizedBox(height: 15),
                            _buildNeumorphicDropdown(
                              value: _selectedPortfolio,
                              label: "Portfolio",
                              icon: Icons.work,
                              items: _portfolios,
                              onChanged: (val) =>
                                  setState(() => _selectedPortfolio = val),
                              baseColor: neumoBaseColor,
                            ),
                            if (_selectedPortfolio == "Other") ...[
                              SizedBox(height: 15),
                              _buildNeumorphicTextField(
                                controller: otherPortfolioController,
                                label: "Specify Portfolio Name",
                                icon: Icons.edit_note,
                                baseColor: neumoBaseColor,
                              ),
                            ],
                            SizedBox(height: 15),
                            _buildNeumorphicDropdown(
                              value: _selectedProvince,
                              label: "Province",
                              icon: Icons.location_on,
                              items: _provinces,
                              onChanged: (val) =>
                                  setState(() => _selectedProvince = val),
                              baseColor: neumoBaseColor,
                            ),
                          ] else ...[
                            // DESKTOP LAYOUT
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildImagePickerBox(neumoBaseColor),
                                SizedBox(width: 30),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildNeumorphicTextField(
                                              controller: nameController,
                                              label: "Name",
                                              icon: Icons.person,
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                          SizedBox(width: 20),
                                          Expanded(
                                            child: _buildNeumorphicTextField(
                                              controller: surnameController,
                                              label: "Surname",
                                              icon: Icons.person_outline,
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildNeumorphicDropdown(
                                              value: _selectedPortfolio,
                                              label: "Portfolio",
                                              icon: Icons.work,
                                              items: _portfolios,
                                              onChanged: (val) => setState(
                                                () => _selectedPortfolio = val,
                                              ),
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                          SizedBox(width: 20),
                                          Expanded(
                                            child: _buildNeumorphicDropdown(
                                              value: _selectedProvince,
                                              label: "Province",
                                              icon: Icons.location_on,
                                              items: _provinces,
                                              onChanged: (val) => setState(
                                                () => _selectedProvince = val,
                                              ),
                                              baseColor: neumoBaseColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_selectedPortfolio == "Other") ...[
                                        SizedBox(height: 20),
                                        _buildNeumorphicTextField(
                                          controller: otherPortfolioController,
                                          label: "Specify Portfolio Name",
                                          icon: Icons.edit_note,
                                          baseColor: neumoBaseColor,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 30),

                          // ⭐️ Neumorphic Button
                          GestureDetector(
                            onTap: _isLoading ? null : _addStaffMember,
                            child: NeumorphicContainer(
                              color: theme.primaryColor,
                              borderRadius: 12,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "Save Staff Member",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),

                    // --- STAFF LIST HEADER ---
                    Text(
                      "Existing Staff Members",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 15),

                    // --- GRID ---
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('staff_members')
                          .orderBy('createdAt', descending: true)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "Error loading staff",
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CupertinoActivityIndicator());
                        }

                        final data = snapshot.data!.docs;

                        if (data.isEmpty) {
                          return Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 40,
                                  color: theme.hintColor.withOpacity(0.5),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "No staff members found.",
                                  style: TextStyle(color: theme.hintColor),
                                ),
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: gridCardWidth,
                                mainAxisExtent:
                                    120, // Slightly taller for padding
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                              ),
                          itemCount: data.length,
                          itemBuilder: (context, index) {
                            final staff =
                                data[index].data() as Map<String, dynamic>;
                            final docId = data[index].id;

                            // ⭐️ Neumorphic List Item
                            return NeumorphicContainer(
                              color: neumoBaseColor,
                              borderRadius: 15,
                              padding: EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.black12,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: staff['faceUrl'] != null
                                          ? Image.network(
                                              staff['faceUrl'],
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(
                                              Icons.person,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${staff['name']} ${staff['surname']}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.primaryColor,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          staff['portfolio'] ?? 'No Portfolio',
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          staff['province'] ?? 'Unknown',
                                          style: TextStyle(
                                            color: theme.hintColor,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _deleteStaff(docId),
                                    child: NeumorphicContainer(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: 50,
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
