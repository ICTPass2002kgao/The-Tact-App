// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print, unnecessary_null_comparison

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:flutter/foundation.dart'; // Import for kIsWeb

// --- PLATFORM UTILITIES ---
// Determine if we should use Cupertino style (iOS/macOS, or forced Material on Web/Android)
bool get _useCupertinoStyle =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
const double _desktopContentMaxWidth = 700.0;
// --------------------------

class AdminAddOverseer extends StatefulWidget {
  const AdminAddOverseer({super.key});

  @override
  State<AdminAddOverseer> createState() => _AdminAddOverseerState();
}

class _AdminAddOverseerState extends State<AdminAddOverseer> {
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

  final TextEditingController overseerAddressController =
      TextEditingController();
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

  Map<String, List<Map<String, String>>> districtCommunities = {};

  @override
  void dispose() {
    overseerEmailController.dispose();
    overseerInitialsAndSurname.dispose();
    overseerPasswordController.dispose();
    overseerDistrictElderController.dispose();
    overseerCommunityNameController.dispose();

    overseerAddressController.dispose();
    super.dispose();
  }

  Future<void> addOverseer() async {
    Api().showLoading(context);
    FirebaseAuth auth = FirebaseAuth.instance;

    if (overseerInitialsAndSurname.text.isEmpty ||
        overseerEmailController.text.isEmpty ||
        overseerPasswordController.text.isEmpty ||
        selectedProvince == null ||
        districtCommunities.isEmpty) // Check if at least one district is added
    {
      if (mounted) {
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Please fill in all fields (including at least one District/Community).',
          'Error',
          Theme.of(context).primaryColorDark,
        );
      }
      return;
    }

    try {
      // 1. Create Firebase Auth User
      var userCredential = await auth.createUserWithEmailAndPassword(
        email: overseerEmailController.text,
        password: overseerPasswordController.text,
      );

      if (!mounted) {
        // If mounting fails after successful user creation, delete the user.
        await userCredential.user?.delete();
        return;
      }

      // 2. Create Overseer Document in Firestore
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // --- FIX: Correctly structure the districts array for Firestore ---
      final List<Map<String, dynamic>> structuredDistricts =
          districtCommunities.entries
              .map(
                (entry) => {
                  'districtElderName': entry.key, // <-- ADDED DISTRICT NAME
                  'communities': entry.value,
                },
              )
              .toList();
      // -------------------------------------------------------------------

      await firestore.collection('overseers').add({
        'overseerInitialsAndSurname': overseerInitialsAndSurname.text,
        'email': overseerEmailController.text,
        'province': selectedProvince,
        'uid': userCredential.user?.uid,
        'role': 'overseer',

        // ADD SUBSCRIPTION/MEMBER FIELDS:
        'subscriptionStatus': 'inactive',
        'paystackAuthCode': null,
        'paystackEmail': null,
        
        // --- USING THE CORRECTLY STRUCTURED LIST ---
        'districts': structuredDistricts,
      });

      if (mounted) {
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Overseer added successfully',
          'Success',
          Theme.of(context).splashColor,
        );
        overseerInitialsAndSurname.clear();
        overseerEmailController.clear();
        overseerPasswordController.clear();
        overseerDistrictElderController.clear();
        overseerCommunityNameController.clear();
        selectedProvince = null;
        setState(() {
          isPasswordVisible = false;
          districtCommunities.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Failed to create overseer: ${error.toString().split('] ').last}', // Clean up FirebaseAuth errors
          'Error',
          Theme.of(context).primaryColorDark,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData color = Theme.of(context);

    // Helper widget to conditionally render a text field based on platform
    Widget platformTextField({
      required TextEditingController controller,
      required String placeholder,
      bool obscureText = false,
      Widget? suffix,
      TextStyle? style,
      EdgeInsets padding = const EdgeInsets.all(16.0),
    }) {
      // FIX: Use platform check _useCupertinoStyle
      if (_useCupertinoStyle) {
        return CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              10.0,
            ), // Smaller radius for form
            border: Border.all(color: color.primaryColor.withOpacity(0.5)),
          ),
          padding: padding,
          style: style,
          suffix: suffix,
        );
      } else {
        return TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelStyle: TextStyle(fontSize: 12),
            labelText: placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                10.0,
              ), // Smaller radius for form
            ),
            suffixIcon: suffix,
          ),
          style: style,
        );
      }
    }

    return Center(
      // FIX 2: Constrain form width for desktop/web
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
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

              // --- Personal Details ---
              Card(
                elevation: 4,
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      platformTextField(
                        controller: overseerInitialsAndSurname,
                        placeholder: 'Initials and Surname',
                      ),
                      const SizedBox(height: 10),
                      platformTextField(
                        controller: overseerRegionController,
                        placeholder: 'Region',
                      ),
                      const SizedBox(height: 10),
                      platformTextField(
                        controller: overseerCodeController,
                        placeholder: 'Code',
                      ),
                      const SizedBox(height: 10),
                      platformTextField(
                        controller: overseerEmailController,
                        placeholder: 'Email Address',
                      ),
                      const SizedBox(height: 10),
                      platformTextField(
                        controller: overseerPasswordController,
                        placeholder: 'Password (min 6 chars)',
                        obscureText: !isPasswordVisible,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: color.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Province Dropdown
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Select Overseer Province',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          value: selectedProvince,
                          items: provinces.map((String province) {
                            return DropdownMenuItem<String>(
                              value: province,
                              child: Text(province),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedProvince = newValue;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Dynamic District and Community Structure ---
              Text(
                'Organization Structure',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color.primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              // 1. Add District Input
              Card(
                elevation: 4,
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New District Elder',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: platformTextField(
                              controller: overseerDistrictElderController,
                              placeholder: 'District Elder Name (e.g., Mkhize)',
                              padding: const EdgeInsets.all(12.0),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: CustomOutlinedButton(
                              onPressed: () {
                                String districtElderName =
                                    overseerDistrictElderController.text.trim();
                                if (districtElderName.isEmpty) {
                                  Api().showMessage(
                                    context,
                                    'Name cannot be empty',
                                    'Error',
                                    color.primaryColorDark,
                                  );
                                } else if (districtCommunities.containsKey(
                                  districtElderName,
                                )) {
                                  Api().showMessage(
                                    context,
                                    'District Elder already exists',
                                    'Error',
                                    color.primaryColorDark,
                                  );
                                } else {
                                  setState(() {
                                    districtCommunities.putIfAbsent(
                                      districtElderName,
                                      () => [],
                                    );
                                    overseerDistrictElderController.clear();
                                  });
                                }
                              },
                              text: 'Add District',
                              backgroundColor: color.primaryColor,
                              foregroundColor: color.scaffoldBackgroundColor,
                              width: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Display and Add Communities to Existing Districts
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: districtCommunities.keys.length,
                itemBuilder: (context, index) {
                  String districtElderName = districtCommunities.keys.elementAt(
                    index,
                  );
                  List<Map<String, String>> communitiesInThisDistrict =
                      districtCommunities[districtElderName] ?? [];

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
                                icon: Icon(
                                  Icons.delete_forever,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    districtCommunities.remove(
                                      districtElderName,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          Divider(color: color.dividerColor),

                          // List of Current Communities
                          if (communitiesInThisDistrict.isNotEmpty)
                            ...communitiesInThisDistrict.map(
                              (communityMap) => Padding(
                                padding: const EdgeInsets.only(
                                  left: 16.0,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Community: ${communityMap['communityName']}',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          districtCommunities[districtElderName]
                                              ?.remove(communityMap);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: EdgeInsets.only(left: 16.0, top: 8),
                              child: Text(
                                'No communities added yet.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: color.hintColor,
                                ),
                              ),
                            ),

                          Divider(height: 20),
                          Text(
                            'Add Community to $districtElderName:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 10),

                          // Community Name Input
                          platformTextField(
                            controller: overseerCommunityNameController,
                            placeholder: 'Community Name (e.g., Durban North)',
                            padding: const EdgeInsets.all(12.0),
                          ),
                          SizedBox(height: 8.0),

                          // Community Elder Input and Add Button
                          Row(
                            children: [
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: CustomOutlinedButton(
                                  width: double.infinity,
                                  onPressed: () {
                                    String communityName =
                                        overseerCommunityNameController.text
                                            .trim();

                                    if (communityName.isEmpty) {
                                      Api().showMessage(
                                        context,
                                        'Name fields required',
                                        'Error',
                                        color.primaryColorDark,
                                      );
                                      return;
                                    }

                                    setState(() {
                                      districtCommunities[districtElderName]
                                          ?.add({
                                            'communityName': communityName,
                                          });
                                      overseerCommunityNameController.clear();
                                    });
                                  },
                                  text: 'Add Community',
                                  backgroundColor: color.primaryColor,
                                  foregroundColor:
                                      color.scaffoldBackgroundColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // --- Final Submit Button ---
              CustomOutlinedButton(
                onPressed: addOverseer,
                text: 'Add Overseer',
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                width: double.infinity,
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}