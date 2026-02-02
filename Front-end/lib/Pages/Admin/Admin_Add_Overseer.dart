// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print, unnecessary_null_comparison

import 'dart:convert';
import 'package:http/http.dart' as http; // Standard HTTP package
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

//

bool get _useCupertinoStyle =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

const double _desktopContentMaxWidth = 1000.0;

class AdminAddOverseer extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const AdminAddOverseer({
    super.key,
    this.uid,
    this.portfolio,
    this.fullName,
    this.province,
  });

  @override
  State<AdminAddOverseer> createState() => _AdminAddOverseerState();
}

class _AdminAddOverseerState extends State<AdminAddOverseer> {
  // Controllers
  final TextEditingController overseerCodeController = TextEditingController();
  final TextEditingController overseerRegionController =
      TextEditingController();
  final TextEditingController overseerInitialsAndSurname =
      TextEditingController();
  final TextEditingController overseerDistrictElderController =
      TextEditingController();
  final TextEditingController overseerCommunityNameController =
      TextEditingController();
  final TextEditingController secretaryNameController = TextEditingController();
  final TextEditingController chairpersonNameController =
      TextEditingController();

  // Images
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
  Map<String, List<Map<String, String>>> districtCommunities = {};

  @override
  void dispose() {
    overseerInitialsAndSurname.dispose();
    overseerDistrictElderController.dispose();
    overseerCommunityNameController.dispose();
    secretaryNameController.dispose();
    chairpersonNameController.dispose();
    overseerCodeController.dispose();
    overseerRegionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String role) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
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
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  // --- MAIN SUBMIT FUNCTION ---
  Future<void> addOverseer() async {
    Api().showLoading(context);

    // 1. Basic Validation
    if (overseerInitialsAndSurname.text.isEmpty ||
        selectedProvince == null ||
        districtCommunities.isEmpty) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Please fill in all fields.',
        'Error',
        Colors.red,
      );
      return;
    }

    try {
      // 2. Prepare District Data
      List<Map<String, dynamic>> formattedDistricts = [];
      districtCommunities.forEach((elderName, communities) {
        List<Map<String, dynamic>> comms = [];
        for (var c in communities) {
          comms.add({
            'community_name': c['communityName'],
            'district_elder_name': elderName,
          });
        }
        formattedDistricts.add({
          'district_elder_name': elderName,
          'communities': comms,
        });
      });

      String initials_and_surname = overseerInitialsAndSurname.text;
      String code = overseerCodeController.text;
      String overseerEmail =
          '${initials_and_surname.replaceAll(" ", "").toLowerCase().trim()}$code@gmail.com';

      // 3. Register in Firebase Auth (Optional: If moving to full Django, this might not be needed)
      // Keeping it here as per your request to maintain existing flow
      try {
        FirebaseAuth auth = FirebaseAuth.instance;
        await auth.createUserWithEmailAndPassword(
          email: overseerEmail,
          password: "password123", // Default password
        );
      } catch (e) {
        print("Auth Note: User might already exist in Firebase.  $e");
        Api().showMessage(
          context,
          "Auth Note: User might already exist in Firebase.  $e",
          "Error",
          Theme.of(context).primaryColorDark,
        );
      }

      // 4. Send Multipart Request to Django
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/overseers/');
      var request = http.MultipartRequest('POST', url);

      // Add Headers
      request.headers['Authorization'] = 'Bearer ${widget.uid}';

      // Add Text Fields (Matching Django Model Fields)
      request.fields['overseer_initials_surname'] =
          overseerInitialsAndSurname.text;
      request.fields['email'] = overseerEmail;
      request.fields['province'] = selectedProvince!;
      request.fields['region'] = overseerRegionController.text;
      request.fields['code'] = code;

      // These fields will trigger the Committee Member auto-creation in Backend
      request.fields['secretary_name'] = secretaryNameController.text;
      request.fields['chairperson_name'] = chairpersonNameController.text;

      // Add JSON Data
      request.fields['districts'] = jsonEncode(formattedDistricts);

      // Add Files
      if (secretaryImageFile != null) {
        final bytes = await secretaryImageFile!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'secretary_face_image',
            bytes,
            filename: 'sec.jpg',
          ),
        );
      }

      if (chairpersonImageFile != null) {
        final bytes = await chairpersonImageFile!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'chairperson_face_image',
            bytes,
            filename: 'chair.jpg',
          ),
        );
      }

      // 5. Send & Handle Response
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); // Close Loading

      if (response.statusCode == 201 || response.statusCode == 200) {
        Api().showMessage(
          context,
          'Overseer Added & Committee Created!',
          'Success',
          Colors.green,
        );
        _resetForm();
      } else {
        print("Server Error: ${response.body}");
        Api().showMessage(
          context,
          'Server Error: ${response.statusCode}',
          'Error',
          Colors.red,
        );
      }
    } catch (error) {
      Navigator.pop(context);
      Api().showMessage(context, 'Failed: $error', 'Error', Colors.red);
    }
  }

  void _resetForm() {
    overseerInitialsAndSurname.clear();
    overseerDistrictElderController.clear();
    overseerCommunityNameController.clear();
    secretaryNameController.clear();
    chairpersonNameController.clear();
    overseerCodeController.clear();
    overseerRegionController.clear();
    setState(() {
      selectedProvince = null;
      districtCommunities.clear();
      secretaryImageFile = null;
      chairpersonImageFile = null;
    });
  }

  // --- UI COMPONENTS ---
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

  Widget _buildSubmitButton() {
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

  Widget platformTextField({
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    Widget? suffix,
    EdgeInsets padding = const EdgeInsets.all(16.0),
  }) {
    final ThemeData color = Theme.of(context);
    if (_useCupertinoStyle) {
      return NeumorphicContainer(
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: color.primaryColor.withOpacity(0.5)),
          ),
          padding: padding,
          suffix: suffix,
        ),
      );
    } else {
      return NeumorphicContainer(
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: placeholder,
            labelStyle: TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
            suffixIcon: suffix,
          ),
        ),
      );
    }
  }

  Widget _buildDistrictCard(
    String districtElderName,
    List<Map<String, String>> communitiesInThisDistrict,
    ThemeData color,
  ) {
    return NeumorphicContainer(
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
                _buildPlatformButton(
                  text: secretaryImageFile == null
                      ? "Select Secretary Face"
                      : "Image Selected",
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
                _buildPlatformButton(
                  text: chairpersonImageFile == null
                      ? "Select Chairperson Face"
                      : "Image Selected",
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
        NeumorphicContainer(
          child: Card( 
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

  @override
  Widget build(BuildContext context) {
    final ThemeData color = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: SingleChildScrollView(
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
        ),
      ),
    );
  }
}
