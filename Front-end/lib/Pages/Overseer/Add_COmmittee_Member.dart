// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http; // Added for Django
import 'package:firebase_auth/firebase_auth.dart'; // Only for Auth UID
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/NeuDesign.dart';

class AddCommitteeMemberTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;

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

  // Data State
  List<dynamic> _committeeMembers = [];
  bool _isLoadingMembers = true;

  final List<String> _committeeRoles = [
    'Secretary',
    'Deputy Secretary',
    'Treasurer',
    'Chairperson',
    'District Elder',
    'Additional Member',
  ];

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

  // --- 1. FETCH COMMITTEE MEMBERS (DJANGO) ---
  Future<void> _fetchCommitteeMembers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _isLoadingMembers = true);

      // A. Get Overseer ID via Email
      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${user.email}',
      );
      final profileResp = await http.get(profileUrl);

      if (profileResp.statusCode == 200) {
        final List data = json.decode(profileResp.body);
        if (data.isNotEmpty) {
          final overseerId = data[0]['id'];

          // B. Get Committee Members for this Overseer
          // URL: /api/committee_members/?overseer=ID
          final url = Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/?overseer=$overseerId',
          );
          final response = await http.get(url);

          if (response.statusCode == 200) {
            setState(() {
              _committeeMembers = json.decode(response.body);
              _isLoadingMembers = false;
            });
            return;
          }
        }
      }
      setState(() => _isLoadingMembers = false);
    } catch (e) {
      print("Error fetching committee: $e");
      if (mounted) setState(() => _isLoadingMembers = false);
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

  // --- 2. ADD MEMBER (DJANGO POST MULTIPART) ---
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

      // 1. Get Overseer ID
      final profileUrl = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${user.email}',
      );
      final profileResp = await http.get(profileUrl);

      if (profileResp.statusCode != 200)
        throw Exception("Failed to get profile");
      final List data = json.decode(profileResp.body);
      if (data.isEmpty) throw Exception("Overseer profile not found");

      final overseerId = data[0]['id'].toString();

      // 2. Prepare Multipart Request (Image + Data)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/committee_members/'),
      );

      request.fields['overseer'] = overseerId;
      request.fields['name'] = _committeeNameController.text.trim();
      request.fields['email'] = _committeeEmailController.text
          .trim(); // Optional in UI but good to have
      request.fields['role'] = 'Overseer'; // Default role category
      request.fields['portfolio'] = _selectedRole!;

      // 3. Add Image File
      // Note: Backend must accept 'face_image' or 'faceUrl' as file field.
      // Assuming backend handles encryption internally upon receiving file.
      // If backend only accepts URL string, you must upload separately first.
      // Let's assume standard Django ViewSet handles file upload:
      if (kIsWeb) {
        final bytes = await _committeeFaceImage!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'face_image', // Key expected by Django
            bytes,
            filename: _committeeFaceImage!.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'face_image',
            _committeeFaceImage!.path,
          ),
        );
      }

      // 4. Send Request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        // Success
        OverseerAuditLogs.logAction(
          action: "CREATED",
          details:
              "Created committee member ${_committeeNameController.text.trim()}",
          committeeMemberName: widget.committeeMemberName,
          committeeMemberRole: widget.committeeMemberRole,
          universityCommitteeFace: widget.faceUrl,
        );

        // Reset UI
        _committeeNameController.clear();
        _committeeEmailController.clear();
        setState(() {
          _selectedRole = null;
          _committeeFaceImage = null;
          _isUploadingCommittee = false;
        });

        _fetchCommitteeMembers(); // Refresh List

        if (mounted) {
          Api().showMessage(
            context,
            "Success",
            "Member added successfully.",
            Colors.green,
          );
        }
      } else {
        print("Upload Error: ${response.body}");
        throw Exception("Server rejected upload: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingCommittee = false);
        Api().showMessage(context, "Error", e.toString(), Colors.red);
      }
    }
  }

  // --- 3. DELETE MEMBER (DJANGO DELETE) ---
  Future<void> _deleteCommitteeMember(
    int memberId, // Django uses Int ID
    String name,
  ) async {
    try {
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/$memberId/',
      );
      final response = await http.delete(url);

      if (response.statusCode == 204) {
        _fetchCommitteeMembers();
        if (mounted) {
          Api().showMessage(context, "Deleted", "$name removed.", Colors.grey);
        }
      } else {
        print("Delete failed: ${response.statusCode}");
      }
    } catch (e) {
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  // --- HELPER: Secure URL ---
  String _getSecureImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return "";
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  // --- NEUMORPHIC TEXT FIELD HELPER ---
  Widget _styledNeumorphicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color hintColor,
    required Color primaryColor,
  }) {
    return NeumorphicContainer(
      isPressed: true,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      borderRadius: 12,
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: hintColor),
          icon: Icon(icon, color: hintColor),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.primaryColor;
    final Color hintColor = theme.hintColor;
    final Color baseColor = theme.scaffoldBackgroundColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // CURRENT SESSION INFO
          if (widget.currentUserName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 25.0),
              child: NeumorphicContainer(
                borderRadius: 12,
                padding: EdgeInsets.all(20),
                color: baseColor,
                child: Row(
                  children: [
                    NeumorphicContainer(
                      isPressed: true,
                      borderRadius: 50,
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.badge_outlined,
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Session:",
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        Text(
                          "${widget.currentUserName} (${widget.currentUserPortfolio ?? 'Member'})",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          Text(
            "Committee Members (Max 5)",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 20),

          // INPUT CARD
          NeumorphicContainer(
            padding: EdgeInsets.all(24),
            borderRadius: 16,
            color: baseColor,
            child: Column(
              children: [
                Row(
                  children: [
                    // IMAGE PICKER
                    GestureDetector(
                      onTap: _pickCommitteeImage,
                      child: NeumorphicContainer(
                        isPressed: true,
                        borderRadius: 12,
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: _committeeFaceImage == null
                              ? Icon(Icons.add_a_photo, color: hintColor)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
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
                    ),
                    SizedBox(width: 20),
                    // TEXT FIELDS
                    Expanded(
                      child: Column(
                        children: [
                          _styledNeumorphicTextField(
                            controller: _committeeNameController,
                            label: "Name",
                            icon: Icons.person,
                            hintColor: hintColor,
                            primaryColor: primaryColor,
                          ),
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
                      child: NeumorphicContainer(
                        isPressed: true,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            hint: Text(
                              "Select Role",
                              style: TextStyle(color: hintColor),
                            ),
                            dropdownColor: baseColor,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: primaryColor,
                            ),
                            items: _committeeRoles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedRole = v),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),

                    // ADD BUTTON
                    GestureDetector(
                      onTap: _isUploadingCommittee
                          ? null
                          : _addCommitteeMemberTab,
                      child: NeumorphicContainer(
                        isPressed: false,
                        borderRadius: 12,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 15,
                        ),
                        color: baseColor,
                        child: _isUploadingCommittee
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Add",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 30),

          // GRID VIEW (LIST OF MEMBERS)
          _isLoadingMembers
              ? Center(child: CupertinoActivityIndicator())
              : _committeeMembers.isEmpty
              ? Center(
                  child: NeumorphicContainer(
                    isPressed: true,
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "No members added yet.",
                      style: TextStyle(color: hintColor),
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 100,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _committeeMembers.length,
                  itemBuilder: (context, index) {
                    var data = _committeeMembers[index];
                    // Convert Django face_url
                    String? faceUrl = data['face_url'] ?? data['faceUrl'];
                    String? secureUrl = faceUrl != null
                        ? _getSecureImageUrl(faceUrl)
                        : null;

                    return NeumorphicContainer(
                      borderRadius: 12,
                      padding: EdgeInsets.all(12),
                      color: baseColor,
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: secureUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(secureUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: secureUrl == null
                                ? Icon(Icons.person, color: hintColor)
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
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  data['portfolio'] ?? 'No Role',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade300,
                            ),
                            onPressed: () => _deleteCommitteeMember(
                              data['id'],
                              data['name'],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
