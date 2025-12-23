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
  // NEW: Controller for manual portfolio entry
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
    "Other", // ADDED "Other" option here
  ];

  // --- STYLE GETTERS ---
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _primaryColor => const Color(0xFF1E3A8A);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1F2937) : Colors.white;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor =>
      _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
  Color get _inputFillColor =>
      _isDarkMode ? const Color(0xFF374151) : Colors.grey.shade50;
  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF4B5563) : Colors.grey.shade300;

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    otherPortfolioController.dispose(); // Dispose new controller
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
    // 1. Determine the actual portfolio string
    String finalPortfolio = "";

    if (_selectedPortfolio == "Other") {
      finalPortfolio = otherPortfolioController.text.trim();
    } else {
      finalPortfolio = _selectedPortfolio ?? "";
    }

    // 2. Updated Validation
    if (nameController.text.isEmpty ||
        surnameController.text.isEmpty ||
        _selectedPortfolio == null ||
        _selectedProvince == null ||
        finalPortfolio.isEmpty) {
      // Ensure final portfolio isn't empty
      Api().showMessage(
        context,
        'Missing Info',
        'Please fill all fields. If "Other" is selected, specify the portfolio.',
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
        'portfolio': finalPortfolio, // Save the resolved string
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
    otherPortfolioController.clear(); // Clear custom field
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

  // --- UI COMPONENTS ---
  Widget _styledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: _textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _subTextColor),
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
      ),
    );
  }

  Widget _styledDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: TextStyle(color: _textColor)),
        );
      }).toList(),
      onChanged: onChanged,
      dropdownColor: _cardColor,
      style: TextStyle(color: _textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _subTextColor),
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
      ),
    );
  }

  Widget _buildImagePickerBox() {
    return InkWell(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(12),
          color: _inputFillColor,
        ),
        child: _faceImageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: _subTextColor),
                  SizedBox(height: 4),
                  Text(
                    "Photo",
                    style: TextStyle(color: _subTextColor, fontSize: 10),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _isWeb
                    ? Image.network(_faceImageFile!.path, fit: BoxFit.cover)
                    : Image.file(
                        io.File(_faceImageFile!.path),
                        fit: BoxFit.cover,
                      ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoint for responsiveness
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
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  SizedBox(height: 20),

                  // --- INPUT CARD ---
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (isMobile) ...[
                          // MOBILE LAYOUT (Stacked)
                          Center(child: _buildImagePickerBox()),
                          SizedBox(height: 20),
                          _styledTextField(
                            controller: nameController,
                            label: "Name",
                            icon: Icons.person,
                          ),
                          SizedBox(height: 10),
                          _styledTextField(
                            controller: surnameController,
                            label: "Surname",
                            icon: Icons.person_outline,
                          ),
                          SizedBox(height: 10),
                          _styledDropdown(
                            value: _selectedPortfolio,
                            label: "Portfolio",
                            icon: Icons.work,
                            items: _portfolios,
                            onChanged: (val) =>
                                setState(() => _selectedPortfolio = val),
                          ),
                          // LOGIC: IF 'OTHER' SELECTED, SHOW TEXT FIELD
                          if (_selectedPortfolio == "Other") ...[
                            SizedBox(height: 10),
                            _styledTextField(
                              controller: otherPortfolioController,
                              label: "Specify Portfolio Name",
                              icon: Icons.edit_note,
                            ),
                          ],
                          SizedBox(height: 10),
                          _styledDropdown(
                            value: _selectedProvince,
                            label: "Province",
                            icon: Icons.location_on,
                            items: _provinces,
                            onChanged: (val) =>
                                setState(() => _selectedProvince = val),
                          ),
                        ] else ...[
                          // DESKTOP/TABLET LAYOUT (Row)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildImagePickerBox(),
                              SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _styledTextField(
                                            controller: nameController,
                                            label: "Name",
                                            icon: Icons.person,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: _styledTextField(
                                            controller: surnameController,
                                            label: "Surname",
                                            icon: Icons.person_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _styledDropdown(
                                            value: _selectedPortfolio,
                                            label: "Portfolio",
                                            icon: Icons.work,
                                            items: _portfolios,
                                            onChanged: (val) => setState(
                                              () => _selectedPortfolio = val,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: _styledDropdown(
                                            value: _selectedProvince,
                                            label: "Province",
                                            icon: Icons.location_on,
                                            items: _provinces,
                                            onChanged: (val) => setState(
                                              () => _selectedProvince = val,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // LOGIC: DESKTOP 'OTHER' FIELD ROW
                                    if (_selectedPortfolio == "Other") ...[
                                      SizedBox(height: 10),
                                      _styledTextField(
                                        controller: otherPortfolioController,
                                        label: "Specify Portfolio Name",
                                        icon: Icons.edit_note,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: 20),

                        // SUBMIT BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _addStaffMember,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  SizedBox(height: 15),

                  // --- RESPONSIVE GRID VIEW ---
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
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
                                color: _subTextColor,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "No staff members found.",
                                style: TextStyle(color: _subTextColor),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: gridCardWidth, // Dynamic width
                          mainAxisExtent: 110, // Fixed height per card
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final staff =
                              data[index].data() as Map<String, dynamic>;
                          final docId = data[index].id;

                          return Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: staff['faceUrl'] != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              staff['faceUrl'],
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: Colors.grey.shade200,
                                  ),
                                  child: staff['faceUrl'] == null
                                      ? Icon(Icons.person, color: _subTextColor)
                                      : null,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "${staff['name']} ${staff['surname']}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _textColor,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.work,
                                            size: 12,
                                            color: _primaryColor,
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              staff['portfolio'] ??
                                                  'No Portfolio',
                                              style: TextStyle(
                                                color: _primaryColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 12,
                                            color: _subTextColor,
                                          ),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              staff['province'] ?? 'Unknown',
                                              style: TextStyle(
                                                color: _subTextColor,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteStaff(docId),
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
    );
  }
}
