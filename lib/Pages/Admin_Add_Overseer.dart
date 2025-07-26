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
      TextEditingController(); // For the Community's Name (Where)
  final TextEditingController overseerCommunityElderNameController =
      TextEditingController(); // For the Community Elder's Name (Who)

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

  // Updated: Map where values are a List of Maps for community details
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
    overseerAddressController.dispose(); // Don't forget to dispose this one too
    super.dispose();
  }

  Future<void> addOverseer() async {
    Api().showLoading(context);
    FirebaseAuth auth = FirebaseAuth.instance; // Directly use instance

    if (overseerNameController.text.isEmpty ||
        overseerSurnameController.text.isEmpty ||
        overseerEmailController.text.isEmpty ||
        overseerPasswordController.text.isEmpty ||
        selectedProvince == null) {
      if (mounted) {
        // Check if widget is still in tree before interacting with context
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

      if (!mounted) return; // Check again after async operation

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
        // Check again before popping and showing message
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Overseer added successfully',
          'Success',
          Theme.of(context).splashColor, // This should be safe
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
        // Check again before interacting with UI
        Navigator.pop(context);
        Api().showMessage(
          context,
          'Failed to create overseer: $error',
          'Error',
          Theme.of(context).primaryColorDark, // This should be safe
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure 'color' is always valid and available.
    // This is the primary way to get theme data.
    final ThemeData color = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Admin Add Overseer Page',
              style: TextStyle(
                fontSize: 24,
                color: color.primaryColor, // Use 'color' for theme access
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 10), // Added for consistency
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
            controller: overseerNameController,
            placeholder: 'Enter Overseer Name',
            padding: EdgeInsets.all(16.0),
            style: const TextStyle(fontSize: 18), // Using const if possible
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
            controller: overseerSurnameController,
            placeholder: 'Enter Overseer Surname',
            padding: EdgeInsets.all(16.0),
            style: const TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
            controller: overseerEmailController,
            placeholder: 'Enter Overseer Email',
            padding: EdgeInsets.all(16.0),
            style: const TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          // Input for adding District Elder
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CupertinoTextField(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18.0),
                      border: Border.all(color: color.primaryColor),
                    ),
                    controller: overseerDistrictElderController,
                    placeholder: 'Enter DISTRICT ELDER NAME',
                    padding: const EdgeInsets.all(16.0),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                Flexible(
                  child: CustomOutlinedButton(
                    width: 120,
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
                          // Ensure the list for this district is initialized
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
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          // Display District Elders and allow adding Communities
          ListView.builder(
            shrinkWrap: true,
            physics:
                NeverScrollableScrollPhysics(), // Disable scrolling for this list
            itemCount: districtCommunities.keys.length,
            itemBuilder: (context, index) {
              String districtElderName = districtCommunities.keys.elementAt(
                index,
              );
              // Safely get the list, default to empty list if key not found or value is null
              List<Map<String, String>> communitiesInThisDistrict =
                  districtCommunities[districtElderName] ?? [];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Align text to start
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'District: $districtElderName', // Label as District for clarity
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
                                // Access the list safely before attempting to remove
                                districtCommunities[districtElderName]?.remove(
                                  communitiesInThisDistrict[index],
                                ); // Use the actual map from the list
                                // Or, if removing the whole district if empty:
                                // districtCommunities.remove(districtElderName);
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Communities in this District:',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (communitiesInThisDistrict.isEmpty)
                        const Padding(
                          // Use const if possible
                          padding: EdgeInsets.only(left: 16.0),
                          child: Text(
                            'No communities added yet for this district.',
                          ),
                        ),
                      // Display each Community Name and its Elder
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
                              Flexible(
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      // Access the list safely before attempting to remove
                                      districtCommunities[districtElderName]
                                          ?.remove(communityMap);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8.0),
                      // Input fields for adding a new Community to this District
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: overseerCommunityNameController,
                        placeholder: 'Enter Community Name (Where)',
                        padding: const EdgeInsets.all(12.0),
                        style: const TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18.0),
                                border: Border.all(color: color.primaryColor),
                              ),
                              controller: overseerCommunityElderNameController,
                              placeholder: 'Enter Community Elder Name (Who)',
                              padding: const EdgeInsets.all(12.0),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          SizedBox(width: 8.0),
                          Flexible(
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
                                  return; // Important: Exit if validation fails
                                }

                                setState(() {
                                  // Safely get the list and add to it
                                  // We use putIfAbsent here just in case, though it should already exist
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
          SizedBox(height: 10),
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
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
            controller: overseerPasswordController,
            placeholder: 'Enter Overseer Password',
            padding: const EdgeInsets.all(16.0),
            obscureText: !isPasswordVisible,
            style: const TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(8.0),
              focusColor: color.scaffoldBackgroundColor,
              decoration: InputDecoration(
                labelText: 'Select Overseer Province',
                border: const OutlineInputBorder(), // Use const
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
          SizedBox(height: 20),
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
