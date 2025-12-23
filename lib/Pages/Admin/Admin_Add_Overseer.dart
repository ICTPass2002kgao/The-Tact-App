// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print, unnecessary_null_comparison

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';

// --- PLATFORM UTILITIES ---
bool get _useCupertinoStyle =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

const double _desktopContentMaxWidth = 1000.0;
// --------------------------

class AdminAddOverseer extends StatefulWidget {
  const AdminAddOverseer({super.key});

  @override
  State<AdminAddOverseer> createState() => _AdminAddOverseerState();
}

class _AdminAddOverseerState extends State<AdminAddOverseer> {
  // --- EXISTING CONTROLLERS ---
  final TextEditingController overseerEmailController = TextEditingController();
  final TextEditingController overseerCodeController = TextEditingController();
  final TextEditingController overseerRegionController =
      TextEditingController();
  final TextEditingController overseerInitialsAndSurname =
      TextEditingController();
  final TextEditingController overseerPasswordController =
      TextEditingController();
  final TextEditingController overseerDistrictElderController =
      TextEditingController();
  final TextEditingController overseerCommunityNameController =
      TextEditingController();

  // Note: Address controller was unused in UI but kept for safety if needed
  final TextEditingController overseerAddressController =
      TextEditingController();

  // --- NEW CONTROLLERS ---
  final TextEditingController secretaryNameController = TextEditingController();
  final TextEditingController chairpersonNameController =
      TextEditingController();

  // --- IMAGE FILES (HELD IN MEMORY) ---
  XFile? secretaryImageFile;
  XFile? chairpersonImageFile;

  List<String> provinces = [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];
  String? selectedProvince;
  bool isPasswordVisible = false;

  // Initialized empty to prevent null errors
  Map<String, List<Map<String, String>>> districtCommunities = {};

  @override
  void dispose() {
    overseerEmailController.dispose();
    overseerInitialsAndSurname.dispose();
    overseerPasswordController.dispose();
    overseerDistrictElderController.dispose();
    overseerCommunityNameController.dispose();
    overseerAddressController.dispose();
    secretaryNameController.dispose();
    chairpersonNameController.dispose();
    super.dispose();
  }

  // --- 1. PICK IMAGE (DOES NOT UPLOAD YET) ---
  Future<void> _pickImage(String role) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Optimize size
      );

      if (image != null) {
        setState(() {
          if (role == 'secretary') {
            secretaryImageFile = image;
          } else {
            chairpersonImageFile = image;
          }
        });
      }
    } catch (e) {
      Api().showMessage(
        context,
        "Error picking image: $e",
        "Error",
        Colors.red,
      );
    }
  }

  // --- 2. UPLOAD HELPER (CALLED DURING SUBMIT) ---
  Future<String?> _uploadFileToStorage(XFile file, String role) async {
    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_$role.jpg';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('overseer_faces')
          .child(fileName);

      TaskSnapshot snapshot;
      if (kIsWeb) {
        Uint8List bytes = await file.readAsBytes();
        snapshot = await ref.putData(bytes);
      } else {
        snapshot = await ref.putFile(File(file.path));
      }
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  // --- 3. MAIN SUBMIT FUNCTION ---
  Future<void> addOverseer() async {
    Api().showLoading(context);
    FirebaseAuth auth = FirebaseAuth.instance;

    // Validation
    if (overseerInitialsAndSurname.text.isEmpty ||
        overseerEmailController.text.isEmpty ||
        overseerPasswordController.text.isEmpty ||
        selectedProvince == null ||
        districtCommunities.isEmpty) {
      if (mounted) {
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Please fill in all fields (including at least one District).',
          'Error',
          Colors.red,
        );
      }
      return;
    }

    try {
      // A. Create User
      var userCredential = await auth.createUserWithEmailAndPassword(
        email: overseerEmailController.text.trim(),
        password: overseerPasswordController.text,
      );

      if (!mounted) return;

      // B. Upload Images (If selected)
      String? secUrl;
      String? chairUrl;

      if (secretaryImageFile != null) {
        secUrl = await _uploadFileToStorage(secretaryImageFile!, 'secretary');
      }
      if (chairpersonImageFile != null) {
        chairUrl = await _uploadFileToStorage(
          chairpersonImageFile!,
          'chairperson',
        );
      }

      // C. Save to Firestore
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      final List<Map<String, dynamic>> structuredDistricts = districtCommunities
          .entries
          .map(
            (entry) => {
              'districtElderName': entry.key,
              'communities': entry.value,
            },
          )
          .toList();

      await firestore.collection('overseers').add({
        'overseerInitialsAndSurname': overseerInitialsAndSurname.text,
        'email': overseerEmailController.text,
        'province': selectedProvince,
        'uid': userCredential.user?.uid,
        'role': 'overseer',
        'subscriptionStatus': 'inactive',
        'paystackAuthCode': null,
        'paystackEmail': null,
        'code': overseerCodeController.text,
        'region': overseerRegionController.text,

        // Biometrics
        'secretaryName': secretaryNameController.text.trim(),
        'chairpersonName': chairpersonNameController.text.trim(),
        'secretaryFaceUrl': secUrl,
        'chairpersonFaceUrl': chairUrl,
        'secretaryFaceUploaded': secUrl != null,
        'chairpersonFaceUploaded': chairUrl != null,

        'districts': structuredDistricts,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        Api().showMessage(
          context,
          'Overseer added successfully',
          'Success',
          Colors.green,
        );
        _resetForm();
      }
    } catch (error) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        Api().showMessage(
          context,
          'Failed: ${error.toString().split('] ').last}',
          'Error',
          Colors.red,
        );
      }
    }
  }

  void _resetForm() {
    overseerInitialsAndSurname.clear();
    overseerEmailController.clear();
    overseerPasswordController.clear();
    overseerDistrictElderController.clear();
    overseerCommunityNameController.clear();
    secretaryNameController.clear();
    chairpersonNameController.clear();
    setState(() {
      selectedProvince = null;
      isPasswordVisible = false;
      districtCommunities.clear();
      secretaryImageFile = null;
      chairpersonImageFile = null;
    });
  }

  // --- WIDGET HELPER: PLATFORM BUTTON ---
  Widget _buildPlatformButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    bool isSuccess = false,
  }) {
    Color btnColor = isSuccess ? Colors.green : Theme.of(context).primaryColor;

    if (_useCupertinoStyle) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          color: btnColor,
          padding: EdgeInsets.symmetric(vertical: 12),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSuccess ? CupertinoIcons.check_mark_circled : icon,
                color: CupertinoColors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            isSuccess ? Icons.check_circle : icon,
            color: isSuccess ? Colors.green : null,
          ),
          label: Text(
            text,
            style: TextStyle(color: isSuccess ? Colors.green : null),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: btnColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }
  }

  // --- WIDGET HELPER: STANDARD SUBMIT BUTTON ---
  Widget _buildSubmitButton() {
    if (_useCupertinoStyle) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: addOverseer,
          child: Text("Add Overseer & Upload Data"),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: addOverseer,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            "Add Overseer & Upload Data",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Widget platformTextField({
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    Widget? suffix,
    EdgeInsets padding = const EdgeInsets.all(16.0),
  }) {
    final ThemeData color = Theme.of(context);
    if (_useCupertinoStyle) {
      return CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscureText,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: color.primaryColor.withOpacity(0.5)),
        ),
        padding: padding,
        suffix: suffix,
      );
    } else {
      return TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: placeholder,
          labelStyle: TextStyle(fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          suffixIcon: suffix,
        ),
      );
    }
  }

  // --- DISTRICT CARD UI ---
  Widget _buildDistrictCard(
    String districtElderName,
    List<Map<String, String>> communitiesInThisDistrict,
    ThemeData color,
  ) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'District: $districtElderName',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color.primaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () => setState(
                    () => districtCommunities.remove(districtElderName),
                  ),
                ),
              ],
            ),
            Divider(color: color.dividerColor),
            // Safe list access
            if (communitiesInThisDistrict.isNotEmpty)
              ...communitiesInThisDistrict.map(
                (map) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('• ${map['communityName']}')),
                      InkWell(
                        child: Icon(Icons.close, size: 16, color: Colors.grey),
                        onTap: () => setState(
                          () => districtCommunities[districtElderName]?.remove(
                            map,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                'No communities yet.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),

            SizedBox(height: 15),
            Text(
              'Add Community:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 5),
            // Using a Row here to layout the input and button nicely
            Row(
              children: [
                Expanded(
                  child: platformTextField(
                    controller: overseerCommunityNameController,
                    placeholder: 'Community Name',
                    padding: EdgeInsets.all(12),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: color.primaryColor,
                    size: 30,
                  ),
                  onPressed: () {
                    String name = overseerCommunityNameController.text.trim();
                    if (name.isNotEmpty) {
                      setState(() {
                        // Safe Map Access
                        if (districtCommunities.containsKey(
                          districtElderName,
                        )) {
                          districtCommunities[districtElderName]?.add({
                            'communityName': name,
                          });
                          overseerCommunityNameController.clear();
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData color = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 600;

    Widget mainContent = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Add New Overseer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: _buildOverseerForm(color),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: _buildDistrictList(color),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildOverseerForm(color),
                    SizedBox(height: 30),
                    _buildDistrictList(color),
                  ],
                ),
          const SizedBox(height: 30),
          _buildSubmitButton(),
          SizedBox(height: 40),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: SingleChildScrollView(child: mainContent),
      ),
    );
  }

  Widget _buildOverseerForm(ThemeData color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                platformTextField(
                  controller: overseerInitialsAndSurname,
                  placeholder: 'Initials and Surname',
                ),
                SizedBox(height: 10),
                platformTextField(
                  controller: overseerRegionController,
                  placeholder: 'Region',
                ),
                SizedBox(height: 10),
                platformTextField(
                  controller: overseerCodeController,
                  placeholder: 'Code',
                ),
                SizedBox(height: 10),
                platformTextField(
                  controller: overseerEmailController,
                  placeholder: 'Email Address',
                ),
                SizedBox(height: 10),
                platformTextField(
                  controller: overseerPasswordController,
                  placeholder: 'Password',
                  obscureText: !isPasswordVisible,
                  suffix: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: color.primaryColor,
                    ),
                    onPressed: () =>
                        setState(() => isPasswordVisible = !isPasswordVisible),
                  ),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Province',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  value: selectedProvince,
                  items: provinces
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedProvince = val),
                ),
              ],
            ),
          ),
        ),

        // --- COMMITTEE SECTION ---
        Card(
          elevation: 4,
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2. Committee (Biometric)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.primaryColor,
                  ),
                ),
                SizedBox(height: 15),
                Text("Secretary Name"),
                SizedBox(height: 5),
                platformTextField(
                  controller: secretaryNameController,
                  placeholder: 'Full Name',
                ),
                SizedBox(height: 10),
                // Secretary Button
                _buildPlatformButton(
                  text: secretaryImageFile == null
                      ? "Select Secretary Face"
                      : "Image Selected (Waiting to Upload)",
                  icon: secretaryImageFile == null
                      ? (_useCupertinoStyle
                            ? CupertinoIcons.photo_camera
                            : Icons.camera_alt)
                      : Icons.check,
                  isSuccess: secretaryImageFile != null,
                  onPressed: () => _pickImage('secretary'),
                ),

                SizedBox(height: 20),
                Text("Chairperson Name"),
                SizedBox(height: 5),
                platformTextField(
                  controller: chairpersonNameController,
                  placeholder: 'Full Name',
                ),
                SizedBox(height: 10),
                // Chairperson Button
                _buildPlatformButton(
                  text: chairpersonImageFile == null
                      ? "Select Chairperson Face"
                      : "Image Selected (Waiting to Upload)",
                  icon: chairpersonImageFile == null
                      ? (_useCupertinoStyle
                            ? CupertinoIcons.photo_camera
                            : Icons.camera_alt)
                      : Icons.check,
                  isSuccess: chairpersonImageFile != null,
                  onPressed: () => _pickImage('chairperson'),
                ),
              ],
            ),
          ),
        ),

        // --- DISTRICT ADDER ---
        Card(
          elevation: 4,
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Add New District Elder',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: platformTextField(
                        controller: overseerDistrictElderController,
                        placeholder: 'Elder Name',
                        padding: EdgeInsets.all(12),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Standard Button here to avoid null error risk
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        size: 35,
                        color: color.primaryColor,
                      ),
                      onPressed: () {
                        String name = overseerDistrictElderController.text
                            .trim();
                        if (name.isNotEmpty &&
                            !districtCommunities.containsKey(name)) {
                          setState(() {
                            districtCommunities[name] = [];
                            overseerDistrictElderController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictList(ThemeData color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Structure Preview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color.primaryColor,
          ),
        ),
        SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: districtCommunities.keys.length,
          itemBuilder: (ctx, i) {
            String key = districtCommunities.keys.elementAt(i);
            // FIXED: Use ?? [] to prevent null crash
            return _buildDistrictCard(
              key,
              districtCommunities[key] ?? [],
              color,
            );
          },
        ),
      ],
    );
  }
}
