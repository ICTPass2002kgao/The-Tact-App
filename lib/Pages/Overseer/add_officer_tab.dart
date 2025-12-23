import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'overseer_widgets.dart'; // Ensure this contains buildPlatformTextField

class AddOfficerTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  const AddOfficerTab({super.key, required this.isLargeScreen, required this.committeeMemberName, required this.committeeMemberRole, required this.faceUrl});

  @override
  State<AddOfficerTab> createState() => _AddOfficerTabState();
}

class _AddOfficerTabState extends State<AddOfficerTab> {
  // --- CONTROLLERS ---
  final TextEditingController officerNameController = TextEditingController();
  final TextEditingController communityOfficerController = TextEditingController();

  @override
  void dispose() {
    officerNameController.dispose();
    communityOfficerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          decoration: widget.isLargeScreen
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                )
              : null,
          child: Column(
            children: [
              const Text(
                "Add District Officer",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              buildPlatformTextField(
                context,
                controller: officerNameController,
                placeholder: "District Elder Name",
              ),
              
              buildPlatformTextField(
                context,
                controller: communityOfficerController,
                placeholder: "Community Name",
              ),
              
              const SizedBox(height: 20),
              
              CustomOutlinedButton(
                onPressed: _saveOfficer,
                text: "Save Officer",
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGIC ---
  Future<void> _saveOfficer() async {
    if (officerNameController.text.isEmpty ||
        communityOfficerController.text.isEmpty) {
      Api().showMessage(
        context,
        "Please fill in both fields.",
        "Missing Info",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception("User not logged in");
      }

      // NOTE: This assumes the document ID is the same as the User ID.
      // If your database uses auto-generated IDs, you might need to query using .where('uid', isEqualTo: uid) first.
      await FirebaseFirestore.instance
          .collection('overseers')
          .doc(uid)
          .update({
        'districts': FieldValue.arrayUnion([
          {
            'districtElderName': officerNameController.text.trim(),
            'communities': [
              {
                'communityName': communityOfficerController.text.trim(),
              },
            ],
          },
        ]),
      });

      if (mounted) Navigator.pop(context); // Close Loading
      OverseerAuditLogs.logAction(action: "CREATED", details: "Created officer ${officerNameController.text.trim()}",   committeeMemberName: widget.committeeMemberName, committeeMemberRole: widget.committeeMemberRole, universityCommitteeFace: widget.faceUrl);
             
      if (mounted) {
        Api().showMessage(
          context,
          "Officer and Community Added Successfully",
          "Success",
          Colors.green,
        );
      }

      // Clear inputs
      officerNameController.clear();
      communityOfficerController.clear();

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close Loading
      if (mounted) {
        Api().showMessage(context, "Error saving officer: $e", "Error", Colors.red);
      }
    }
  }
}