// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables, avoid_print

import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Tactso_Audit_Logs.dart'; // Ensure this import exists

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 900.0;
bool get isDesktop =>
    kIsWeb ||
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

class AddCommitteeMember extends StatefulWidget {
  
  const AddCommitteeMember({super.key});

  @override
  State<AddCommitteeMember> createState() => _AddCommitteeMemberState();
}

class _AddCommitteeMemberState extends State<AddCommitteeMember> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State for Desktop Split View
  String? _selectedBranchId;
  Map<String, dynamic>? _selectedBranchData;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width > _desktopBreakpoint;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Manage Committees (Super Admin)",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: isLargeScreen ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // --- LAYOUTS ---

  Widget _buildMobileLayout() {
    return _buildBranchList(
      onTap: (docId, data) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      padding: EdgeInsets.all(20),
                      child: CommitteeManagerView(
                        branchId: docId,
                        branchData: data,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: List
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: _buildBranchList(
            onTap: (docId, data) {
              setState(() {
                _selectedBranchId = docId;
                _selectedBranchData = data;
              });
            },
            selectedId: _selectedBranchId,
          ),
        ),

        // Right: Details
        Expanded(
          child: _selectedBranchId == null
              ? Center(
                  child: Text(
                    "Select a University Branch to manage its committee.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(40),
                  child: CommitteeManagerView(
                    key: ValueKey(_selectedBranchId), // Force rebuild on change
                    branchId: _selectedBranchId!,
                    branchData: _selectedBranchData!,
                  ),
                ),
        ),
      ],
    );
  }

  // --- BRANCH LIST ---

  Widget _buildBranchList({
    required Function(String, Map<String, dynamic>) onTap,
    String? selectedId,
  }) {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('tactso_branches')
          .orderBy('universityName')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CupertinoActivityIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return Center(child: Text("No Branches Found"));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isSelected = selectedId == doc.id;

            // Get Logo
            String? logoUrl;
            if (data['imageUrl'] is List &&
                (data['imageUrl'] as List).isNotEmpty) {
              logoUrl = data['imageUrl'][0];
            } else if (data['imageUrl'] is String) {
              logoUrl = data['imageUrl'];
            }

            return Container(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: logoUrl != null
                      ? NetworkImage(logoUrl)
                      : null,
                  child: logoUrl == null
                      ? Icon(Icons.school, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  data['universityName'] ?? "Unknown",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  data['email'] ?? "",
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => onTap(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// === REUSABLE COMMITTEE MANAGER (Logic from TactsoBranchesApplications) ===
// =============================================================================

class CommitteeManagerView extends StatefulWidget {
  final String branchId;
  final Map<String, dynamic> branchData;

  const CommitteeManagerView({
    super.key,
    required this.branchId,
    required this.branchData,
  });

  @override
  State<CommitteeManagerView> createState() => _CommitteeManagerViewState();
}

class _CommitteeManagerViewState extends State<CommitteeManagerView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedRole;
  XFile? _faceImage;
  bool _isUploading = false;

  final List<String> _roles = [
    'Chairperson',
    'Deputy Chairperson',
    'Secretary',
    'Deputy Secretary',
    'Treasurer',
    'Additional Member',
    'Education Officer',
  ];

  // Colors matching previous design
  final Color _cardColor = Colors.white;
  final Color _borderColor = Colors.grey.shade300;
  final Color _inputFillColor = Colors.grey.shade50;
  final Color _primaryColor = const Color(0xFF1E3A8A);
  final Color _textColor = Colors.black87;
  final Color _subTextColor = Colors.grey.shade600;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _faceImage = picked);
  }

  Future<String> _uploadFile(XFile file) async {
    String uniName = widget.branchData['universityName'] ?? 'Unknown';
    final ref = FirebaseStorage.instance.ref(
      "Tactso Branches/$uniName/Committee/${_nameController.text}_${DateTime.now().millisecondsSinceEpoch}",
    );

    SettableMetadata? metadata;
    if (kIsWeb) metadata = SettableMetadata(contentType: 'image/jpeg');

    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), metadata);
    } else {
      await ref.putFile(io.File(file.path));
    }
    return await ref.getDownloadURL();
  }

  Future<void> _addMember() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _selectedRole == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please fill all fields",
        Colors.orange,
      );
      return;
    }
    if (_faceImage == null) {
      Api().showMessage(
        context,
        "Face Required",
        "Upload face for biometric login",
        Colors.red,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload Face
      String faceUrl = await _uploadFile(_faceImage!);

      // 2. Add to Sub-collection
      await FirebaseFirestore.instance
          .collection('tactso_branches')
          .doc(widget.branchId)
          .collection('committee_members')
          .add({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'role': _selectedRole,
            'faceUrl': faceUrl,
            'addedAt': FieldValue.serverTimestamp(),
            'addedBy': 'Super Admin',
          });

      // 3. Update Biometric Array
      await FirebaseFirestore.instance
          .collection('tactso_branches')
          .doc(widget.branchId)
          .update({
            'authorizedUserFaceUrls': FieldValue.arrayUnion([faceUrl]),
          });

      // 4. Audit Log
      String? logoUrl;
      if (widget.branchData['imageUrl'] is List &&
          (widget.branchData['imageUrl'] as List).isNotEmpty) {
        logoUrl = widget.branchData['imageUrl'][0];
      } else if (widget.branchData['imageUrl'] is String) {
        logoUrl = widget.branchData['imageUrl'];
      }

      await TactsoAuditLogs.logAction(
        action: "ADMIN_ADD_MEMBER",
        details: "Super Admin added ${_nameController.text} as $_selectedRole",
        referenceId: widget.branchId,
        universityName: widget.branchData['universityName'],
        universityLogo: logoUrl,
        committeeMemberName: "Super Admin",
        committeeMemberRole: "Administrator",
        universityCommitteeFace: null,
        targetMemberName: _nameController.text,
        targetMemberRole: _selectedRole,
      );

      _nameController.clear();
      _emailController.clear();
      setState(() {
        _selectedRole = null;
        _faceImage = null;
        _isUploading = false;
      });
      Api().showMessage(context, "Success", "Member added", Colors.green);
    } catch (e) {
      setState(() => _isUploading = false);
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  Future<void> _deleteMember(
    String docId,
    String? faceUrl,
    String name,
    String role,
  ) async {
    try {
      // 1. Delete Doc
      await FirebaseFirestore.instance
          .collection('tactso_branches')
          .doc(widget.branchId)
          .collection('committee_members')
          .doc(docId)
          .delete();

      // 2. Remove Face from Array
      if (faceUrl != null) {
        await FirebaseFirestore.instance
            .collection('tactso_branches')
            .doc(widget.branchId)
            .update({
              'authorizedUserFaceUrls': FieldValue.arrayRemove([faceUrl]),
            });
      }

      // 3. Audit
      String? logoUrl;
      if (widget.branchData['imageUrl'] is List &&
          (widget.branchData['imageUrl'] as List).isNotEmpty) {
        logoUrl = widget.branchData['imageUrl'][0];
      } else if (widget.branchData['imageUrl'] is String) {
        logoUrl = widget.branchData['imageUrl'];
      }

      await TactsoAuditLogs.logAction(
        action: "ADMIN_DELETE_MEMBER",
        details: "Super Admin removed $name",
        referenceId: widget.branchId,
        universityName: widget.branchData['universityName'],
        universityLogo: logoUrl,
        committeeMemberName: "Super Admin",
        committeeMemberRole: "Administrator",
        universityCommitteeFace: null,
        targetMemberName: name,
        targetMemberRole: role,
      );

      Api().showMessage(context, "Deleted", "Member removed", Colors.grey);
    } catch (e) {
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shield, color: Colors.blue, size: 30),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.branchData['universityName'] ?? "University",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Committee Management (Admin Override)",
                    style: TextStyle(color: _subTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 30),

        // --- ADD FORM ---
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add New Member",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Picker
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _inputFillColor,
                        border: Border.all(color: _borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _faceImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: _subTextColor),
                                SizedBox(height: 4),
                                Text(
                                  "Face",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _subTextColor,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: kIsWeb
                                  ? Image.network(
                                      _faceImage!.path,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      io.File(_faceImage!.path),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                    ),
                  ),
                  SizedBox(width: 20),
                  // Inputs
                  Expanded(
                    child: Column(
                      children: [
                        _styledTextField(
                          _nameController,
                          "Full Name",
                          Icons.person,
                        ),
                        SizedBox(height: 12),
                        _styledTextField(
                          _emailController,
                          "Email",
                          Icons.email,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      hint: Text("Select Portfolio"),
                      dropdownColor: _cardColor,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: _roles
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRole = v),
                    ),
                  ),
                  SizedBox(width: 15),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _addMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: _isUploading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text("Add Member"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 30),
        Text(
          "Current Committee",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        SizedBox(height: 15),

        // --- GRID LIST ---
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('tactso_branches')
              .doc(widget.branchId)
              .collection('committee_members')
              .orderBy('addedAt')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CupertinoActivityIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return Container(
                padding: EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "No members found.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );

            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                mainAxisExtent: 90,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;

                return Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[200],
                          image: DecorationImage(
                            image: NetworkImage(data['faceUrl'] ?? ''),
                            fit: BoxFit.cover,
                            onError: (e, s) => Icon(Icons.person),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              data['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              data['role'] ?? 'Member',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteMember(
                          doc.id,
                          data['faceUrl'],
                          data['name'] ?? '',
                          data['role'] ?? '',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        SizedBox(height: 50), // Bottom padding
      ],
    );
  }

  Widget _styledTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _subTextColor, size: 20),
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
