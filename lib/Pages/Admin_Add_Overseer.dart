import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

class AdminAddOverseer extends StatefulWidget {
  const AdminAddOverseer({super.key});

  @override
  State<AdminAddOverseer> createState() => _AdminAddOverseerState();
}

class _AdminAddOverseerState extends State<AdminAddOverseer> {
  final TextEditingController overseerNameController = TextEditingController();
  final TextEditingController overseerEmailController = TextEditingController();
  final TextEditingController overseerSurnameController =
      TextEditingController();
  final TextEditingController overseerPasswordController =
      TextEditingController();
  final TextEditingController overseerDistrictElderController =
      TextEditingController();
  final TextEditingController overseerCommunityNameController =
      TextEditingController();
  final TextEditingController overseerCommunityElderNameController =
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
    overseerNameController.dispose();
    overseerEmailController.dispose();
    overseerSurnameController.dispose();
    overseerPasswordController.dispose();
    overseerDistrictElderController.dispose();
    overseerCommunityNameController.dispose();
    overseerCommunityElderNameController.dispose();
    overseerAddressController.dispose();
    super.dispose();
  }

  Future<void> addOverseer() async {
    Api().showLoading(context);
    FirebaseAuth auth = FirebaseAuth.instance;

    if (overseerNameController.text.isEmpty ||
        overseerSurnameController.text.isEmpty ||
        overseerEmailController.text.isEmpty ||
        overseerPasswordController.text.isEmpty ||
        selectedProvince == null) {
      if (mounted) {
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Please fill in all fields',
          'Error',
          Theme.of(context).primaryColorDark,
        );
      }
      return;
    }

    try {
      var userCredential = await auth.createUserWithEmailAndPassword(
        email: overseerEmailController.text,
        password: overseerPasswordController.text,
      );

      if (!mounted) return;

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('overseers').add({
        'name': overseerNameController.text,
        'surname': overseerSurnameController.text,
        'email': overseerEmailController.text,
        'province': selectedProvince,
        'uid': userCredential.user?.uid,
        'role': 'overseer',
        'districts': districtCommunities.entries
            .map(
              (entry) => {
                'districtElderName': entry.key,
                'communities': entry.value,
              },
            )
            .toList(),
      });

      if (mounted) {
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Overseer added successfully',
          'Success',
          Theme.of(context).splashColor,
        );
        overseerNameController.clear();
        overseerSurnameController.clear();
        overseerEmailController.clear();
        overseerPasswordController.clear();
        overseerDistrictElderController.clear();
        overseerCommunityNameController.clear();
        overseerCommunityElderNameController.clear();
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
          'Failed to create overseer: $error',
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
      if (Platform.isIOS) {
        return CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: color.primaryColor),
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
              borderRadius: BorderRadius.circular(18.0),
            ),
            suffixIcon: suffix,
          ),
          style: style,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text(
            'Admin Add Overseer Page',
            style: TextStyle(fontSize: 24, color: color.primaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          platformTextField(
            controller: overseerNameController,
            placeholder: 'Enter Overseer Name',
          ),
          const SizedBox(height: 10),
          platformTextField(
            controller: overseerSurnameController,
            placeholder: 'Enter Overseer Surname',
          ),
          const SizedBox(height: 10),
          platformTextField(
            controller: overseerEmailController,
            placeholder: 'Enter Overseer Email',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: platformTextField(
                  controller: overseerDistrictElderController,
                  placeholder: 'Enter DISTRICT ELDER NAME',
                  padding: const EdgeInsets.all(16.0),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: CustomOutlinedButton(
                  onPressed: () {
                    String districtElderName = overseerDistrictElderController
                        .text
                        .trim();
                    if (districtElderName.isEmpty) {
                      Api().showMessage(
                        context,
                        'District Elder Name cannot be empty',
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
                  backgroundColor: color.scaffoldBackgroundColor,
                  foregroundColor: color.primaryColor,
                  width: double.infinity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
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
                              Icons.delete,
                              color: color.primaryColorDark,
                            ),
                            onPressed: () {
                              setState(() {
                                districtCommunities.remove(districtElderName);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Communities in this District:',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (communitiesInThisDistrict.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0),
                          child: Text(
                            'No communities added yet for this district.',
                          ),
                        ),
                      ...communitiesInThisDistrict.map(
                        (communityMap) => Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Community: ${communityMap['communityName']} (Elder: ${communityMap['communityElderName']})',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
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
                      ),
                      const SizedBox(height: 8.0),
                      platformTextField(
                        controller: overseerCommunityNameController,
                        placeholder: 'Enter Community Name (Where)',
                        padding: const EdgeInsets.all(12.0),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: platformTextField(
                              controller: overseerCommunityElderNameController,
                              placeholder: 'Enter Community Elder Name (Who)',
                              padding: const EdgeInsets.all(12.0),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: CustomOutlinedButton(
                              width: double.infinity,
                              onPressed: () {
                                String communityName =
                                    overseerCommunityNameController.text.trim();
                                String communityElderName =
                                    overseerCommunityElderNameController.text
                                        .trim();

                                if (communityName.isEmpty ||
                                    communityElderName.isEmpty) {
                                  Api().showMessage(
                                    context,
                                    'Community Name and Elder Name cannot be empty',
                                    'Error',
                                    color.primaryColorDark,
                                  );
                                  return;
                                }

                                setState(() {
                                  districtCommunities[districtElderName]?.add({
                                    'communityName': communityName,
                                    'communityElderName': communityElderName,
                                  });
                                  overseerCommunityNameController.clear();
                                  overseerCommunityElderNameController.clear();
                                });
                              },
                              text: 'Add Community',
                              backgroundColor: color.scaffoldBackgroundColor,
                              foregroundColor: color.primaryColor,
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
          const SizedBox(height: 10),
          platformTextField(
            controller: overseerPasswordController,
            placeholder: 'Enter Overseer Password',
            obscureText: !isPasswordVisible,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  isPasswordVisible = !isPasswordVisible;
                });
              },
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Overseer Province',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18.0),
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
          const SizedBox(height: 20),
          CustomOutlinedButton(
            onPressed: addOverseer,
            text: 'Add Overseer',
            backgroundColor: color.primaryColor,
            foregroundColor: color.scaffoldBackgroundColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
