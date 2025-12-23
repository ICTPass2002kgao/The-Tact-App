// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_typing_uninitialized_variables

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'dart:io' as io; // Safe import for File usage
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Custom_Buttons.dart';
import 'package:ttact/Components/API.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// --- HELPER WIDGETS ---
Widget _buildPlatformTextField({
  required TextEditingController controller,
  required String placeholder,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  bool readOnly = false,
  int? maxLines = 1,
  String? Function(String?)? validator,
  Widget? suffixIcon,
  required BuildContext context,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: isIOSPlatform
        ? CupertinoTextField(
            style: TextStyle(color: Theme.of(context).cardColor),
            controller: controller,
            placeholder: placeholder,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(12.0),
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(prefixIcon, color: CupertinoColors.systemGrey),
                  )
                : null,
            suffixMode: OverlayVisibilityMode.editing,
            suffix: suffixIcon,
          )
        : TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
            ),
            validator: validator,
          ),
  );
}

Widget _buildListTile({
  required String title,
  required String trailingText,
  required VoidCallback onTap,
  required BuildContext context,
  IconData? leadingIcon,
  String? subtitle,
}) {
  if (isIOSPlatform) {
    return CupertinoListTile(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: Theme.of(context).primaryColor)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText, style: TextStyle(color: Colors.grey[600])),
          const Icon(CupertinoIcons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  } else {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: Theme.of(context).primaryColor)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText, style: TextStyle(color: Colors.grey[600])),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }
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
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(title),
        actions: actions.map((item) {
          return CupertinoActionSheetAction(
            child: Text(item),
            onPressed: () {
              onSelected(item);
              Navigator.pop(context);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, textAlign: TextAlign.center),
              const Divider(),
              ...actions.map((item) {
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    onSelected(item);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
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
  String? _selectedMemberUid;
  String? _selectedDistrictElder;
  String? _selectedCommunityName;
  Map<String, dynamic>? _currentOverseerData;
  List<String> _districtElderNames = [];
  List<String> _communityNames = [];

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

  ImageProvider _getProfileImage() {
    if (_pickedFile != null) {
      if (kIsWeb) {
        return NetworkImage(_pickedFile!.path);
      } else {
        return FileImage(io.File(_pickedFile!.path));
      }
    } else if (_currentProfileImageUrl != null &&
        _currentProfileImageUrl!.isNotEmpty) {
      return NetworkImage(_currentProfileImageUrl!);
    } else {
      return AssetImage('assets/no_profile.png');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(StateSetter setModalState) async {
    final picker = ImagePicker();
    final pickedXFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedXFile != null) {
      setModalState(() {
        _pickedFile = pickedXFile;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_pickedFile == null) {
      return _currentProfileImageUrl;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profile_images')
          .child('${user.uid}.jpg');

      UploadTask uploadTask;

      if (kIsWeb) {
        final bytes = await _pickedFile!.readAsBytes();
        uploadTask = storageRef.putData(bytes);
      } else {
        uploadTask = storageRef.putFile(io.File(_pickedFile!.path));
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: ${e.message}')),
        );
      }
      return null;
    }
  }

  Future<void> _updateUserData(Map<String, dynamic> dataToUpdate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      isIOSPlatform
          ? Api().showIosLoading(context)
          : Api().showLoading(context);

      String? newProfileUrl = await _uploadImage();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          ...dataToUpdate,
          if (newProfileUrl != null) 'profileUrl': newProfileUrl,
        },
      );

      if (newProfileUrl != null) {
        await user.updatePhotoURL(newProfileUrl);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    }
  }

  Future<void> _fetchOverseerData(
    String overseerUid,
    StateSetter setModalState,
  ) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: overseerUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();

        setModalState(() {
          _currentOverseerData = data;

          final districts = data['districts'] as List<dynamic>? ?? [];
          _districtElderNames = districts
              .map((d) => d['districtElderName'] as String)
              .toList();

          if (_selectedDistrictElder != null) {
            final selectedDistrict = districts.firstWhere(
              (d) => d['districtElderName'] == _selectedDistrictElder,
              orElse: () => null,
            );

            if (selectedDistrict != null) {
              final communities =
                  selectedDistrict['communities'] as List<dynamic>? ?? [];
              _communityNames = communities
                  .map((c) => c['communityName'] as String)
                  .toList();
            } else {
              _communityNames = [];
              _selectedCommunityName = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching overseer data: $e");
    }
  }

  void _showEditProfileSheet(
    BuildContext context,
    Map<String, dynamic> currentData,
  ) {
    _nameController.text = currentData['name'] ?? '';
    _surnameController.text = currentData['surname'] ?? '';
    _addressController.text = currentData['address'] ?? '';
    _contactNumberController.text = currentData['phone'] ?? '';
    _currentProfileImageUrl = currentData['profileUrl'];
    _pickedFile = null;

    _selectedProvince = currentData['province'];
    _selectedMemberUid = currentData['overseerUid'];
    _selectedDistrictElder = currentData['districtElderName'];
    _selectedCommunityName = currentData['communityName'];

    _currentOverseerData = null;
    _districtElderNames = [];
    _communityNames = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                if (_selectedMemberUid != null &&
                    _currentOverseerData == null) {
                  _fetchOverseerData(_selectedMemberUid!, setModalState);
                }

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16.0,
                    right: 16.0,
                    top: 24.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Edit Profile',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 20, thickness: 1),
                          const SizedBox(height: 20),

                          GestureDetector(
                            onTap: () async {
                              await _pickImage(setModalState);
                            },
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              backgroundImage: _getProfileImage(),
                              child:
                                  (_pickedFile == null &&
                                      (_currentProfileImageUrl == null ||
                                          _currentProfileImageUrl!.isEmpty))
                                  ? Icon(
                                      Icons.camera_alt,
                                      size: 40,
                                      color: Theme.of(context).primaryColor,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          isIOSPlatform
                              ? CupertinoButton(
                                  child: Text('Change Profile Picture'),
                                  onPressed: () async =>
                                      await _pickImage(setModalState),
                                )
                              : TextButton(
                                  onPressed: () async =>
                                      await _pickImage(setModalState),
                                  child: const Text('Change Profile Picture'),
                                ),
                          const SizedBox(height: 20),

                          Text(
                            "Personal Details",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildPlatformTextField(
                            context: context,
                            controller: _nameController,
                            placeholder: 'First Name',
                            prefixIcon: CupertinoIcons.person,
                          ),
                          _buildPlatformTextField(
                            context: context,
                            controller: _surnameController,
                            placeholder: 'Last Name',
                            prefixIcon: CupertinoIcons.person_alt,
                          ),
                          _buildPlatformTextField(
                            context: context,
                            controller: _contactNumberController,
                            placeholder: 'Contact Number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: CupertinoIcons.phone,
                          ),
                          _buildPlatformTextField(
                            context: context,
                            controller: _addressController,
                            placeholder: 'Address',
                            maxLines: 2,
                            prefixIcon: CupertinoIcons.location,
                          ),
                          const SizedBox(height: 20),

                          Text(
                            "Organization Details",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),

                          _buildListTile(
                            context: context,
                            title: 'Province',
                            leadingIcon: Icons.map,
                            trailingText: _selectedProvince ?? 'Select',
                            onTap: () {
                              _buildActionSheet(
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
                              );
                            },
                          ),

                          if (_selectedProvince != null)
                            _buildListTile(
                              context: context,
                              title: 'Overseer',
                              leadingIcon: Icons.supervisor_account,
                              trailingText:
                                  _currentOverseerData?['overseerInitialsAndSurname'] ??
                                  (_selectedMemberUid != null
                                      ? 'Loading...'
                                      : 'Select'),
                              onTap: () async {
                                final snapshot = await FirebaseFirestore
                                    .instance
                                    .collection('overseers')
                                    .where(
                                      'province',
                                      isEqualTo: _selectedProvince,
                                    )
                                    .get();

                                if (snapshot.docs.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "No overseers found in $_selectedProvince",
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final overseers = snapshot.docs
                                    .map((doc) => doc.data())
                                    .toList();
                                final names = overseers
                                    .map(
                                      (o) =>
                                          o['overseerInitialsAndSurname']
                                              as String,
                                    )
                                    .toList();

                                _buildActionSheet(
                                  context: context,
                                  title: 'Select Overseer',
                                  actions: names,
                                  onSelected: (val) {
                                    final selectedDoc = overseers.firstWhere(
                                      (o) =>
                                          o['overseerInitialsAndSurname'] ==
                                          val,
                                    );
                                    setModalState(() {
                                      _selectedMemberUid = selectedDoc['uid'];
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
                                                d['districtElderName']
                                                    as String,
                                          )
                                          .toList();
                                    });
                                  },
                                );
                              },
                            ),

                          if (_selectedMemberUid != null)
                            _buildListTile(
                              context: context,
                              title: 'District Elder',
                              leadingIcon: Icons.person,
                              trailingText: _selectedDistrictElder ?? 'Select',
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
                                                d['districtElderName'] == val,
                                          );
                                      final communities =
                                          selectedDistrict['communities']
                                              as List<dynamic>? ??
                                          [];
                                      _communityNames = communities
                                          .map(
                                            (c) => c['communityName'] as String,
                                          )
                                          .toList();
                                    });
                                  },
                                );
                              },
                            ),

                          if (_selectedDistrictElder != null)
                            _buildListTile(
                              context: context,
                              title: 'Community Name',
                              leadingIcon: Icons.home,
                              trailingText: _selectedCommunityName ?? 'Select',
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

                          const SizedBox(height: 24),

                          isIOSPlatform
                              ? CupertinoButton.filled(
                                  child: const Text(
                                    'Save Changes',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  onPressed: _saveProfileChanges,
                                )
                              : ElevatedButton(
                                  onPressed: _saveProfileChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Save Changes',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                          const SizedBox(height: 20),
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
    ).whenComplete(() {
      _pickedFile = null;
    });
  }

  void _saveProfileChanges() {
    if (_nameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty ||
        _contactNumberController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all personal fields.')),
      );
      return;
    }

    if (_selectedProvince != null &&
        (_selectedMemberUid == null ||
            _selectedDistrictElder == null ||
            _selectedCommunityName == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all organization details.'),
        ),
      );
      return;
    }

    final updatedData = {
      'name': _nameController.text.trim(),
      'surname': _surnameController.text.trim(),
      'phone': _contactNumberController.text.trim(),
      'address': _addressController.text.trim(),
      'province': _selectedProvince,
      'overseerUid': _selectedMemberUid,
      'districtElderName': _selectedDistrictElder,
      'communityName': _selectedCommunityName,
    };

    _updateUserData(updatedData);
    Navigator.of(context).pop();
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    if (isIOSPlatform) {
      return CupertinoNavigationBar(
        middle: const Text('My Profile'),
        backgroundColor: theme.primaryColor,
        leading: CupertinoNavigationBarBackButton(
          color: theme.scaffoldBackgroundColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.pencil,
            color: theme.scaffoldBackgroundColor,
          ),
          onPressed: _onEditPressed,
        ),
        brightness: Brightness.dark,
      );
    } else {
      return AppBar(
        title: const Text('My Profile'),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _onEditPressed),
        ],
      );
    }
  }

  void _onEditPressed() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (userDoc.exists) {
      _showEditProfileSheet(context, userDoc.data() as Map<String, dynamic>);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load profile data for editing.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    if (userId == null) {
      return Scaffold(
        appBar: _buildAppBar(theme),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Center(child: Text('Please log in to view your profile.')),
            const SizedBox(height: 20),
            Custom_Button(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              text: 'Log In',
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.scaffoldBackgroundColor,
              minWidth: 200,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(theme),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 900),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: isIOSPlatform
                      ? CupertinoActivityIndicator()
                      : CircularProgressIndicator(color: theme.primaryColor),
                );
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              // Defensive check
              if (!snapshot.hasData ||
                  snapshot.data == null ||
                  !snapshot.data!.exists) {
                return const Center(child: Text('No User Data Found.'));
              }

              // Safe Cast
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          backgroundImage:
                              (data['profileUrl'] != null &&
                                  data['profileUrl'].toString().isNotEmpty)
                              ? NetworkImage(data['profileUrl'])
                              : const AssetImage('assets/no_profile.png')
                                    as ImageProvider,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${data['name'] ?? ''} ${data['surname'] ?? ''}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['email'] ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            (data['role'] ?? 'N/A').toString().toUpperCase(),
                          ),
                          backgroundColor: theme.primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildPersonalAndOrgDetails(
                                theme,
                                data['phone'] ?? 'N/A',
                                data['address'] ?? 'N/A',
                                data['province'] ?? 'N/A',
                                data['communityName'] ?? 'N/A',
                                data['districtElderName'] ?? 'N/A',
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildWeeklyProgressCard(
                                    theme,
                                    (data['week1'] as num?)?.toDouble() ?? 0.0,
                                    (data['week2'] as num?)?.toDouble() ?? 0.0,
                                    (data['week3'] as num?)?.toDouble() ?? 0.0,
                                    (data['week4'] as num?)?.toDouble() ?? 0.0,
                                  ),
                                  _buildUserApplicationsCard(theme, userId),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildPersonalAndOrgDetails(
                              theme,
                              data['phone'] ?? 'N/A',
                              data['address'] ?? 'N/A',
                              data['province'] ?? 'N/A',
                              data['communityName'] ?? 'N/A',
                              data['districtElderName'] ?? 'N/A',
                            ),
                            _buildUserApplicationsCard(theme, userId),
                            _buildWeeklyProgressCard(
                              theme,
                              (data['week1'] as num?)?.toDouble() ?? 0.0,
                              (data['week2'] as num?)?.toDouble() ?? 0.0,
                              (data['week3'] as num?)?.toDouble() ?? 0.0,
                              (data['week4'] as num?)?.toDouble() ?? 0.0,
                            ),
                          ],
                        ),
                  tryBuildAd(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget tryBuildAd() {
    try {
      return AdManager().bannerAdWidget();
    } catch (e) {
      return SizedBox();
    }
  }

  Widget _buildCardWrapper({
    required ThemeData theme,
    required List<Widget> children,
    required String title,
  }) {
    return Card(
      color: theme.scaffoldBackgroundColor.withOpacity(0.9),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalAndOrgDetails(
    ThemeData theme,
    String contactNumber,
    String address,
    String province,
    String communityName,
    String districtElderName,
  ) {
    return Column(
      children: [
        _buildCardWrapper(
          theme: theme,
          title: 'Personal Information',
          children: [
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform ? CupertinoIcons.phone : Icons.phone,
              title: 'Contact Number',
              trailingText: contactNumber,
              onTap: () {},
            ),
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform
                  ? CupertinoIcons.location
                  : Icons.location_on,
              title: 'Address',
              trailingText: address,
              onTap: () {},
            ),
          ],
        ),
        _buildCardWrapper(
          theme: theme,
          title: 'Organizational Details',
          children: [
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform
                  ? CupertinoIcons.building_2_fill
                  : Icons.apartment,
              title: 'Province',
              trailingText: province,
              onTap: () {},
            ),
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform ? CupertinoIcons.group : Icons.group,
              title: 'Community Name',
              trailingText: communityName,
              onTap: () {},
            ),
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform
                  ? CupertinoIcons.person_3
                  : Icons.supervisor_account,
              title: 'District Elder',
              trailingText: districtElderName,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserApplicationsCard(ThemeData theme, String userId) {
    return _buildCardWrapper(
      theme: theme,
      title: 'My Applications',
      children: [_buildUserApplicationsList(theme, userId)],
    );
  }

  Widget _buildWeeklyProgressCard(
    ThemeData theme,
    double w1,
    double w2,
    double w3,
    double w4,
  ) {
    return _buildCardWrapper(
      theme: theme,
      title: 'Weekly Progress',
      children: [
        Table(
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
          border: TableBorder.all(color: Colors.grey.shade300),
          children: [
            _buildTableRow('Week 1', 'R${w1.toStringAsFixed(2)}', theme),
            _buildTableRow('Week 2', 'R${w2.toStringAsFixed(2)}', theme),
            _buildTableRow('Week 3', 'R${w3.toStringAsFixed(2)}', theme),
            _buildTableRow('Week 4', 'R${w4.toStringAsFixed(2)}', theme),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value, ThemeData theme) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // --- FIXED STREAM BUILDER LOGIC ---
  Widget _buildUserApplicationsList(ThemeData theme, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('university_applications')
          .orderBy('submissionDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Handle Waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }

        // 2. Handle Errors
        if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Error loading applications'),
          );
        }

        // 3. Handle Empty Data (Null or Empty List)
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No applications submitted yet.'),
          );
        }

        // 4. Safe to display
        final docs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          primary: false, // Helps preventing scroll conflict in nested lists
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            // Safely cast the data with checks
            var data = docs[index].data() as Map<String, dynamic>? ?? {};

            return Card(
              margin: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.school, color: theme.primaryColor),
                title: Text(
                  data['universityName'] ?? 'N/A',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Program: ${data['primaryProgram'] ?? 'N/A'}'),
                    Text(
                      'Status: ${data['status'] ?? 'N/A'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(data['status'] ?? 'N/A'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.orange;
      case 'Reviewed':
        return Colors.blue;
      case 'Applied':
        return Colors.purple;
      case 'Accepted':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}
