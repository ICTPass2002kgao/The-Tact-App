// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';

class AddCommitteeMemberTab extends StatefulWidget {

  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;

  // --- NEW: Receive Logged in User Data ---
  final String? currentUserName;
  final String? currentUserPortfolio;


  const AddCommitteeMemberTab({

    super.key,
    required this.isLargeScreen,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
    this.currentUserName,
    this.currentUserPortfolio,
  });

  @override
  State<AddCommitteeMemberTab> createState() => _AddCommitteeMemberTabState();
}

class _AddCommitteeMemberTabState extends State<AddCommitteeMemberTab> {
  // --- CONTROLLERS ---
  final TextEditingController _committeeNameController =
      TextEditingController();
  final TextEditingController _committeeEmailController =
      TextEditingController();

  // --- STATE ---
  String? _selectedRole;
  XFile? _committeeFaceImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingCommittee = false;
  Future<QuerySnapshot>? _committeeFuture;

  final List<String> _committeeRoles = [
    'Secretary',
    'Deputy Secretary',
    'Treasurer',
    'Chairperson',
    'District Elder',
    'Additional Member',
  ];

  // --- STYLE GETTERS ---
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _primaryColor => const Color(0xFF1E3A8A);
  Color get _cardColor => _isDarkMode ? const Color(0xFF1F2937) : Colors.white;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor =>
      _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
  Color get _inputFillColor =>
      _isDarkMode ? const Color(0xFF374151) : Colors.grey.shade50;
  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF4B5563) : Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    _fetchCommitteeMembers();
  }

  @override
  void dispose() {
    _committeeNameController.dispose();
    _committeeEmailController.dispose();
    super.dispose();
  }

  // --- DATA LOADING ---
  void _fetchCommitteeMembers() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _committeeFuture = FirebaseFirestore.instance
            .collection('overseers')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get()
            .then((snapshot) {
              if (snapshot.docs.isNotEmpty) {
                return snapshot.docs.first.reference
                    .collection('committee_members')
                    .get();
              }
              return Future.error("User document not found");
            });
      });
    }
  }

  // --- ACTIONS ---
  Future<void> _pickCommitteeImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _committeeFaceImage = picked);
  }

  Future<String> _uploadFile(XFile file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    UploadTask uploadTask;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/${file.name.split('.').last}'),
      );
    } else {
      uploadTask = ref.putFile(io.File(file.path));
    }
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _addCommitteeMemberTab() async {
    if (_committeeNameController.text.isEmpty || _selectedRole == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please fill all fields.",
        Colors.orange,
      );
      return;
    }
    if (_committeeFaceImage == null) {
      Api().showMessage(
        context,
        "Face Required",
        "Upload face for biometric login.",
        Colors.red,
      );
      return;
    }

    setState(() => _isUploadingCommittee = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. Find correct doc
      final querySnapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty)
        throw Exception("Overseer profile not found.");
      final overseerRef = querySnapshot.docs.first.reference;

      // 2. Upload Image
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String path =
          "Overseers/${user.uid}/Committee/${_committeeNameController.text}_$timestamp";
      String faceUrl = await _uploadFile(_committeeFaceImage!, path);

      // 3. Add to Sub-collection
      await overseerRef.collection('committee_members').add({
        'name': _committeeNameController.text.trim(),
        'email': _committeeEmailController.text.trim(),
        'role': 'Overseer',
        'portfolio': _selectedRole,
        'faceUrl': faceUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // 4. Update Main Doc
      await overseerRef.update({
        'authorizedUserFaceUrls': FieldValue.arrayUnion([faceUrl]),
      });

      // 5. Reset

      OverseerAuditLogs.logAction(action: "CREATED", details: "Created committee member ${_committeeNameController.text.trim()}",   committeeMemberName: widget.committeeMemberName, committeeMemberRole: widget.committeeMemberRole, universityCommitteeFace: widget.faceUrl);
             
      _committeeNameController.clear();
      _committeeEmailController.clear();
      setState(() {
        _selectedRole = null;
        _committeeFaceImage = null;
        _isUploadingCommittee = false;
      });
      _fetchCommitteeMembers();
      Api().showMessage(
        context,
        "Success",
        "Member added successfully.",
        Colors.green,
      );
    } catch (e) {
      setState(() => _isUploadingCommittee = false);
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  Future<void> _deleteCommitteeMember(
    String docId,
    String? faceUrl,
    String name,
    String role,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final overseerRef = querySnapshot.docs.first.reference;

        await overseerRef.collection('committee_members').doc(docId).delete();

        if (faceUrl != null) {
          await overseerRef.update({
            'authorizedUserFaceUrls': FieldValue.arrayRemove([faceUrl]),
          });
        }
        
        _fetchCommitteeMembers();
        Api().showMessage(context, "Deleted", "$name removed.", Colors.grey);
      }
    } catch (e) {
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  // --- UI WIDGETS ---

  Widget _styledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: _textColor),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _subTextColor),
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // --- NEW: DISPLAY LOGGED IN USER INFO ---
          if (widget.currentUserName != null)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 25),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: _primaryColor, size: 32),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Current Session:",
                        style: TextStyle(fontSize: 12, color: _subTextColor),
                      ),
                      Text(
                        "${widget.currentUserName} (${widget.currentUserPortfolio ?? 'Member'})",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ----------------------------------------
          Text(
            "Committee Members (Max 5)",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          SizedBox(height: 20),

          // --- INPUT CARD ---
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // IMAGE PICKER BOX
                    InkWell(
                      onTap: _pickCommitteeImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: _borderColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _committeeFaceImage == null
                            ? Icon(Icons.add_a_photo, color: _subTextColor)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: kIsWeb
                                    ? Image.network(
                                        _committeeFaceImage!.path,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        io.File(_committeeFaceImage!.path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                      ),
                    ),
                    SizedBox(width: 20),
                    // TEXT FIELDS COLUMN
                    Expanded(
                      child: Column(
                        children: [
                          _styledTextField(
                            controller: _committeeNameController,
                            label: "Name",
                            icon: Icons.person,
                          ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                // ROLE DROPDOWN & BUTTON
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        dropdownColor: _cardColor,
                        style: TextStyle(color: _textColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _inputFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _borderColor),
                          ),
                        ),
                        items: _committeeRoles
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedRole = v),
                      ),
                    ),
                    SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: _isUploadingCommittee
                          ? null
                          : _addCommitteeMemberTab,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        minimumSize: Size(120, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUploadingCommittee
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text("Add", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 30),

          // --- GRID VIEW ---
          FutureBuilder<QuerySnapshot>(
            future: _committeeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CupertinoActivityIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    "No members added yet.",
                    style: TextStyle(color: _subTextColor),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 100,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: NetworkImage(data['faceUrl'] ?? ''),
                              fit: BoxFit.cover,
                              onError: (e, s) {},
                            ),
                          ),
                          child: data['faceUrl'] == null
                              ? Icon(Icons.person, color: _subTextColor)
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                data['portfolio'] ?? 'No Role',
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCommitteeMember(
                            doc.id,
                            data['faceUrl'],
                            data['name'],
                            data['portfolio'],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
