// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_typing_uninitialized_variables

// --- PLATFORM IMPORTS FIX: Rerouting dart:io ---
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb

// Import dart:io.File with an alias 'io' ONLY on non-web platforms.
import 'dart:io' as io show File; // <-- FIX: Imports ONLY the File class for use as io.File
import 'package:image_picker/image_picker.dart';

// --- REST OF IMPORTS ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Custom_Buttons.dart';
import 'package:ttact/Components/API.dart'; // Import API for showLoading

// --- PLATFORM UTILITIES ---
// UPDATED: This logic now checks the OS, even on the web.
bool get isIOSPlatform {
  // Checks for iOS or macOS (which iPads/Macs report in browsers)
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// UPDATED: This logic now checks the OS, even on the web.
bool get isAndroidPlatform {
  // Checks for Android, Linux, or Fuchsia to default to Material style.
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// ------------------------

// --- COPIED HELPERS FROM SIGNUPPAGE ---

// Custom platform-aware TextField Builder
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

// Custom platform-aware ListTile Builder
Widget _buildListTile({
  required String title,
  required String trailingText,
  required VoidCallback onTap,
  required BuildContext context,
  IconData? leadingIcon, // Added for flexibility
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

// Custom platform-aware Action Sheet Builder
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
// --- END COPIED HELPERS ---

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

  final _formKey = GlobalKey<FormState>();

  // Helper for profile image display
  ImageProvider _getProfileImage() {
    if (_pickedFile != null) {
      if (kIsWeb) {
        // Web: Use the path which is actually a data URL or blob
        return NetworkImage(_pickedFile!.path);
      } else {
        // Mobile/Desktop: Use dart:io.File, referenced via alias
        return FileImage(io.File(_pickedFile!.path)); // <--- CORRECTED LINE
      }
    } else if (_currentProfileImageUrl != null &&
        _currentProfileImageUrl!.isNotEmpty) {
      // Existing network image
      return NetworkImage(_currentProfileImageUrl!);
    } else {
      // Default placeholder
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
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profile_images')
          .child('$userId.jpg');

      UploadTask uploadTask;

      if (kIsWeb) {
        // Web-safe upload using bytes
        final bytes = await _pickedFile!.readAsBytes();
        uploadTask = storageRef.putData(bytes);
      } else {
        // Mobile/Desktop upload using dart:io.File, referenced via alias
        uploadTask =
            storageRef.putFile(io.File(_pickedFile!.path)); // <--- CORRECTED LINE
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
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
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not logged in.')));
      }
      return;
    }

    try {
isIOSPlatform?
    Api().showIosLoading(context):
 
    Api().showLoading(context);; // Use platform-aware loading

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
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() {}); // Refresh the UI by re-fetching data
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication Error: ${e.message}')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore Error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
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
    _pickedFile = null; // Clear picked file when opening sheet for existing data

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Use ConstrainedBox for a nice look on wide screens
        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 500), // Max width for the modal
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
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
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 20, thickness: 1),
                          const SizedBox(height: 20),

                          GestureDetector(
                            onTap: () async {
                              await _pickImage(
                                  setModalState); // Pass setModalState
                            },
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              backgroundImage:
                                  _getProfileImage(), // Use safe image getter
                              child: (_pickedFile == null &&
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
                          // --- PLATFORM AWARE BUTTON ---
                          isIOSPlatform
                              ? CupertinoButton(
                                  child: Text('Change Profile Picture'),
                                  onPressed: () async {
                                    await _pickImage(setModalState);
                                  },
                                )
                              : TextButton(
                                  onPressed: () async {
                                    await _pickImage(setModalState);
                                  },
                                  child: const Text('Change Profile Picture'),
                                ),
                          const SizedBox(height: 20),

                          // --- PLATFORM AWARE TEXT FIELDS ---
                          _buildPlatformTextField(
                            context: context,
                            controller: _nameController,
                            placeholder: 'First Name',
                            prefixIcon: CupertinoIcons.person,
                          ),
                          const SizedBox(height: 12),
                          _buildPlatformTextField(
                            context: context,
                            controller: _surnameController,
                            placeholder: 'Last Name',
                            prefixIcon: CupertinoIcons.person_alt,
                          ),
                          const SizedBox(height: 12),
                          _buildPlatformTextField(
                            context: context,
                            controller: _contactNumberController,
                            placeholder: 'Contact Number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: CupertinoIcons.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildPlatformTextField(
                            context: context,
                            controller: _addressController,
                            placeholder: 'Address',
                            maxLines: 3,
                            prefixIcon: CupertinoIcons.location,
                          ),
                          const SizedBox(height: 24),

                          // --- PLATFORM AWARE BUTTON ---
                          isIOSPlatform
                              ? CupertinoButton.filled(
                                  child: const Text(
                                    'Save Changes',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  onPressed: () {
                                    _saveProfileChanges();
                                  },
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    _saveProfileChanges();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).primaryColor,
                                    foregroundColor: Theme.of(context)
                                        .scaffoldBackgroundColor,
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

  // --- NEW HELPER: Save Profile Logic ---
  void _saveProfileChanges() {
    if (_nameController.text.trim().isEmpty ||
        _surnameController.text.trim().isEmpty ||
        _contactNumberController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
        ),
      );
      return;
    }

    final updatedData = {
      'name': _nameController.text.trim(),
      'surname': _surnameController.text.trim(),
      'phone': _contactNumberController.text.trim(),
      'address': _addressController.text.trim(),
    };
    _updateUserData(updatedData);
    Navigator.of(context).pop(); // Close the bottom sheet
  }

  // --- PLATFORM AWARE APP BAR ---
  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    if (isIOSPlatform) {
      return CupertinoNavigationBar(
        middle: const Text('My Profile'),
        backgroundColor: theme.primaryColor,
        // This is tricky. CupertinoNavigationBar doesn't handle theming from Material themes well.
        // We'll force the text color.
        leading: CupertinoNavigationBarBackButton(
          color: theme.scaffoldBackgroundColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.pencil, color: theme.scaffoldBackgroundColor),
          onPressed: _onEditPressed,
        ),
        // A bit of a hack to make the text white
        brightness: Brightness.dark, 
      );
    } else {
      return AppBar(
        title: const Text('My Profile'),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _onEditPressed,
          ),
        ],
      );
    }
  }

  // --- NEW HELPER: Edit Button Logic ---
  void _onEditPressed() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return; // Should be handled by the body, but good practice

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      _showEditProfileSheet(
        context,
        userDoc.data() as Map<String, dynamic>,
      );
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
    final bool isDesktop =
        MediaQuery.of(context).size.width > 800; // Define desktop breakpoint

    if (userId == null) {
      return Scaffold(
        appBar: _buildAppBar(theme), // Use platform-aware app bar
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
      appBar: _buildAppBar(theme), // Use platform-aware app bar
      body: Center(
        child: Container(
          // Constrain content width for desktop/web
          constraints: BoxConstraints(maxWidth: 900),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  // --- PLATFORM AWARE ---
                  child: isIOSPlatform
                      ? CupertinoActivityIndicator()
                      : CircularProgressIndicator(color: theme.primaryColor),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text('No User Data Found. Please create your profile.'),
                );
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;

              final String name = data['name'] ?? 'N/A';
              final String surname = data['surname'] ?? 'N/A';
              final String email = data['email'] ?? 'N/A';
              final String profileUrl = data['profileUrl'] ?? '';
              // Update local state for the current image URL for the next edit session
              _currentProfileImageUrl = profileUrl;

              final String address = data['address'] ?? 'N/A';
              final String contactNumber = data['phone'] ?? 'N/A';
              final String role = data['role'] ?? 'N/A';
              
              // Handle new nullable fields for External Members
              final String province = data['province'] ?? 'N/A';
              final String districtElderName =
                  data['districtElderName'] ?? 'N/A';
              final String communityElderName =
                  data['communityElderName'] ?? 'N/A';
              final String communityName = data['communityName'] ?? 'N/A';
              
              final double week1 = (data['week1'] as num?)?.toDouble() ?? 0.00;
              final double week2 = (data['week2'] as num?)?.toDouble() ?? 0.00;
              final double week3 = (data['week3'] as num?)?.toDouble() ?? 0.00;
              final double week4 = (data['week4'] as num?)?.toDouble() ?? 0.00;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          backgroundImage: profileUrl.isNotEmpty
                              ? NetworkImage(profileUrl)
                              : const AssetImage('assets/no_profile.png')
                                  as ImageProvider,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$name $surname',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(role.toUpperCase()),
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

                  // Wrap cards in a Row for desktop/web if desired, otherwise keep stacked (default)
                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _buildPersonalAndOrgDetails(
                                    theme,
                                    contactNumber,
                                    address,
                                    province,
                                    communityName,
                                    districtElderName)),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildWeeklyProgressCard(
                                      theme, week1, week2, week3, week4),
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
                                contactNumber,
                                address,
                                province,
                                communityName,
                                districtElderName),
                            _buildUserApplicationsCard(theme, userId),
                            _buildWeeklyProgressCard(
                                theme, week1, week2, week3, week4),
                          ],
                        ),

                  AdManager().bannerAdWidget(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildCardWrapper(
      {required ThemeData theme,
      required List<Widget> children,
      required String title}) {
    return Card(
      color: theme.scaffoldBackgroundColor.withOpacity(0.9),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
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
      String districtElderName) {
    return Column(
      children: [
        // Personal Information Card
        _buildCardWrapper(
          theme: theme,
          title: 'Personal Information',
          children: [
            // --- PLATFORM AWARE ---
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform ? CupertinoIcons.phone : Icons.phone,
              title: 'Contact Number',
              trailingText: contactNumber,
              onTap: () {}, // No action on tap
            ),
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform ? CupertinoIcons.location : Icons.location_on,
              title: 'Address',
              trailingText: address,
              onTap: () {}, // No action on tap
            ),
          ],
        ),

        // Organizational Details Card (Original)
        _buildCardWrapper(
          theme: theme,
          title: 'Organizational Details',
          children: [
            // --- PLATFORM AWARE ---
            _buildListTile(
              context: context,
              leadingIcon: isIOSPlatform ? CupertinoIcons.building_2_fill : Icons.apartment,
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
              leadingIcon: isIOSPlatform ? CupertinoIcons.person_3 : Icons.supervisor_account,
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
      children: [
        _buildUserApplicationsList(theme, userId),
      ],
    );
  }

  Widget _buildWeeklyProgressCard(
      ThemeData theme, double week1, double week2, double week3, double week4) {
    return _buildCardWrapper(
      theme: theme,
      title: 'Weekly Progress',
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
          },
          border: TableBorder.all(color: Colors.grey.shade300),
          children: [
            _buildTableRow('Week 1', 'R${week1.toStringAsFixed(2)}', theme),
            _buildTableRow('Week 2', 'R${week2.toStringAsFixed(2)}', theme),
            _buildTableRow('Week 3', 'R${week3.toStringAsFixed(2)}', theme),
            _buildTableRow('Week 4', 'R${week4.toStringAsFixed(2)}', theme),
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

  Widget _buildUserApplicationsList(ThemeData theme, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('university_applications')
          .orderBy('submissionDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // --- PLATFORM AWARE ---
          return Center(
              child: isIOSPlatform
                  ? CupertinoActivityIndicator()
                  : CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error loading applications: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('No applications submitted yet.'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true, // Important for nested ListViews
          physics:
              const NeverScrollableScrollPhysics(), // Important for nested ListViews
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var applicationDoc = snapshot.data!.docs[index];
            var applicationData = applicationDoc.data() as Map<String, dynamic>;

            String universityName = applicationData['universityName'] ?? 'N/A';
            String programName = applicationData['primaryProgram'] ?? 'N/A';
            String status = applicationData['status'] ?? 'N/A';
            Timestamp? submissionDate =
                applicationData['submissionDate'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.school, color: theme.primaryColor),
                title: Text(
                  universityName,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Program: $programName'),
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                    if (submissionDate != null)
                      Text(
                        'Submitted: ${DateFormat('MMM dd, yyyy').format(submissionDate.toDate())}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: CupertinoColors.systemGrey,
                ),
                onTap: () {
                  // TODO: Implement navigation to a detailed application view if needed
                },
              ),
            );
          },
        );
      },
    );
  }

  // Helper function to get status-specific colors
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
      case 'Rejected':
        return Colors.red;
      case 'Pending Documents':
        return Colors.deepOrange;
      case 'Withdrawn':
        return Colors.grey;
      default:
        return Colors.black; // Default for unknown statuses
    }
  }
}