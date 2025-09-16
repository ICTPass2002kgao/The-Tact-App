import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Import Cupertino
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Custom_Buttons.dart'; // For formatting dates

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

  File? _pickedImage;
  String? _currentProfileImageUrl;

  final _formKey = GlobalKey<FormState>(); // Still useful for validation logic

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) {
      return _currentProfileImageUrl;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profile_images')
          .child('$userId.jpg');

      await storageRef.putFile(_pickedImage!);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      if (mounted) {
        // Check if the widget is still mounted
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updating profile...')));
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        setState(() {}); // Refresh the UI by re-fetching data
        // Navigator.of(context).pop(); // Removed this line, not always desired to pop after update
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication Error: ${e.message}')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore Error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
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
    _pickedImage =
        null; // Clear picked image when opening sheet for existing data

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Wrap with a StateSetter to allow setState within the builder for image preview
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16.0,
                right: 16.0,
                top: 24.0,
              ),
              child: Form(
                // Still use Form for validation logic
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
                          await _pickImage(); // Call original pickImage
                          setModalState(
                            () {},
                          ); // Update modal state to show new image
                        },
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor:
                              _pickedImage == null &&
                                  (_currentProfileImageUrl == null ||
                                      _currentProfileImageUrl!.isEmpty)
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                          child:
                              _pickedImage == null &&
                                  (_currentProfileImageUrl == null ||
                                      _currentProfileImageUrl!.isEmpty)
                              ? Icon(
                                  Icons.camera_alt,
                                  size: 60,
                                  color: Theme.of(context).primaryColor,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () async {
                          await _pickImage(); // Call original pickImage
                          setModalState(
                            () {},
                          ); // Update modal state to show new image
                        },
                        child: const Text('Change Profile Picture'),
                      ),
                      const SizedBox(height: 20),

                      // CupertinoTextField for Name
                      CupertinoTextField(
                        controller: _nameController,
                        placeholder: 'First Name',
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.lightBackgroundGray,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(CupertinoIcons.person),
                        ),
                        // Validation logic - integrate with Form
                        onChanged: (value) => _formKey.currentState?.validate(),
                      ),
                      const SizedBox(height: 12),

                      // CupertinoTextField for Surname
                      CupertinoTextField(
                        controller: _surnameController,
                        placeholder: 'Last Name',
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.lightBackgroundGray,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(CupertinoIcons.person_alt),
                        ),
                        onChanged: (value) => _formKey.currentState?.validate(),
                      ),
                      const SizedBox(height: 12),

                      // CupertinoTextField for Contact Number
                      CupertinoTextField(
                        controller: _contactNumberController,
                        placeholder: 'Contact Number',
                        keyboardType: TextInputType.phone,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.lightBackgroundGray,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(CupertinoIcons.phone),
                        ),
                        onChanged: (value) => _formKey.currentState?.validate(),
                      ),
                      const SizedBox(height: 12),

                      // CupertinoTextField for Address
                      CupertinoTextField(
                        controller: _addressController,
                        placeholder: 'Address',
                        maxLines: 3, // Allow multiple lines for address
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: CupertinoColors.lightBackgroundGray,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(CupertinoIcons.location),
                        ),
                        onChanged: (value) => _formKey.currentState?.validate(),
                      ),
                      const SizedBox(height: 24),

                      // Note: Cupertino doesn't have a direct equivalent of TextFormField's validator property.
                      // You'll need to manually validate when the Save button is pressed.
                      ElevatedButton(
                        onPressed: () {
                          // Manual validation for CupertinoTextFields
                          if (_nameController.text.trim().isEmpty ||
                              _surnameController.text.trim().isEmpty ||
                              _contactNumberController.text.trim().isEmpty ||
                              _addressController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill all required fields.',
                                ),
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
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
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
        );
      },
    ).whenComplete(() {
      _pickedImage = null;
      // _currentProfileImageUrl is maintained for display if not updated
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: theme.primaryColor,
          foregroundColor: theme.scaffoldBackgroundColor,
          centerTitle: true,
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Center(child: Text('Please log in to view your profile.')),
            const SizedBox(height: 20),
            Custom_Button(
              onPressed: () {
                // Define your onPressed logic here
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
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
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
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
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
          final String address = data['address'] ?? 'N/A';
          final String contactNumber = data['phone'] ?? 'N/A';
          final String role = data['role'] ?? 'N/A';
          final String province = data['province'] ?? 'N/A';
          final String districtElderName = data['districtElderName'] ?? 'N/A';
          final String communityElderName = data['communityElderName'] ?? 'N/A';
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
              Card(
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
                        'Personal Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      ListTile(
                        leading: Icon(Icons.phone, color: theme.primaryColor),
                        title: const Text('Contact Number'),
                        subtitle: Text(contactNumber),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: theme.primaryColor,
                        ),
                        title: const Text('Address'),
                        subtitle: Text(address),
                      ),
                    ],
                  ),
                ),
              ),
              // --- Applications Section ---
              Card(
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
                        'My Applications',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      _buildUserApplicationsList(theme, userId),
                    ],
                  ),
                ),
              ),
              // --- End Applications Section ---
              Card(
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
                        'Organizational Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      ListTile(
                        leading: Icon(
                          Icons.apartment,
                          color: theme.primaryColor,
                        ),
                        title: const Text('Province'),
                        subtitle: Text(province),
                      ),
                      ListTile(
                        leading: Icon(Icons.group, color: theme.primaryColor),
                        title: const Text('Community Name'),
                        subtitle: Text(communityName),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.person_outline,
                          color: theme.primaryColor,
                        ),
                        title: const Text('Community Elder'),
                        subtitle: Text(communityElderName),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.supervisor_account,
                          color: theme.primaryColor,
                        ),
                        title: const Text('District Elder'),
                        subtitle: Text(districtElderName),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
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
                        'Weekly Progress',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20, thickness: 1),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(2),
                        },
                        border: TableBorder.all(color: Colors.grey.shade300),
                        children: [
                          _buildTableRow(
                            'Week 1',
                            'R${week1.toStringAsFixed(2)}',
                            theme,
                          ),
                          _buildTableRow(
                            'Week 2',
                            'R${week2.toStringAsFixed(2)}',
                            theme,
                          ),
                          _buildTableRow(
                            'Week 3',
                            'R${week3.toStringAsFixed(2)}',
                            theme,
                          ),
                          _buildTableRow(
                            'Week 4',
                            'R${week4.toStringAsFixed(2)}',
                            theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              AdManager().bannerAdWidget(),
            ],
          );
        },
      ),
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
          return const Center(child: CupertinoActivityIndicator());
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

            // Safely access data
            // These fields MUST be present directly in the university_applications document
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
