// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print

// --- PLATFORM IMPORTS FIX ---
// Import dart:io conditionally to enable cross-platform build
import 'dart:io' if (dart.library.html) 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb and defaultTargetPlatform

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ttact/Components/AdBanner.dart';

import '../Components/CustomOutlinedButton.dart';
import '../Components/API.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
bool get isAndroidPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
// --------------------------

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
    // FIX: Use isIOSPlatform getter
    child: isIOSPlatform
        ? CupertinoTextField(
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
}) {
  // FIX: Use isIOSPlatform getter
  if (isIOSPlatform) {
    return CupertinoListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText),
          const Icon(CupertinoIcons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  } else {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText),
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
  // FIX: Use isIOSPlatform getter
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
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
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
  TextEditingController txtAccountNumber = TextEditingController();
  TextEditingController txtBankCodeController = TextEditingController();

  TextEditingController txtPassword = TextEditingController();
  TextEditingController txtConfirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool isChecked = false;
  Api backendService = Api();
  List<String> roles = ['Member', 'Seller'];
  String? role;

  String? selectedMemberUid;
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
  String? selectedCommunityName;
  Map<String, dynamic>? selectedDistrictData;
  Map<String, dynamic>? currentOverseerData;
  AdManager adManager = AdManager();

  @override
  void initState() {
    super.initState();
    adManager.loadRewardedInterstitialAd();
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
    // Skip Geolocation on Web as it requires permissions that crash the app in some environments,
    // and is generally handled differently.
    if (kIsWeb) {
      txtAddress.text = "Enter Address Manually (Web)";
      return;
    }

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
            "${p.street},  ${p.locality}, ${p.administrativeArea}";
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
    
    if (selectedCommunityName == null) {
      Api().showMessage(
        context,
        'Validation Error',
        'Please select a community name.',
        Colors.red,
      );
      return false;
    }

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

  String YOUR_BACKEND_BASE_URL =
      'https://us-central1-tact-3c612.cloudfunctions.net/api';

  Future<String?> createSellerSubaccount({
    required String uid,
    required String businessName,
    required String email,
    required String accountNumber,
    required String bankCode,
  }) async {
    final url = Uri.parse('$YOUR_BACKEND_BASE_URL/create_seller_subaccount');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "uid": uid,
        "business_name": businessName,
        "bank_code": bankCode,
        "account_number": accountNumber,
        "contact_email": email,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['subaccount_code'];
    } else {
      print('Error creating subaccount: ${response.body}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    String emailFromArgs = args['email'] ?? '';
    final colorScheme = Theme.of(context);
    final isDesktop =
        MediaQuery.of(context).size.width > 800; // Define desktop breakpoint

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
      backgroundColor: colorScheme.scaffoldBackgroundColor,
      // FIX: Use isIOSPlatform getter
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
              backgroundColor: colorScheme.scaffoldBackgroundColor,
              border: Border.all(color: Colors.transparent),
              leading: CupertinoNavigationBarBackButton(
                color: colorScheme.primaryColor,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : AppBar(
              backgroundColor: colorScheme.scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: colorScheme.primaryColor,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: Container(
            // Constrain content width for desktop/web
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 600 : double.infinity,
            ),
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
                    style: TextStyle(
                      color: colorScheme.hintColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personal Details
                  _buildPlatformTextField(
                    context: context,
                    controller: txtName,
                    placeholder: 'Name',
                    prefixIcon: CupertinoIcons.person_fill,
                    keyboardType: TextInputType.name,
                  ),
                  _buildPlatformTextField(
                    context: context,
                    controller: txtSurname,
                    placeholder: 'Surname',
                    prefixIcon: CupertinoIcons.person_add,
                    keyboardType: TextInputType.name,
                  ),
                  _buildPlatformTextField(
                    context: context,
                    controller: txtAddress,
                    placeholder: 'Address',
                    prefixIcon: CupertinoIcons.location_solid,
                    keyboardType: TextInputType.streetAddress,
                    maxLines: 3,
                  ),
                  _buildPlatformTextField(
                    context: context,
                    controller: txtContactNumber,
                    placeholder: 'Contact Number',
                    prefixIcon: CupertinoIcons.phone_fill,
                    keyboardType: TextInputType.phone,
                  ),

                  // Role Selection
                  const SizedBox(height: 10),
                  _buildSection(
                    context: context,
                    title: 'ROLE SELECTION',
                    children: [
                      _buildListTile(
                        context: context,
                        title: 'Select Role',
                        trailingText: role ?? 'Not Selected',
                        onTap: () {
                          _buildActionSheet(
                            context: context,
                            title: 'Select Role',
                            actions: roles,
                            onSelected: (userRole) {
                              setState(() {
                                role = userRole;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  if (role == 'Seller') ...[
                    const SizedBox(height: 10),
                    _buildPlatformTextField(
                      context: context,
                      controller: txtAccountNumber,
                      placeholder: 'Bank Account Number',
                      prefixIcon: CupertinoIcons.money_dollar,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _buildPlatformTextField(
                      context: context,
                      controller: txtBankCodeController,
                      placeholder: 'Bank Code',
                      prefixIcon: CupertinoIcons.building_2_fill,
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  // Province Selection
                  const SizedBox(height: 10),
                  _buildSection(
                    context: context,
                    title: 'LOCATION DETAILS',
                    children: [
                      _buildListTile(
                        context: context,
                        title: 'Select Province',
                        trailingText: selectedProvince ?? 'Not Selected',
                        onTap: () {
                          _buildActionSheet(
                            context: context,
                            title: 'Select your Province',
                            actions: provinces,
                            onSelected: (province) {
                              setState(() {
                                selectedProvince = province;
                                selectedMemberUid = null;
                                currentOverseerData = null;
                                selectedDistrictElder = null; 
                                selectedCommunityName = null;
                                selectedDistrictData = null;
                              });
                            },
                          );
                        },
                      ),

                      if (selectedProvince != null)
                        FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('overseers')
                              .where('province', isEqualTo: selectedProvince)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              // FIX: Use platform-aware loading indicator
                              return Center(
                                child: isIOSPlatform
                                    ? const CupertinoActivityIndicator()
                                    : const CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return _buildListTile(
                                context: context,
                                title: 'Error: ${snapshot.error}',
                                trailingText: '!',
                                onTap: () {},
                              );
                            }
                            final overseers = snapshot.data?.docs ?? [];
                            if (overseers.isEmpty) {
                              return _buildListTile(
                                context: context,
                                title: 'No Overseers found.',
                                trailingText: '',
                                onTap: () {},
                              );
                            }

                            return _buildListTile(
                              context: context,
                              title: 'Select Overseer',
                              trailingText: (() {
                                if (selectedMemberUid == null) {
                                  return 'Not Selected';
                                }
                                final overseerDoc = overseers
                                    .cast<QueryDocumentSnapshot>()
                                    .firstWhere(
                                      (o) => o['uid'] == selectedMemberUid,
                                      orElse: () =>
                                          null as QueryDocumentSnapshot,
                                    );
                                if (overseerDoc == null) {
                                  return 'Not Selected';
                                }
                                final overseer =
                                    overseerDoc.data() as Map<String, dynamic>;
                                return '${overseer['name']} ${overseer['surname']}';
                              })(),
                              onTap: () {
                                _buildActionSheet(
                                  context: context,
                                  title: 'Choose an Overseer',
                                  actions: overseers.map((overseerDoc) {
                                    final overseer =
                                        (overseerDoc).data()
                                            as Map<String, dynamic>;
                                    return '${overseer['name']} ${overseer['surname']}';
                                  }).toList(),
                                  onSelected: (selectedName) {
                                    final selectedDoc = overseers.firstWhere(
                                      (doc) =>
                                          '${doc['name']} ${doc['surname']}' ==
                                          selectedName,
                                    );
                                    setState(() {
                                      selectedMemberUid = selectedDoc['uid'];
                                      _fetchOverseerData(selectedMemberUid!);
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),

                      if (currentOverseerData != null)
                        _buildListTile(
                          context: context,
                          title: 'Select District Elder',
                          trailingText: selectedDistrictElder ?? 'Not Selected',
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
                            _buildActionSheet(
                              context: context,
                              title: 'Choose a District Elder',
                              actions: districtElderNames,
                              onSelected: (elderName) {
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
                                  selectedCommunityName = null;
                                });
                              },
                            );
                          },
                        ),
 
                     ],
                  ),

                  // Email and Password Fields
                  const SizedBox(height: 10),
                  _buildSection(
                    context: context,
                    title: 'ACCOUNT CREDENTIALS',
                    children: [
                      if (emailFromArgs.isEmpty)
                        _buildPlatformTextField(
                          context: context,
                          controller: txtEmail,
                          placeholder: 'Email Address',
                          prefixIcon: CupertinoIcons.mail_solid,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      if (emailFromArgs.isEmpty)
                        _buildPlatformTextField(
                          context: context,
                          controller: txtPassword,
                          placeholder: 'Password',
                          prefixIcon: CupertinoIcons.lock_fill,
                          obscureText: _obscurePassword,
                          // FIX: Use isIOSPlatform getter
                          suffixIcon: isIOSPlatform
                              ? CupertinoButton(
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
                                )
                              : IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                        ),
                      if (emailFromArgs.isEmpty)
                        _buildPlatformTextField(
                          context: context,
                          controller: txtConfirmPassword,
                          placeholder: 'Confirm Password',
                          prefixIcon: CupertinoIcons.lock_fill,
                          obscureText: _obscureConfirmPassword,
                          // FIX: Use isIOSPlatform getter
                          suffixIcon: isIOSPlatform
                              ? CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  child: Icon(
                                    _obscureConfirmPassword
                                        ? CupertinoIcons.eye_slash_fill
                                        : CupertinoIcons.eye_fill,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 15),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // FIX: Use isIOSPlatform getter
                      isIOSPlatform
                          ? CupertinoCheckbox(
                              value: isChecked,
                              onChanged: (val) =>
                                  setState(() => isChecked = val!),
                              activeColor: colorScheme.primaryColor,
                              checkColor: colorScheme.scaffoldBackgroundColor,
                            )
                          : Checkbox(
                              value: isChecked,
                              onChanged: (val) =>
                                  setState(() => isChecked = val!),
                              activeColor: colorScheme.primaryColor,
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
                              const TextSpan(
                                text: "I've read and agree with the ",
                              ),
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
                      Api().showLoading(context);
                      await _getAddress();
                      if (!_validateFields()) {
                        if (context.mounted)
                          Navigator.pop(context); // Dismiss loading
                        return;
                      }

                      try {
                        if (emailFromArgs.isEmpty) {
                          await backendService.signUp(
                            txtName.text.trim(),
                            txtSurname.text.trim(),
                            txtEmail.text.trim(),
                            txtPassword.text,
                            txtAddress.text.trim(),
                            txtContactNumber.text.trim(),
                            selectedMemberUid!,
                            role!,
                            accountNumber: txtAccountNumber.text.trim(),
                            bankCode: txtBankCodeController.text.trim(),
                            selectedProvince!,
                            selectedDistrictElder!, 
                            selectedCommunityName!,
                            context,
                          );
                        } else {
                          // This branch is for users signing in via social auth (already signed up with Firebase)
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .set(
                                {
                                  "name": txtName.text.trim(),
                                  "surname": txtSurname.text.trim(),
                                  "email": emailFromArgs,
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
                                  if (role == 'Seller')
                                    'sellerPaystackAccount': '',
                                  "uid": FirebaseAuth.instance.currentUser!.uid,
                                  "communityName":
                                      selectedCommunityName, // Added missing communityName
                                },
                                SetOptions(merge: true),
                              ); // Use merge true for social users

                          if (role == 'Seller') {
                            String?
                            subaccountCode = await createSellerSubaccount(
                              uid: FirebaseAuth.instance.currentUser!.uid,
                              businessName:
                                  "${txtName.text.trim()} ${txtSurname.text.trim()}",
                              email: emailFromArgs,
                              accountNumber: txtAccountNumber.text.trim(),
                              bankCode: txtBankCodeController.text.trim(),
                            );

                            if (subaccountCode != null && context.mounted) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(FirebaseAuth.instance.currentUser!.uid)
                                  .update({
                                    'sellerPaystackAccount': subaccountCode,
                                  });
                            } else if (context.mounted) {
                              print('Failed to create Paystack subaccount');
                            }
                          }

                          if (context.mounted) {
                            Navigator.pop(context); // Dismiss loading
                            backendService.showMessage(
                              context,
                              'Success',
                              'Account details updated successfully!',
                              colorScheme.splashColor,
                            );
                            // Only show ad on Android, handled safely in AdBanner.dart
                            if (isAndroidPlatform) {
                              adManager.showRewardedInterstitialAd((
                                ad,
                                reward,
                              ) {
                                print(
                                  'User earned reward: ${reward.amount} ${reward.type}',
                                );
                              });
                            }
                            Navigator.pushNamed(context, '/main-menu');
                          }
                        }
                      } catch (e) {
                        if (context.mounted)
                          Navigator.pop(context); // Dismiss loading
                        backendService.showMessage(
                          context,
                          'Sign Up/Update Failed',
                          e.toString(),
                          colorScheme.primaryColorDark,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),

                  const SizedBox(height: 10),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A custom builder to handle the platform-specific form sections
Widget _buildSection({
  required BuildContext context,
  required String title,
  required List<Widget> children,
}) {
  // FIX: Use isIOSPlatform getter
  if (isIOSPlatform) {
    return CupertinoFormSection(
      backgroundColor: Colors.transparent,
      header: Text(title),
      children: children,
    );
  } else {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
