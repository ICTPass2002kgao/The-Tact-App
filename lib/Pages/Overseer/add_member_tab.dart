import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'overseer_widgets.dart'; // Ensure this contains buildPlatformTextField

class AddMemberTab extends StatefulWidget {

  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  const AddMemberTab({super.key, required this.isLargeScreen, required this.committeeMemberName, required this.committeeMemberRole, required this.faceUrl});

  @override
  State<AddMemberTab> createState() => _AddMemberTabState();
}

class _AddMemberTabState extends State<AddMemberTab> {
  // --- CONTROLLERS ---
  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberSurnameController = TextEditingController();
  final TextEditingController memberEmailController = TextEditingController();
  final TextEditingController memberAddressController = TextEditingController();
  final TextEditingController memberContactController = TextEditingController();

  // --- DROPDOWN STATE ---
  String? selectedDistrictElder;
  String? selectedCommunityName;
  String selectedProvince = '';

  @override
  void dispose() {
    memberNameController.dispose();
    memberSurnameController.dispose();
    memberEmailController.dispose();
    memberAddressController.dispose();
    memberContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(20),
        decoration: widget.isLargeScreen
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Register New Member",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            buildPlatformTextField(
              context,
              controller: memberNameController,
              placeholder: "First Name",
            ),
            buildPlatformTextField(
              context,
              controller: memberSurnameController,
              placeholder: "Surname",
            ),
            buildPlatformTextField(
              context,
              controller: memberEmailController,
              placeholder: "Email (Optional)",
              keyboardType: TextInputType.emailAddress,
            ),
            buildPlatformTextField(
              context,
              controller: memberAddressController,
              placeholder: "Address",
            ),
            buildPlatformTextField(
              context,
              controller: memberContactController,
              placeholder: "Phone Number",
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 10),
            
            // Dropdowns for Organization
            _buildOrgDropdowns(),
            
            const SizedBox(height: 20),
            
            CustomOutlinedButton(
              onPressed: _registerMember,
              text: "Save Member",
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  // --- DROPDOWN BUILDER ---
  Widget _buildOrgDropdowns() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Text("Overseer profile not found.");

        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        selectedProvince = data['province'] ?? '';
        List districts = data['districts'] ?? [];

        // Extract District Elders
        List<String> elders = districts
            .map((e) => e['districtElderName'].toString())
            .toList();

        // Extract Communities based on selected District Elder
        List<String> communities = [];
        if (selectedDistrictElder != null) {
          var dist = districts.firstWhere(
            (e) => e['districtElderName'] == selectedDistrictElder,
            orElse: () => null,
          );
          if (dist != null) {
            communities = (dist['communities'] as List)
                .map((c) => c['communityName'].toString())
                .toList();
          }
        }

        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedDistrictElder,
              hint: const Text("Select District Elder"),
              items: elders.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() {
                selectedDistrictElder = val;
                selectedCommunityName = null; // Reset community
              }),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedCommunityName,
              hint: const Text("Select Community"),
              items: communities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() {
                selectedCommunityName = val;
              }),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- LOGIC ---
  Future<void> _registerMember() async {
    if (memberNameController.text.isEmpty ||
        memberSurnameController.text.isEmpty ||
        selectedDistrictElder == null) {
      Api().showMessage(
        context,
        "Please fill required fields (Name, Surname, District)",
        "Error",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);
    
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'name': memberNameController.text.trim(),
        'surname': memberSurnameController.text.trim(),
        'email': memberEmailController.text.trim(),
        'address': memberAddressController.text.trim(),
        'phone': memberContactController.text.trim(),
        'overseerUid': FirebaseAuth.instance.currentUser?.uid,
        'role': 'Member',
        'province': selectedProvince,
        'districtElderName': selectedDistrictElder,
        'communityName': selectedCommunityName,
        'week1': 0.0,
        'week2': 0.0,
        'week3': 0.0,
        'week4': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) Navigator.pop(context); // Close loading
      
      if (mounted) {
        Api().showMessage(context, "Member added successfully", "Success", Colors.green);
      }

      OverseerAuditLogs.logAction(action: "CREATED", details: "Created member ${memberNameController.text.trim()}",   committeeMemberName: widget.committeeMemberName, committeeMemberRole: widget.committeeMemberRole, universityCommitteeFace: widget.faceUrl);

      _clearMemberInputs();
      
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) {
        Api().showMessage(context, "Error: $e", "Error", Colors.red);
      }
    }
  }

  void _clearMemberInputs() {
    memberNameController.clear();
    memberSurnameController.clear();
    memberEmailController.clear();
    memberAddressController.clear();
    memberContactController.clear();
    setState(() {
      selectedDistrictElder = null;
      selectedCommunityName = null;
    });
  }
}