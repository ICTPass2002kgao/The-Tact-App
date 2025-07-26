import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart'; // Import for Cupertino widgets
import 'package:flutter/material.dart'; // Still needed for Scaffold, Material, etc.
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// Assuming these are your custom components.
// I'll re-implement their basic functionality using Cupertino widgets for consistency.
import '../Components/CustomOutlinedButton.dart';
import '../Components/API.dart'; // Your API class

// Custom CupertinoTextField Builder for reusability
Widget _buildCupertinoTextField({
  required TextEditingController controller,
  required String placeholder,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  bool readOnly = false,
  int? maxLines = 1,
  String? Function(String?)? validator,
  CupertinoButton? suffixIcon, // For manual validation
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      maxLines: maxLines,
      decoration: BoxDecoration(
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
      suffixMode:
          OverlayVisibilityMode.editing, // Show suffix only when editing
      suffix:
          obscureText // Only show suffix if it's a password field
          ? GestureDetector(
              onTap: () {
                // This will need to be handled by the parent widget's setState
                // if you want to toggle visibility directly within this builder.
                // For simplicity, I'm assuming obscureText is controlled externally.
              },
              child: Icon(
                obscureText
                    ? CupertinoIcons.eye_slash_fill
                    : CupertinoIcons.eye_fill,
                color: CupertinoColors.systemGrey,
              ),
            )
          : null,
    ),
  );
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  TextEditingController txtEmail = TextEditingController();
  TextEditingController txtName = TextEditingController();
  TextEditingController txtSurname = TextEditingController();
  TextEditingController txtAddress = TextEditingController();
  TextEditingController txtContactNumber = TextEditingController();

  TextEditingController txtPassword = TextEditingController();
  TextEditingController txtConfirmPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Used for overall form state
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool isChecked = false;
  Api backendService = Api();
  List<String> roles = ['Member', 'Seller']; // Stronger type
  String? role; // Made nullable to reflect initial no selection

  String? selectedMemberUid; // The UID of the selected overseer
  String? selectedProvince;
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

  String? selectedDistrictElder;
  String? selectedCommunityElder;
  String? selectedCommunityName;
  Map<String, dynamic>? selectedDistrictData;
  Map<String, dynamic>? currentOverseerData;

  @override
  void initState() {
    super.initState();
    _getAddress();
  }

  @override
  void dispose() {
    txtEmail.dispose();
    txtName.dispose();
    txtSurname.dispose();
    txtAddress.dispose();
    txtContactNumber.dispose();
    txtPassword.dispose();
    txtConfirmPassword.dispose();
    super.dispose();
  }

  Future<void> _getAddress() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          Api().showMessage(
            context,
            'Location Permission Denied',
            'Please grant location permission to auto-fill address.',
            Colors.orange,
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        String fullAddress =
            "${p.street}, ${p.subLocality}, ${p.locality}, ${p.administrativeArea}";
        txtAddress.text = fullAddress;
      } else {
        txtAddress.text = "Address not found";
      }
    } catch (e) {
      Api().showMessage(
        context,
        'Location Error',
        'Could not get address: ${e.toString()}',
        Colors.red,
      );
      txtAddress.text = "Error getting address";
    }
  }

  List<String> getDistrictElderNames(Map<String, dynamic>? data) {
    if (data == null ||
        !data.containsKey('districts') ||
        data['districts'] == null) {
      return [];
    }
    return (data['districts'] as List<dynamic>)
        .map((district) => district['districtElderName'] as String?)
        .where((name) => name != null)
        .cast<String>()
        .toSet()
        .toList();
  }

  List<String> getCommunityElderNamesForDistrict(
    Map<String, dynamic>? districtData,
  ) {
    if (districtData == null ||
        !districtData.containsKey('communities') ||
        districtData['communities'] == null) {
      return [];
    }
    return (districtData['communities'] as List<dynamic>)
        .map((community) => community['communityElderName'] as String?)
        .where((name) => name != null)
        .cast<String>()
        .toSet()
        .toList();
  }

  List<String> getCommunityNamesForDistrict(
    Map<String, dynamic>? districtData,
  ) {
    if (districtData == null ||
        !districtData.containsKey('communities') ||
        districtData['communities'] == null) {
      return [];
    }
    return (districtData['communities'] as List<dynamic>)
        .map((community) => community['communityName'] as String?)
        .where((name) => name != null)
        .cast<String>()
        .toSet()
        .toList();
  }

  Future<void> _fetchOverseerData(String uid) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: uid)
          .get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          currentOverseerData = snapshot.docs.first.data();
          selectedDistrictElder = null;
          selectedCommunityElder = null;
          selectedCommunityName = null;
          selectedDistrictData = null;
        });
      } else {
        setState(() {
          currentOverseerData = null;
        });
        Api().showMessage(
          context,
          'Error',
          'Overseer data not found.',
          Colors.red,
        );
      }
    } catch (e) {
      Api().showMessage(
        context,
        'Error',
        'Error fetching overseer data: $e',
        Colors.red,
      );
      setState(() {
        currentOverseerData = null;
      });
    }
  }

  // Manual validation function
  bool _validateFields() {
    if (txtName.text.trim().isEmpty ||
        txtSurname.text.trim().isEmpty ||
        txtAddress.text.trim().isEmpty ||
        txtContactNumber.text.trim().isEmpty) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please fill in all personal details.',
        Colors.red,
      );
      return false;
    }
    if (role == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select a role.',
        Colors.red,
      );
      return false;
    }
    if (selectedProvince == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select your province.',
        Colors.red,
      );
      return false;
    }
    if (selectedMemberUid == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select an overseer.',
        Colors.red,
      );
      return false;
    }
    if (selectedDistrictElder == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select a district elder.',
        Colors.red,
      );
      return false;
    }
    if (selectedCommunityElder == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select a community elder.',
        Colors.red,
      );
      return false;
    }
    if (selectedCommunityName == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select a community name.',
        Colors.red,
      );
      return false;
    }

    // Basic email format check
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(txtEmail.text.trim())) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please enter a valid email address.',
        Colors.red,
      );
      return false;
    }

    if (txtPassword.text.isEmpty || txtConfirmPassword.text.isEmpty) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please enter and confirm your password.',
        Colors.red,
      );
      return false;
    }
    if (txtPassword.text != txtConfirmPassword.text) {
      Api().showMessage(
        context,
        'Validation Error',
        'Passwords do not match.',
        Colors.red,
      );
      return false;
    }
    if (txtPassword.text.length < 6) {
      Api().showMessage(
        context,
        'Validation Error',
        'Password must be at least 6 characters long.',
        Colors.red,
      );
      return false;
    }

    if (!isChecked) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please agree to the Terms and Conditions and Privacy Policy.',
        Colors.red,
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    String emailFromArgs = args['email'] ?? '';
    final colorScheme = Theme.of(context);

    final List<String> districtElderNames = getDistrictElderNames(
      currentOverseerData,
    );
    final List<String> communityElderNames = getCommunityElderNamesForDistrict(
      selectedDistrictData,
    );
    final List<String> communityNames = getCommunityNamesForDistrict(
      selectedDistrictData,
    );

    return Scaffold(
      backgroundColor:
          colorScheme.scaffoldBackgroundColor, // Ensure background color
      appBar: CupertinoNavigationBar(
        backgroundColor: colorScheme.scaffoldBackgroundColor,
        border: Border.all(color: Colors.transparent), // No border
        leading: CupertinoNavigationBarBackButton(
          color: colorScheme.primaryColor, // Use primary color for back button
          onPressed: () => Navigator.pop(context),
        ),
        // No title needed if back button is the primary element
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sign up",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Create an account to get started",
                style: TextStyle(color: colorScheme.hintColor, fontSize: 16),
              ),
              const SizedBox(height: 20),

              // Personal Details
              _buildCupertinoTextField(
                controller: txtName,
                placeholder: 'Name',
                prefixIcon: CupertinoIcons.person_fill,
                keyboardType: TextInputType.name,
              ),
              _buildCupertinoTextField(
                controller: txtSurname,
                placeholder: 'Surname',
                prefixIcon: CupertinoIcons.person_add,
                keyboardType: TextInputType.name,
              ),
              _buildCupertinoTextField(
                controller: txtAddress,
                placeholder: 'Address',
                prefixIcon: CupertinoIcons.location_solid,
                keyboardType: TextInputType.streetAddress,
                maxLines: 3,
              ),
              _buildCupertinoTextField(
                controller: txtContactNumber,
                placeholder: 'Contact Number',
                prefixIcon: CupertinoIcons.phone_fill,
                keyboardType: TextInputType.phone,
                suffixIcon: null,
              ),

              // Role Selection
              const SizedBox(height: 10),
              CupertinoFormSection(
                backgroundColor:
                    Colors.transparent, // Match scaffold background
                header: const Text('ROLE SELECTION'),
                children: [
                  CupertinoListTile(
                    title: const Text('Select Role'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(role ?? 'Not Selected'),
                        const Icon(CupertinoIcons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => CupertinoActionSheet(
                          title: const Text('Select Role'),
                          actions: roles.map((userRole) {
                            return CupertinoActionSheetAction(
                              child: Text(userRole),
                              onPressed: () {
                                setState(() {
                                  role = userRole;
                                });
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
                    },
                  ),
                ],
              ),

              // Province Selection
              const SizedBox(height: 10),
              CupertinoFormSection(
                backgroundColor: Colors.transparent,
                header: const Text('LOCATION DETAILS'),
                children: [
                  CupertinoListTile(
                    title: const Text('Select Province'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(selectedProvince ?? 'Not Selected'),
                        const Icon(CupertinoIcons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => CupertinoActionSheet(
                          title: const Text('Select your Province'),
                          actions: provinces.map((province) {
                            return CupertinoActionSheetAction(
                              child: Text(province),
                              onPressed: () {
                                setState(() {
                                  selectedProvince = province;
                                  selectedMemberUid = null;
                                  currentOverseerData = null;
                                  selectedDistrictElder = null;
                                  selectedCommunityElder = null;
                                  selectedCommunityName = null;
                                  selectedDistrictData = null;
                                });
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
                    },
                  ),

                  // Overseer Selection (Conditionally displayed)
                  if (selectedProvince != null)
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('overseers')
                          .where('province', isEqualTo: selectedProvince)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text('');
                        }
                        if (snapshot.hasError) {
                          return CupertinoListTile(
                            title: Text('Error: ${snapshot.error}'),
                            trailing: const Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                            ),
                          );
                        }
                        final overseers = snapshot.data?.docs ?? [];
                        if (overseers.isEmpty) {
                          return const CupertinoListTile(
                            title: Text('No Overseers found in this province.'),
                          );
                        }

                        return CupertinoListTile(
                          title: const Text('Select Overseer'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (() {
                                  if (selectedMemberUid == null) {
                                    return 'Select Overseer';
                                  }
                                  final overseerDoc = overseers
                                      .cast<QueryDocumentSnapshot>()
                                      .where(
                                        (o) => o['uid'] == selectedMemberUid,
                                      )
                                      .toList();
                                  if (overseerDoc.isEmpty) {
                                    return 'Select Overseer';
                                  }
                                  final overseer =
                                      overseerDoc.first.data()
                                          as Map<String, dynamic>;
                                  return '${overseer['name']} ${overseer['surname']}';
                                })(),
                              ),
                              const Icon(CupertinoIcons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (BuildContext context) =>
                                  CupertinoActionSheet(
                                    title: const Text('Choose an Overseer'),
                                    actions: overseers.map((overseerDoc) {
                                      final overseer =
                                          (overseerDoc as QueryDocumentSnapshot)
                                                  .data()
                                              as Map<String, dynamic>;
                                      return CupertinoActionSheetAction(
                                        child: Text(
                                          '${overseer['name']} ${overseer['surname']}',
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            selectedMemberUid = overseer['uid'];
                                            _fetchOverseerData(
                                              selectedMemberUid!,
                                            );
                                          });
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
                          },
                        );
                      },
                    ),

                  // District Elder Selection (Conditionally displayed)
                  if (currentOverseerData != null)
                    CupertinoListTile(
                      title: const Text('Select District Elder'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(selectedDistrictElder ?? 'Not Selected'),
                          const Icon(CupertinoIcons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        if (districtElderNames.isEmpty) {
                          Api().showMessage(
                            context,
                            'No Districts',
                            'No district elders found for the selected overseer.',
                            Colors.orange,
                          );
                          return;
                        }
                        showCupertinoModalPopup(
                          context: context,
                          builder: (BuildContext context) => CupertinoActionSheet(
                            title: const Text('Choose a District Elder'),
                            actions: districtElderNames.map((elderName) {
                              return CupertinoActionSheetAction(
                                child: Text(elderName),
                                onPressed: () {
                                  setState(() {
                                    selectedDistrictElder = elderName;
                                    selectedDistrictData =
                                        (currentOverseerData?['districts']
                                                    as List<dynamic>?)
                                                ?.firstWhere(
                                                  (district) =>
                                                      district['districtElderName'] ==
                                                      elderName,
                                                  orElse: () => null,
                                                )
                                            as Map<String, dynamic>?;
                                    selectedCommunityElder = null;
                                    selectedCommunityName = null;
                                  });
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
                      },
                    ),

                  // Community Elder Selection (Conditionally displayed)
                  if (selectedDistrictElder != null)
                    CupertinoListTile(
                      title: const Text('Select Community Elder'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(selectedCommunityElder ?? 'Not Selected'),
                          const Icon(CupertinoIcons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        if (communityElderNames.isEmpty) {
                          Api().showMessage(
                            context,
                            'No Communities',
                            'No community elders found for this district.',
                            Colors.orange,
                          );
                          return;
                        }
                        showCupertinoModalPopup(
                          context: context,
                          builder: (BuildContext context) =>
                              CupertinoActionSheet(
                                title: const Text('Choose a Community Elder'),
                                actions: communityElderNames.map((elderName) {
                                  return CupertinoActionSheetAction(
                                    child: Text(elderName),
                                    onPressed: () {
                                      setState(() {
                                        selectedCommunityElder = elderName;
                                      });
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
                      },
                    ),

                  // Community Name Selection (Conditionally displayed)
                  if (selectedCommunityElder != null)
                    CupertinoListTile(
                      title: const Text('Select Community Name'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(selectedCommunityName ?? 'Not Selected'),
                          const Icon(CupertinoIcons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        if (communityNames.isEmpty) {
                          Api().showMessage(
                            context,
                            'No Communities',
                            'No community names found for this district.',
                            Colors.orange,
                          );
                          return;
                        }
                        showCupertinoModalPopup(
                          context: context,
                          builder: (BuildContext context) =>
                              CupertinoActionSheet(
                                title: const Text('Choose a Community Name'),
                                actions: communityNames.map((community) {
                                  return CupertinoActionSheetAction(
                                    child: Text(community),
                                    onPressed: () {
                                      setState(() {
                                        selectedCommunityName = community;
                                      });
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
                      },
                    ),
                ],
              ),

              // Email and Password Fields
              const SizedBox(height: 10),
              CupertinoFormSection(
                backgroundColor: Colors.transparent,
                header: const Text('ACCOUNT CREDENTIALS'),
                children: [
                  if (emailFromArgs.isEmpty)
                    _buildCupertinoTextField(
                      controller: txtEmail,
                      placeholder: 'Email Address',
                      prefixIcon: CupertinoIcons.mail_solid,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  if (emailFromArgs.isEmpty)
                    _buildCupertinoTextField(
                      controller: txtPassword,
                      placeholder: 'Password',
                      prefixIcon: CupertinoIcons.lock_fill,
                      obscureText: _obscurePassword,
                      suffixIcon: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        child: Icon(
                          _obscurePassword
                              ? CupertinoIcons.eye_slash_fill
                              : CupertinoIcons.eye_fill,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  if (emailFromArgs.isEmpty)
                    _buildCupertinoTextField(
                      controller: txtConfirmPassword,
                      placeholder: 'Confirm Password',
                      prefixIcon: CupertinoIcons.lock_fill,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        child: Icon(
                          _obscureConfirmPassword
                              ? CupertinoIcons.eye_slash_fill
                              : CupertinoIcons.eye_fill,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CupertinoCheckbox(
                    // Cupertino checkbox
                    value: isChecked,
                    onChanged: (val) => setState(() => isChecked = val!),
                    activeColor: colorScheme.primaryColor,
                    checkColor: colorScheme.scaffoldBackgroundColor,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: colorScheme.hintColor,
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(text: "I've read and agree with the "),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {
                                // Navigate to Terms and Conditions
                              },
                              child: Text(
                                "Terms and Conditions",
                                style: TextStyle(
                                  color: colorScheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: " and the "),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () {
                                // Navigate to Privacy Policy
                              },
                              child: Text(
                                "Privacy Policy.",
                                style: TextStyle(
                                  color: colorScheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomOutlinedButton(
                width: double.infinity,
                backgroundColor: colorScheme.primaryColor,
                foregroundColor: colorScheme.scaffoldBackgroundColor,
                text: 'SIGN UP',
                onPressed: () async {
                  // Perform all validations manually
                  if (!_validateFields()) {
                    return; // Stop if any validation fails
                  }

                  // All fields are valid, proceed with sign-up
                  try {
                    if (emailFromArgs.isEmpty) {
                      await backendService.signUp(
                        // Use the backendService instance
                        txtName.text.trim(),
                        txtSurname.text.trim(),
                        txtEmail.text.trim(),
                        txtPassword.text,
                        txtAddress.text.trim(),
                        txtContactNumber.text.trim(),
                        selectedMemberUid!,
                        role!,
                        selectedProvince!,
                        selectedDistrictElder!,
                        selectedCommunityElder!,
                        selectedCommunityName!,
                        context,
                      );
                    } else {
                      // This part handles the case where email is pre-filled (e.g., from Google Sign-in)
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .set({
                            "name": txtName.text.trim(),
                            "surname": txtSurname.text.trim(),
                            "email": emailFromArgs, // Use email from args
                            "profileUrl": "",
                            "address": txtAddress.text.trim(),
                            "phone": txtContactNumber.text.trim(),
                            "overseerUid": selectedMemberUid,
                            'week1': 0.00,
                            'week2': 0.00,
                            'week3': 0.00,
                            'week4': 0.00,
                            "role": role,
                            "province": selectedProvince,
                            "districtElderName": selectedDistrictElder,
                            "communityElderName": selectedCommunityElder,
                            "communityName": selectedCommunityName,
                            "uid": FirebaseAuth
                                .instance
                                .currentUser!
                                .uid, // Ensure uid is stored
                          });
                      backendService.showMessage(
                        context,
                        'Success',
                        'Account details updated successfully!',
                        colorScheme.splashColor,
                      );

                      Navigator.pushNamed(context, '/main-menu');
                      // Example: go back after update
                    }
                  } catch (e) {
                    backendService.showMessage(
                      context,
                      'Sign Up/Update Failed',
                      e.toString(),
                      colorScheme.primaryColorDark
                    );
                  }
                },
              ),
              const SizedBox(height: 40),

              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Have an account?'),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Login here',
                      style: TextStyle(
                        color: colorScheme.primaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
