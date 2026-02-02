// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_typing_uninitialized_variables, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http; // Added for Django
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Kept for UID
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/API.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class MyProfile extends StatefulWidget {
  const MyProfile({super.key});

  @override
  State<MyProfile> createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();

  XFile? _pickedFile;
  String? _currentProfileImageUrl;

  String? _selectedProvince;
  String? _selectedRole;
  String? _selectedMemberUid; // This acts as Overseer ID/UID
  String? _selectedDistrictElder;
  String? _selectedCommunityName;

  // Cache data
  Map<String, dynamic>? _currentOverseerData;
  List<String> _districtElderNames = [];
  List<String> _communityNames = [];

  // Async State for Profile Refreshing
  Future<Map<String, dynamic>?>? _profileFuture;

  final _formKey = GlobalKey<FormState>();

  final List<String> provinces = [
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
  final List<String> roles = ['Seller', "Member", "External Member"];

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  // --- 1. FETCH USER PROFILE (DJANGO) ---
  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // URL: /api/users/UID/ (Assuming UID is the primary lookup key or ID)
      // If your Django ID is different from Firebase UID, use ?uid= filter instead
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/${user.uid}/',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Fallback: try filtering if direct ID fails
        final filterUrl = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/users/?uid=${user.uid}',
        );
        final filterResp = await http.get(filterUrl);
        if (filterResp.statusCode == 200) {
          final List results = json.decode(filterResp.body);
          if (results.isNotEmpty) return results[0];
        }
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
    return null;
  }

  // --- 2. UPDATE PROFILE (DJANGO MULTIPART) ---
  Future<void> _updateUserData(Map<String, dynamic> dataToUpdate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isIOSPlatform ? Api().showIosLoading(context) : Api().showLoading(context);

    try {
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/${user.uid}/',
      );

      var request = http.MultipartRequest('PATCH', url);

      // Add Text Fields
      dataToUpdate.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });

      // Add Image if picked
      if (_pickedFile != null) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'profile_image', // Django field name
              await _pickedFile!.readAsBytes(),
              filename: _pickedFile!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_image',
              _pickedFile!.path,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() {
          _profileFuture = _fetchUserProfile(); // Refresh UI
        });
      } else {
        throw Exception(
          "Update failed: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- 3. FETCH OVERSEER DATA FOR DROPDOWNS (DJANGO) ---
  Future<void> _fetchOverseerData(
    String overseerUid,
    StateSetter setModalState,
  ) async {
    try {
      // Assume searching by UID or ID
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?uid=$overseerUid',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final data = results[0];
          setModalState(() {
            _currentOverseerData = data;

            // Django serializer usually returns 'districts' list
            final districts = data['districts'] as List<dynamic>? ?? [];
            _districtElderNames = districts
                .map(
                  (d) => (d['district_elder_name'] ?? d['districtElderName'])
                      .toString(),
                )
                .toList();

            // Auto-populate community if district is selected
            if (_selectedDistrictElder != null) {
              final selectedDistrict = districts.firstWhere(
                (d) =>
                    (d['district_elder_name'] ?? d['districtElderName']) ==
                    _selectedDistrictElder,
                orElse: () => null,
              );

              if (selectedDistrict != null) {
                final communities =
                    selectedDistrict['communities'] as List<dynamic>? ?? [];
                _communityNames = communities
                    .map(
                      (c) => (c['community_name'] ?? c['communityName'])
                          .toString(),
                    )
                    .toList();
              } else {
                _communityNames = [];
                _selectedCommunityName = null;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching overseer data: $e");
    }
  }

  // --- HELPER: Secure Image URL ---
  String _getSecureImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return "";
    // If it's a file path (picked image), return it as is (handled by Image provider logic)
    if (!originalUrl.startsWith('http')) return originalUrl;

    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  ImageProvider _getProfileImage() {
    if (_pickedFile != null) {
      if (kIsWeb) return NetworkImage(_pickedFile!.path);
      return FileImage(io.File(_pickedFile!.path));
    } else if (_currentProfileImageUrl != null &&
        _currentProfileImageUrl!.isNotEmpty) {
      return NetworkImage(_getSecureImageUrl(_currentProfileImageUrl));
    } else {
      return AssetImage('assets/no_profile.png');
    }
  }

  // --- NEUMORPHIC EDIT SHEET ---
  void _showEditProfileSheet(
    BuildContext context,
    Map<String, dynamic> currentData,
  ) {
    _nameController.text = currentData['name'] ?? '';
    _surnameController.text = currentData['surname'] ?? '';
    _addressController.text = currentData['address'] ?? '';
    _contactNumberController.text = currentData['phone'] ?? '';
    _currentProfileImageUrl =
        currentData['profile_image'] ??
        currentData['profileUrl']; // Django/Firebase key check
    _pickedFile = null;
    _selectedRole = currentData['role'];
    _selectedProvince = currentData['province'];
    _selectedMemberUid =
        currentData['overseer_uid'] ?? currentData['overseerUid'];
    _selectedDistrictElder =
        currentData['district_elder_name'] ?? currentData['districtElderName'];
    _selectedCommunityName =
        currentData['community_name'] ?? currentData['communityName'];

    _currentOverseerData = null;
    _districtElderNames = [];
    _communityNames = [];

    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: baseColor,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                // Auto-load overseer data if ID is present
                if (_selectedMemberUid != null &&
                    _currentOverseerData == null) {
                  _fetchOverseerData(_selectedMemberUid!, setModalState);
                }
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 30,
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: NeumorphicContainer(
                                  color: baseColor,
                                  borderRadius: 50,
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),

                          GestureDetector(
                            onTap: () async => await _pickImage(setModalState),
                            child: NeumorphicContainer(
                              color: baseColor,
                              isPressed: false,
                              padding: EdgeInsets.all(4),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: baseColor,
                                backgroundImage: _getProfileImage(),
                                child:
                                    (_pickedFile == null &&
                                        (_currentProfileImageUrl == null ||
                                            _currentProfileImageUrl!.isEmpty))
                                    ? Icon(
                                        Icons.camera_alt,
                                        size: 30,
                                        color: theme.primaryColor,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () async =>
                                await _pickImage(setModalState),
                            child: Text(
                              'Change Photo',
                              style: TextStyle(color: theme.primaryColor),
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildSectionHeader("Personal Details", theme),
                          _buildNeuEditField(
                            controller: _nameController,
                            hint: 'First Name',
                            icon: Icons.person,
                            baseColor: baseColor,
                          ),
                          _buildNeuEditField(
                            controller: _surnameController,
                            hint: 'Last Name',
                            icon: Icons.person_outline,
                            baseColor: baseColor,
                          ),
                          _buildNeuEditField(
                            controller: _contactNumberController,
                            hint: 'Phone',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            baseColor: baseColor,
                          ),
                          _buildNeuEditField(
                            controller: _addressController,
                            hint: 'Address',
                            icon: Icons.location_on,
                            maxLines: 2,
                            baseColor: baseColor,
                          ),

                          const SizedBox(height: 20),
                          _buildNeuDropdownRow(
                            title: 'Role',
                            value: _selectedRole,
                            onTap: () => _buildActionSheet(
                              context: context,
                              title: 'Select Role',
                              actions: roles,
                              onSelected: (val) =>
                                  setModalState(() => _selectedRole = val),
                            ),
                            baseColor: baseColor,
                          ),

                          _buildSectionHeader("Organization Details", theme),
                          _buildNeuDropdownRow(
                            title: 'Province',
                            value: _selectedProvince,
                            onTap: () => _buildActionSheet(
                              context: context,
                              title: 'Select Province',
                              actions: provinces,
                              onSelected: (val) {
                                setModalState(() {
                                  _selectedProvince = val;
                                  _selectedMemberUid = null;
                                  _currentOverseerData = null;
                                  _selectedDistrictElder = null;
                                  _selectedCommunityName = null;
                                  _districtElderNames = [];
                                  _communityNames = [];
                                });
                              },
                            ),
                            baseColor: baseColor,
                          ),

                          if (_selectedProvince != null)
                            _buildNeuDropdownRow(
                              title: 'Overseer',
                              value:
                                  _currentOverseerData?['overseer_initials_surname'] ??
                                  _currentOverseerData?['overseerInitialsAndSurname'] ??
                                  (_selectedMemberUid != null
                                      ? 'Loading...'
                                      : 'Select'),
                              baseColor: baseColor,
                              onTap: () async {
                                final url = Uri.parse(
                                  '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?province=$_selectedProvince',
                                );
                                final response = await http.get(url);
                                if (response.statusCode != 200) return;

                                final List overseers = json.decode(
                                  response.body,
                                );
                                final names = overseers
                                    .map(
                                      (o) =>
                                          (o['overseer_initials_surname'] ??
                                                  o['overseerInitialsAndSurname'])
                                              .toString(),
                                    )
                                    .toList();

                                _buildActionSheet(
                                  context: context,
                                  title: 'Select Overseer',
                                  actions: names,
                                  onSelected: (val) {
                                    final selectedDoc = overseers.firstWhere(
                                      (o) =>
                                          (o['overseer_initials_surname'] ??
                                              o['overseerInitialsAndSurname']) ==
                                          val,
                                    );
                                    setModalState(() {
                                      _selectedMemberUid =
                                          selectedDoc['uid'] ??
                                          selectedDoc['id']
                                              .toString(); // Prefer UID if available
                                      _currentOverseerData = selectedDoc;
                                      _selectedDistrictElder = null;
                                      _selectedCommunityName = null;
                                      _communityNames = [];

                                      final districts =
                                          selectedDoc['districts']
                                              as List<dynamic>? ??
                                          [];
                                      _districtElderNames = districts
                                          .map(
                                            (d) =>
                                                (d['district_elder_name'] ??
                                                        d['districtElderName'])
                                                    .toString(),
                                          )
                                          .toList();
                                    });
                                  },
                                );
                              },
                            ),

                          if (_selectedMemberUid != null)
                            _buildNeuDropdownRow(
                              title: 'District Elder',
                              value: _selectedDistrictElder,
                              baseColor: baseColor,
                              onTap: () {
                                if (_districtElderNames.isEmpty) return;
                                _buildActionSheet(
                                  context: context,
                                  title: 'Select District',
                                  actions: _districtElderNames,
                                  onSelected: (val) {
                                    setModalState(() {
                                      _selectedDistrictElder = val;
                                      _selectedCommunityName = null;
                                      final districts =
                                          _currentOverseerData!['districts']
                                              as List<dynamic>;
                                      final selectedDistrict = districts
                                          .firstWhere(
                                            (d) =>
                                                (d['district_elder_name'] ??
                                                    d['districtElderName']) ==
                                                val,
                                          );
                                      final communities =
                                          selectedDistrict['communities']
                                              as List<dynamic>? ??
                                          [];
                                      _communityNames = communities
                                          .map(
                                            (c) =>
                                                (c['community_name'] ??
                                                        c['communityName'])
                                                    .toString(),
                                          )
                                          .toList();
                                    });
                                  },
                                );
                              },
                            ),

                          if (_selectedDistrictElder != null)
                            _buildNeuDropdownRow(
                              title: 'Community',
                              value: _selectedCommunityName,
                              baseColor: baseColor,
                              onTap: () {
                                if (_communityNames.isEmpty) return;
                                _buildActionSheet(
                                  context: context,
                                  title: 'Select Community',
                                  actions: _communityNames,
                                  onSelected: (val) {
                                    setModalState(() {
                                      _selectedCommunityName = val;
                                    });
                                  },
                                );
                              },
                            ),

                          const SizedBox(height: 30),
                          GestureDetector(
                            onTap: _saveProfileChanges,
                            child: NeumorphicContainer(
                              color: theme.primaryColor,
                              borderRadius: 30,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() => _pickedFile = null);
  }

  // --- ACTIONS ---
  Future<void> _pickImage(StateSetter setModalState) async {
    final picker = ImagePicker();
    final pickedXFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedXFile != null) setModalState(() => _pickedFile = pickedXFile);
  }

  void _saveProfileChanges() {
    if (_nameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill name fields.')));
      return;
    }
    final updatedData = {
      'name': _nameController.text.trim(),
      'surname': _surnameController.text.trim(),
      'phone': _contactNumberController.text.trim(),
      'address': _addressController.text.trim(),
      'province': _selectedProvince,
      'role': _selectedRole,
      'overseer_uid': _selectedMemberUid, // Django Field
      'district_elder_name': _selectedDistrictElder, // Django Field
      'community_name': _selectedCommunityName, // Django Field
    };
    _updateUserData(updatedData);
    Navigator.of(context).pop();
  }

  void _onEditPressed() async {
    final Map<String, dynamic>? userData = await _fetchUserProfile();
    if (userData != null) {
      if (mounted) _showEditProfileSheet(context, userData);
    }
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    if (userId == null) {
      return Scaffold(
        backgroundColor: baseColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: NeumorphicContainer(
                        color: baseColor,
                        borderRadius: 50,
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.arrow_back,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Please log in.', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 30),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/login'),
                      child: NeumorphicContainer(
                        color: theme.primaryColor,
                        borderRadius: 30,
                        padding: EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 16,
                        ),
                        child: Text(
                          "Log In",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: baseColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: NeumorphicContainer(
                      color: baseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.arrow_back, color: theme.primaryColor),
                    ),
                  ),
                  Text(
                    "My Profile",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: _onEditPressed,
                    child: NeumorphicContainer(
                      color: baseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.edit, color: theme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 900),
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: _profileFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        );
                      if (!snapshot.hasData)
                        return Center(child: Text('Profile Not Found'));

                      final data = snapshot.data!;
                      String? profileUrl =
                          data['profile_image'] ??
                          data['profileUrl']; // Handle Snake Case

                      return ListView(
                        padding: const EdgeInsets.all(20.0),
                        children: [
                          Center(
                            child: NeumorphicContainer(
                              color: baseColor,
                              borderRadius: 100,
                              padding: EdgeInsets.all(8),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundImage:
                                    (profileUrl != null &&
                                        profileUrl.isNotEmpty)
                                    ? NetworkImage(
                                        _getSecureImageUrl(profileUrl),
                                      )
                                    : AssetImage('assets/no_profile.png')
                                          as ImageProvider,
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Text(
                              '${data['name']} ${data['surname']}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              data['email'] ?? '',
                              style: TextStyle(color: theme.hintColor),
                            ),
                          ),
                          SizedBox(height: 10),
                          Center(
                            child: NeumorphicContainer(
                              color: baseColor,
                              isPressed: true,
                              borderRadius: 20,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: Text(
                                (data['role'] ?? 'N/A')
                                    .toString()
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 30),

                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDetailsSection(
                                    theme,
                                    baseColor,
                                    data,
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildWeeklyProgress(
                                        theme,
                                        baseColor,
                                        data,
                                      ),
                                      SizedBox(height: 20),
                                      _buildApplicationsList(
                                        theme,
                                        baseColor,
                                        userId,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildDetailsSection(theme, baseColor, data),
                                SizedBox(height: 20),
                                _buildApplicationsList(
                                  theme,
                                  baseColor,
                                  userId,
                                ),
                                SizedBox(height: 20),
                                _buildWeeklyProgress(theme, baseColor, data),
                              ],
                            ),

                          SizedBox(height: 20),
                          tryBuildAd(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (WIDGET HELPERS KEPT SAME AS BEFORE) ...
  Widget tryBuildAd() {
    try {
      return AdManager().bannerAdWidget();
    } catch (e) {
      return SizedBox();
    }
  }

  Widget _buildDetailsSection(
    ThemeData theme,
    Color baseColor,
    Map<String, dynamic> data,
  ) {
    return Column(
      children: [
        _buildInfoCard(theme, baseColor, "Personal Info", [
          _buildInfoRow(Icons.phone, "Phone", data['phone'] ?? 'N/A'),
          _buildInfoRow(Icons.location_on, "Address", data['address'] ?? 'N/A'),
        ]),
        SizedBox(height: 20),
        _buildInfoCard(theme, baseColor, "Organization", [
          _buildInfoRow(Icons.map, "Province", data['province'] ?? 'N/A'),
          // Handle both camelCase and snake_case for Django compatibility
          _buildInfoRow(
            Icons.group,
            "Community",
            data['community_name'] ?? data['communityName'] ?? 'N/A',
          ),
          _buildInfoRow(
            Icons.person,
            "Elder",
            data['district_elder_name'] ?? data['districtElderName'] ?? 'N/A',
          ),
        ]),
      ],
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    Color baseColor,
    String title,
    List<Widget> children,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      padding: EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          Divider(color: theme.hintColor.withOpacity(0.2)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. WEEKLY PROGRESS (DJANGO MAPPING) ---
  Widget _buildWeeklyProgress(
    ThemeData theme,
    Color baseColor,
    Map<String, dynamic> data,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      borderRadius: 20,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weekly Contributions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: 15),
          NeumorphicContainer(
            color: baseColor,
            isPressed: true,
            borderRadius: 12,
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                _buildProgressRow("Week 1", data['week1']),
                Divider(),
                _buildProgressRow("Week 2", data['week2']),
                Divider(),
                _buildProgressRow("Week 3", data['week3']),
                Divider(),
                _buildProgressRow("Week 4", data['week4']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, dynamic value) {
    double val = double.tryParse(value.toString()) ?? 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            "R${val.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. FETCH APPLICATIONS (DJANGO) ---
  Widget _buildApplicationsList(
    ThemeData theme,
    Color baseColor,
    String userId,
  ) {
    return NeumorphicContainer(
      color: baseColor,
      borderRadius: 20,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "My Applications",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: 10),
          FutureBuilder(
            // URL: /api/university_applications/?user_uid=UID
            future: http.get(
              Uri.parse(
                '${Api().BACKEND_BASE_URL_DEBUG}/university_applications/?user_uid=$userId',
              ),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    "Loading...",
                    style: TextStyle(color: Colors.grey),
                  ),
                );

              if (snapshot.hasData && snapshot.data!.statusCode == 200) {
                List apps = json.decode(snapshot.data!.body);
                if (apps.isEmpty)
                  return Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      "No applications yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: apps.length,
                  itemBuilder: (ctx, index) {
                    var data = apps[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: NeumorphicContainer(
                        color: baseColor,
                        isPressed: true,
                        borderRadius: 12,
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.school, color: theme.primaryColor),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['university_name'] ?? 'N/A',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    data['status'] ?? 'Pending',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getStatusColor(data['status']),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return Padding(
                padding: EdgeInsets.all(10),
                child: Text(
                  "Failed to load.",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Re-used widgets for Edit Sheet
  Widget _buildNeuEditField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required Color baseColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: true,
        borderRadius: 12,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: Icon(icon, color: Colors.grey),
            hintText: hint,
          ),
        ),
      ),
    );
  }

  Widget _buildNeuDropdownRow({
    required String title,
    required String? value,
    required VoidCallback onTap,
    required Color baseColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: onTap,
        child: NeumorphicContainer(
          color: baseColor,
          isPressed: false,
          borderRadius: 12,
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Text(
                    value ?? 'Select',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).hintColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.hintColor,
          ),
        ),
      ),
    );
  }

  void _buildActionSheet({
    required BuildContext context,
    required String title,
    required List<String> actions,
    required ValueChanged<String> onSelected,
  }) {
    if (isIOSPlatform) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(title),
          actions: actions
              .map(
                (item) => CupertinoActionSheetAction(
                  child: Text(item),
                  onPressed: () {
                    onSelected(item);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
                Divider(),
                ...actions
                    .map(
                      (item) => ListTile(
                        title: Text(item),
                        onTap: () {
                          onSelected(item);
                          Navigator.pop(context);
                        },
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
        ),
      );
    }
  }
}
