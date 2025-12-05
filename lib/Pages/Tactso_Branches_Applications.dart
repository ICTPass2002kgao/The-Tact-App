// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AuditService.dart';
import 'package:ttact/Pages/Payment.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' as io;

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1100.0;
bool get isAppleStyle =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

class TactsoBranchesApplications extends StatefulWidget {
  // Parameters passed from FaceVerificationScreen
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl;

  const TactsoBranchesApplications({
    super.key,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.faceUrl,
  });

  @override
  State<TactsoBranchesApplications> createState() =>
      _TactsoBranchesApplicationsState();
}

class _TactsoBranchesApplicationsState
    extends State<TactsoBranchesApplications> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isDarkMode = false;
  String? _universityName;
  String? _adminEmail;
  String? _currentuid;
  bool _isLoadingUniversityData = true;

  Future<QuerySnapshot>? _committeeFuture;
  int _selectedIndex = 0;

  final TextEditingController _committeeNameController =
      TextEditingController();
  final TextEditingController _committeeEmailController =
      TextEditingController();
  String? _selectedRole;
  XFile? _committeeFaceImage;
  bool _isUploadingCommittee = false;
  String? _universityLogoUrl;
  String? _universityCommitteeFace; // Main face (usually Officer)

  final List<String> _committeeRoles = [
    'Chairperson',
    'Deputy Chairperson',
    'Secretary',
    'Deputy Secretary',
    'Treasurer',
    'Additional Member',
  ];
  final List<String> _applicationStatuses = [
    'New',
    'Reviewed',
    'Application Submitted',
    'Rejected',
  ];
  String? _committeeName; // Default Officer Name

  final Color _primaryColor = const Color(0xFF1E3A8A);
  final Color _accentColor = const Color(0xFF3B82F6);
  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
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
    _loadUniversityData();
    Future.delayed(Duration.zero, _checkAuthorization);
  }

  @override
  void dispose() {
    _committeeNameController.dispose();
    _committeeEmailController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthorization() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _fetchCommitteeMembers() {
    if (_currentuid != null) {
      setState(() {
        _committeeFuture = _firestore
            .collection('tactso_branches')
            .doc(_currentuid)
            .collection('committee_members')
            .orderBy('addedAt')
            .get();
      });
    }
  }

  Future<void> _loadUniversityData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _currentuid = currentUser.uid;
      _adminEmail = currentUser.email;
      _fetchCommitteeMembers();

      try {
        QuerySnapshot querySnapshot = await _firestore
            .collection('tactso_branches')
            .where('uid', isEqualTo: _currentuid)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          var data = querySnapshot.docs.first.data() as Map<String, dynamic>;
          setState(() {
            _universityName = data['universityName'] ?? 'University Admin';
            _committeeName = data['educationOfficerName'] ?? 'Committee';
            _universityCommitteeFace = data['educationOfficerFaceUrl'];
            var imgField = data['imageUrl'];
            if (imgField is List && imgField.isNotEmpty) {
              _universityLogoUrl = imgField[0].toString();
            } else if (imgField is String) {
              _universityLogoUrl = imgField;
            } else {
              _universityLogoUrl = null;
            }
          });
        }
      } catch (e) {
        debugPrint("Error loading data: $e");
      }
    }
    setState(() => _isLoadingUniversityData = false);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted)
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

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

  // --- ADD MEMBER + AUDIT ---
  Future<void> _addCommitteeMember() async {
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

    QuerySnapshot existingMembers = await _firestore
        .collection('tactso_branches')
        .doc(_currentuid)
        .collection('committee_members')
        .get();

    // MAX LIMIT CHECK: 5 Members Total (Officer + Chair + 3 Others)
    if (existingMembers.docs.length >= 5) {
      Api().showMessage(
        context,
        "Limit Reached",
        "Maximum 5 committee members allowed.",
        Colors.red,
      );
      return;
    }

    setState(() => _isUploadingCommittee = true);

    try {
      String faceUrl = await _uploadFile(
        _committeeFaceImage!,
        "Tactso Branches/$_universityName/Committee/${_committeeNameController.text}_${DateTime.now().millisecondsSinceEpoch}",
      );

      await _firestore
          .collection('tactso_branches')
          .doc(_currentuid)
          .collection('committee_members')
          .add({
            'name': _committeeNameController.text.trim(),
            'email': _committeeEmailController.text.trim(),
            'role': _selectedRole,
            'faceUrl': faceUrl,
            'addedAt': FieldValue.serverTimestamp(),
          });

      // Add face to authorized list
      await _firestore.collection('tactso_branches').doc(_currentuid).update({
        'authorizedUserFaceUrls': FieldValue.arrayUnion([faceUrl]),
      });

      // --- LOG AUDIT ---
      await AuditService.logAction(
        action: "ADD_COMMITTEE_MEMBER",
        details: "Added ${_committeeNameController.text} as $_selectedRole",
        referenceId: "N/A",
        // University Context
        universityName: _universityName,
        universityLogo: _universityLogoUrl,
        // Actor (Logged In)
        committeeMemberName: widget.loggedMemberName ?? _committeeName,
        committeeMemberRole: widget.loggedMemberRole ?? "Education Officer",
        universityCommitteeFace: _universityCommitteeFace,
        // Target (New Member)
        targetMemberName: _committeeNameController.text,
        targetMemberRole: _selectedRole,
      );

      _committeeNameController.clear();
      _committeeEmailController.clear();
      setState(() {
        _selectedRole = null;
        _committeeFaceImage = null;
        _isUploadingCommittee = false;
      });

      _fetchCommitteeMembers();
      Api().showMessage(context, "Success", "Member added.", Colors.green);
    } catch (e) {
      setState(() => _isUploadingCommittee = false);
      Api().showMessage(context, "Error", e.toString(), Colors.red);
    }
  }

  // --- DELETE MEMBER + AUDIT ---
  Future<void> _deleteCommitteeMember(
    String docId,
    String? faceUrl,
    String memberName,
    String memberRole,
  ) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    memberName == widget.loggedMemberName
                        ? "Please confirm that you're deleting yourself in the database and any action taken cannot be revert back!!"
                        : "Please confirm deletion of $memberName the current $memberRole of this branch.",
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                      },
                      child: Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () async {
                        isIOSPlatform
                            ? Api().showIosLoading(context)
                            : Api().showLoading(context);
                        await _firestore
                            .collection('tactso_branches')
                            .doc(_currentuid)
                            .collection('committee_members')
                            .doc(docId)
                            .delete();

                        if (faceUrl != null) {
                          await _firestore
                              .collection('tactso_branches')
                              .doc(_currentuid)
                              .update({
                                'authorizedUserFaceUrls':
                                    FieldValue.arrayRemove([faceUrl]),
                              });
                        }

                        await AuditService.logAction(
                          action: "DELETE_COMMITTEE_MEMBER",
                          details: "Removed $memberName from committee",
                          referenceId: docId,
                          // University Context
                          universityName: _universityName,
                          universityLogo: _universityLogoUrl,
                          // Actor (Logged In)
                          committeeMemberName:
                              widget.loggedMemberName ?? _committeeName,
                          committeeMemberRole:
                              widget.loggedMemberRole ?? "Education Officer",
                          universityCommitteeFace: _universityCommitteeFace,
                          // Target (Deleted Member)
                          targetMemberName: memberName,
                          targetMemberRole: memberRole,
                        );
                        _fetchCommitteeMembers();
                        if (memberName == widget.loggedMemberName &&
                            memberRole == widget.loggedMemberRole) {
                          _auth.signOut();
                          Navigator.pop(context);
                          Navigator.pushNamed(context, "/login");
                        }
                        Api().showMessage(
                          context,
                          "Deleted",
                          memberName == widget.loggedMemberName
                              ? "You deleted yourself!!"
                              : "Member removed.",
                          Colors.grey,
                        );
                      },
                      child: Text("Confirm"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // --- LOG AUDIT ---
  }

  // --- UPDATE STATUS + AUDIT ---
  Future<void> _updateApplicationStatus({
    required String applicationId,
    required String newStatus,
    String? globalApplicationRequestId,
    String? userId,
    Map<String, dynamic>? applicationData,
  }) async {
    if (_currentuid == null) return;
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference universityAppRef = _firestore
            .collection('tactso_branches')
            .doc(_currentuid)
            .collection('application_requests')
            .doc(applicationId);
        transaction.update(universityAppRef, {'status': newStatus});
        if (globalApplicationRequestId != null) {
          DocumentReference globalAppRef = _firestore
              .collection('application_requests')
              .doc(globalApplicationRequestId);
          transaction.update(globalAppRef, {
            'applicationDetails.status': newStatus,
            'status': newStatus,
          });
        }
        if (userId != null) {
          QuerySnapshot userAppsSnapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('university_applications')
              .where('uid', isEqualTo: _currentuid)
              .where('applicationRequestId', isEqualTo: applicationId)
              .get();
          if (userAppsSnapshot.docs.isNotEmpty) {
            transaction.update(userAppsSnapshot.docs.first.reference, {
              'status': newStatus,
            });
          }
        }
      });

      if (applicationData != null) {
        final details = applicationData['applicationDetails'] ?? {};
        final studentEmail = details['email'];
        if (studentEmail != null)
          await Api().sendEmail(
            studentEmail,
            'Status Update: $newStatus',
            '<p>Your status is now: $newStatus</p>',
            context,
          );
      }

      // --- LOG AUDIT ---
      String studentName =
          applicationData?['applicationDetails']?['fullName'] ?? "Unknown";

      await AuditService.logAction(
        action: "UPDATE_STATUS",
        details: "Changed status to $newStatus for $studentName",
        referenceId: applicationId,
        // University Context
        universityName: _universityName,
        universityLogo: _universityLogoUrl,
        // Actor (Logged In)
        committeeMemberName: widget.loggedMemberName ?? _committeeName,
        committeeMemberRole: widget.loggedMemberRole ?? "Education Officer",
        universityCommitteeFace: _universityCommitteeFace,
        // Target (Student)
        studentName: studentName,
      );

      if (mounted) {
        Api().showMessage(context, 'Updated', 'Status changed.', Colors.green);
        setState(() {});
      }
    } catch (e) {
      if (mounted) Api().showMessage(context, 'Error', '$e', Colors.red);
    }
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url)))
      Api().showMessage(context, 'Error', 'Invalid URL', Colors.red);
  }

  // ===========================================================================
  // === UI & DESIGN (UNCHANGED) ===
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null)
      return Scaffold(body: Center(child: Text("Session Expired.")));
    if (_isLoadingUniversityData || _currentuid == null)
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: isAppleStyle
              ? CupertinoActivityIndicator()
              : CircularProgressIndicator(),
        ),
      );

    Widget contentBody = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _selectedIndex == 0
              ? _buildDashboardTab(context)
              : _selectedIndex == 1
              ? _buildApplicationsTableTab(context)
              : _buildCommitteeTab(context),
        ),
      ),
    );

    final double screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= _desktopBreakpoint) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 280,
              color: _cardColor,
              child: _buildDrawerContent(context, isSidebar: true),
            ),
            Expanded(
              child: Scaffold(
                backgroundColor: _bgColor,
                appBar: _buildAppBar(context),
                body: SingleChildScrollView(child: contentBody),
              ),
            ),
          ],
        ),
      );
    }
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: _buildAppBar(context),
        drawer: Drawer(
          backgroundColor: _cardColor,
          child: _buildDrawerContent(context, isSidebar: false),
        ),
        body: SingleChildScrollView(child: contentBody),
      );
    }
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(child: contentBody),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: _cardColor,
          indicatorColor: _primaryColor.withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.all(
            TextStyle(color: _textColor, fontSize: 12),
          ),
          iconTheme: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.selected)
                ? IconThemeData(color: _primaryColor)
                : IconThemeData(color: _subTextColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.table_chart_outlined),
              selectedIcon: Icon(Icons.table_chart),
              label: 'Applications',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outlined),
              selectedIcon: Icon(Icons.people),
              label: 'Team',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        _universityName ?? "Admin Portal",
        style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
      ),
      backgroundColor: _cardColor,
      elevation: 0,
      iconTheme: IconThemeData(color: _textColor),
      actions: [
        IconButton(
          icon: Icon(
            _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: _isDarkMode ? Colors.yellow.shade600 : Colors.grey.shade600,
          ),
          onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
        ),
        SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            backgroundColor: _primaryColor.withOpacity(0.1),
            backgroundImage: _universityLogoUrl != null
                ? NetworkImage(_universityLogoUrl!)
                : null,
            child: _universityLogoUrl == null
                ? Text(
                    _universityName?.substring(0, 1) ?? "U",
                    style: TextStyle(color: _primaryColor),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerContent(BuildContext context, {required bool isSidebar}) {
    final color = isSidebar
        ? (_isDarkMode ? Colors.white70 : Colors.black54)
        : _textColor;
    return Column(
      children: [
        if (isSidebar)
          Container(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: _primaryColor,
                ),
                SizedBox(height: 10),
                Text(
                  "TACTSO ADMIN",
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        if (!isSidebar)
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: _primaryColor),
            accountName: Text(_universityName ?? 'Admin'),
            accountEmail: Text(_adminEmail ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.school, color: _primaryColor),
            ),
          ),
        SizedBox(height: 20),
        _drawerItem(Icons.dashboard_rounded, "Dashboard", 0, color),
        _drawerItem(Icons.table_chart_rounded, "Applications", 1, color),
        _drawerItem(Icons.groups_rounded, "Committee", 2, color),
        Spacer(),
        ListTile(
          leading: Icon(Icons.logout_rounded, color: Colors.redAccent),
          title: Text("Logout", style: TextStyle(color: Colors.redAccent)),
          onTap: _logout,
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _drawerItem(IconData icon, String title, int index, Color color) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isActive
            ? _primaryColor.withOpacity(0.1)
            : Colors.transparent,
        leading: Icon(icon, color: isActive ? _primaryColor : color),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? _primaryColor : color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (Scaffold.of(context).hasDrawer &&
              Scaffold.of(context).isDrawerOpen)
            Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildDashboardTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tactso_branches')
          .doc(_currentuid)
          .collection('application_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CupertinoActivityIndicator());
        }

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final newApps = docs.where((d) => d['status'] == 'New').length;
        final submitted = docs
            .where((d) => d['status'] == 'Application Submitted')
            .length;
        final rejected = docs.where((d) => d['status'] == 'Rejected').length;
        final reviewed = docs.where((d) => d['status'] == 'Reviewed').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryColor, _accentColor]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!_isDarkMode)
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: widget.faceUrl != null && widget.faceUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              height: 100,
                              width: 100,
                              widget.faceUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome Back,",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        // DISPLAY THE LOGGED IN MEMBER'S NAME & ROLE
                        Text(
                          widget.loggedMemberName != null
                              ? "${widget.loggedMemberName} (${widget.loggedMemberRole})"
                              : _universityName ?? "Administrator",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),

            Text(
              "Overview",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            SizedBox(height: 15),

            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard(
                      "Total Applications",
                      total.toString(),
                      Icons.folder_shared,
                      Colors.blueAccent,
                      constraints.maxWidth,
                      crossAxisCount,
                    ),
                    _buildStatCard(
                      "New / Pending",
                      newApps.toString(),
                      Icons.fiber_new,
                      Colors.orange,
                      constraints.maxWidth,
                      crossAxisCount,
                    ),
                    _buildStatCard(
                      "Completed",
                      submitted.toString(),
                      Icons.check_circle,
                      Colors.green,
                      constraints.maxWidth,
                      crossAxisCount,
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 30),

            if (total > 0) ...[
              Text(
                "Status Distribution",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 15),
              Container(
                height: 350,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!_isDarkMode)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            _buildPieSection(newApps, "New", Colors.orange),
                            _buildPieSection(reviewed, "Reviewed", Colors.blue),
                            _buildPieSection(
                              submitted,
                              "Submitted",
                              Colors.green,
                            ),
                            _buildPieSection(rejected, "Rejected", Colors.red),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem("New", Colors.orange, newApps),
                          _buildLegendItem("Reviewed", Colors.blue, reviewed),
                          _buildLegendItem(
                            "Submitted",
                            Colors.green,
                            submitted,
                          ),
                          _buildLegendItem("Rejected", Colors.red, rejected),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                padding: EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "No application data available for charts.",
                    style: TextStyle(color: _subTextColor),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  PieChartSectionData _buildPieSection(int count, String title, Color color) {
    final double value = count.toDouble();
    return PieChartSectionData(
      color: color,
      value: value,
      title: value > 0 ? '${value.toInt()}' : '',
      radius: 50,
      titleStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          SizedBox(width: 8),
          Text("$title ($count)", style: TextStyle(color: _subTextColor)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
    int count,
  ) {
    return Container(
      width: count == 3 ? (width - 40) / 3 : width,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: _subTextColor, fontSize: 14)),
              SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsTableTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tactso_branches')
          .doc(_currentuid)
          .collection('application_requests')
          .orderBy('submissionDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return Center(
            child: Text(
              "No applications",
              style: TextStyle(color: _subTextColor),
            ),
          );
        return Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(
                  label: Text("Student", style: TextStyle(color: _textColor)),
                ),
                DataColumn(
                  label: Text("Status", style: TextStyle(color: _textColor)),
                ),
                DataColumn(
                  label: Text("Action", style: TextStyle(color: _textColor)),
                ),
              ],
              rows: snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        data['applicationDetails']['fullName'] ?? 'Unknown',
                        style: TextStyle(color: _textColor),
                      ),
                    ),
                    DataCell(
                      _buildStatusChip(data['status'] ?? 'New', doc.id, data),
                    ),
                    DataCell(
                      ElevatedButton(
                        child: Text("View Docs"),
                        onPressed: () => _showDocsDialog(
                          context,
                          data['applicationDetails']['documents'],
                          studentName: data['applicationDetails']['fullName'],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(
    String currentStatus,
    String docId,
    Map<String, dynamic> data,
  ) {
    return DropdownButton<String>(
      value: _applicationStatuses.contains(currentStatus)
          ? currentStatus
          : null,
      dropdownColor: _cardColor,
      style: TextStyle(color: _primaryColor),
      items: _applicationStatuses
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) => _updateApplicationStatus(
        applicationId: docId,
        newStatus: val!,
        applicationData: data,
        globalApplicationRequestId: data['globalApplicationRequestId'],
        userId: data['userId'],
      ),
    );
  }

  void _showDocsDialog(
    BuildContext context,
    dynamic docs, {
    required String studentName,
  }) {
    if (docs == null || docs is! Map) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text("Docs: $studentName", style: TextStyle(color: _textColor)),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: docs.entries
                .map(
                  (e) => ListTile(
                    title: Text(e.key),
                    onTap: () => _launchUrl(e.value),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCommitteeTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Committee Members (Max 5)",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
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
                  Expanded(
                    child: Column(
                      children: [
                        _styledTextField(
                          controller: _committeeNameController,
                          label: "Name",
                          icon: Icons.person,
                        ),
                        SizedBox(height: 10),
                        _styledTextField(
                          controller: _committeeEmailController,
                          label: "Email",
                          icon: Icons.email,
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
                      dropdownColor: _cardColor,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _inputFillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                        : _addCommitteeMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      minimumSize: Size(120, 50),
                    ),
                    child: _isUploadingCommittee
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("Add"),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 30),
        FutureBuilder<QuerySnapshot>(
          future: _committeeFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CupertinoActivityIndicator();
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
                var data =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
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
                              data['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                            Text(
                              data['role'],
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
                          snapshot.data!.docs[index].id,
                          data['faceUrl'],
                          data['name'],
                          data['role'],
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
    );
  }

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
      ),
    );
  }
}
