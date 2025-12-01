// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED: fl_chart: ^0.65.0
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AuditService.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' as io;

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1100.0;

bool get isAppleStyle {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class TactsoBranchesApplications extends StatefulWidget {
  const TactsoBranchesApplications({super.key});

  @override
  State<TactsoBranchesApplications> createState() =>
      _TactsoBranchesApplicationsState();
}

class _TactsoBranchesApplicationsState
    extends State<TactsoBranchesApplications> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // --- THEME STATE ---
  bool _isDarkMode = false;

  // --- DATA STATE ---
  String? _universityName;
  String? _adminEmail;
  String? _currentuid;
  bool _isLoadingUniversityData = true;

  // Future for Committee Members
  Future<QuerySnapshot>? _committeeFuture;

  // Navigation
  int _selectedIndex = 0;

  // --- INPUT CONTROLLERS ---
  final TextEditingController _committeeNameController =
      TextEditingController();
  final TextEditingController _committeeEmailController =
      TextEditingController();
  String? _selectedRole;
  XFile? _committeeFaceImage;
  bool _isUploadingCommittee = false;
  String? _universityLogoUrl;
  String? _universityCommitteeFace;

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

  String? _selectedStatus;
  String? _committeeName;

  // --- COLOR PALETTE (Dynamic) ---
  final Color _primaryColor = const Color(0xFF1E3A8A); // Deep Blue
  final Color _accentColor = const Color(0xFF3B82F6); // Bright Blue

  // Dynamic Colors based on Mode
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
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

  // --- FIXED DATA LOADING FUNCTION ---
  Future<void> _loadUniversityData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _currentuid = currentUser.uid;
      _adminEmail = currentUser.email;

      _fetchCommitteeMembers();

      try {
        // 1. Get QuerySnapshot
        QuerySnapshot querySnapshot = await _firestore
            .collection('tactso_branches')
            .where('uid', isEqualTo: _currentuid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // 2. Extract Data from first doc
          var data = querySnapshot.docs.first.data() as Map<String, dynamic>;

          setState(() {
            _universityName = data['universityName'] ?? 'University Admin';
            _committeeName = data['educationOfficerName'] ?? 'Committee';
            _universityCommitteeFace = data['educationOfficerFaceUrl'];

            // 3. Fix: Handle Array vs String for imageUrl
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
    setState(() {
      _isLoadingUniversityData = false;
    });
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // --- LOGIC ---
  Future<void> _pickCommitteeImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _committeeFaceImage = picked;
        });
      }
    } catch (e) {
      Api().showMessage(
        context,
        "Error",
        "Could not pick image: $e",
        Colors.red,
      );
    }
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

  Future<void> _addCommitteeMember() async {
    if (_committeeNameController.text.isEmpty ||
        _committeeEmailController.text.isEmpty ||
        _selectedRole == null) {
      Api().showMessage(
        context,
        "Missing Info",
        "Please fill all text fields.",
        Colors.orange,
      );
      return;
    }

    if (_committeeFaceImage == null) {
      Api().showMessage(
        context,
        "Face Required",
        "Please upload a face image for biometric login.",
        Colors.red,
      );
      return;
    }

    QuerySnapshot existingMembers = await _firestore
        .collection('tactso_branches')
        .doc(_currentuid)
        .collection('committee_members')
        .get();

    if (existingMembers.docs.length >= 4) {
      Api().showMessage(
        context,
        "Limit Reached",
        "Maximum 5 members allowed (1 Head + 4 Committee).",
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

      await _firestore.collection('tactso_branches').doc(_currentuid).update({
        'authorizedUserFaceUrls': FieldValue.arrayUnion([faceUrl]),
      });

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

  Future<void> _deleteCommitteeMember(String docId, String? faceUrl) async {
    await _firestore
        .collection('tactso_branches')
        .doc(_currentuid)
        .collection('committee_members')
        .doc(docId)
        .delete();

    if (faceUrl != null) {
      await _firestore.collection('tactso_branches').doc(_currentuid).update({
        'authorizedUserFaceUrls': FieldValue.arrayRemove([faceUrl]),
      });
    }
    _fetchCommitteeMembers();
    Api().showMessage(context, "Deleted", "Member removed.", Colors.grey);
  }

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
            DocumentReference userSpecificAppRef =
                userAppsSnapshot.docs.first.reference;
            transaction.update(userSpecificAppRef, {'status': newStatus});
          }
        }
      });

      if (applicationData != null) {
        final details = applicationData['applicationDetails'] ?? {};
        final studentEmail = details['email'];
        if (studentEmail != null) {
          await Api().sendEmail(
            studentEmail,
            'Status Update: $newStatus',
            '<p>Your status is now: $newStatus</p>',
            context,
          );
        }
      }

      String studentName = "Unknown Student";
      if (applicationData != null &&
          applicationData['applicationDetails'] != null) {
        studentName =
            applicationData['applicationDetails']['fullName'] ??
            "Unknown Student";
      }

      await AuditService.logAction(
        action: "UPDATE_STATUS",
        details: "Changed status to $newStatus",
        referenceId: applicationId,
        universityName: _universityName,
        studentName: studentName,
        committeeName: _committeeName,
        universityCommitteeFace: _universityCommitteeFace,
        universityLogo: _universityLogoUrl,
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
    if (!await launchUrl(Uri.parse(url))) {
      Api().showMessage(context, 'Error', 'Invalid URL', Colors.red);
    }
  }

  // ===========================================================================
  // === UI & DESIGN ===
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) return _buildLoginRedirect(context);
    if (_isLoadingUniversityData || _currentuid == null) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: isAppleStyle
              ? CupertinoActivityIndicator()
              : CircularProgressIndicator(),
        ),
      );
    }

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

    // DESKTOP
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

    // WEB / TABLET
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

    // MOBILE
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
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return IconThemeData(color: _primaryColor);
            }
            return IconThemeData(color: _subTextColor);
          }),
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
          onPressed: () {
            setState(() {
              _isDarkMode = !_isDarkMode;
            });
          },
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

  // --- DRAWER ---
  Widget _buildDrawerContent(BuildContext context, {required bool isSidebar}) {
    final color = isSidebar
        ? (_isDarkMode ? Colors.white70 : Colors.black54)
        : _textColor;
    final activeColor = _primaryColor;

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
        _drawerItem(
          Icons.dashboard_rounded,
          "Dashboard",
          0,
          color,
          activeColor,
        ),
        _drawerItem(
          Icons.table_chart_rounded,
          "Applications",
          1,
          color,
          activeColor,
        ),
        _drawerItem(Icons.groups_rounded, "Committee", 2, color, activeColor),
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

  Widget _drawerItem(
    IconData icon,
    String title,
    int index,
    Color color,
    Color activeColor,
  ) {
    bool isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
        leading: Icon(icon, color: isActive ? activeColor : color),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? activeColor : color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (Scaffold.of(context).hasDrawer &&
              Scaffold.of(context).isDrawerOpen) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // --- TAB 1: DASHBOARD ---
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
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back,",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _universityName ?? "Administrator",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

  // --- TAB 2: APPLICATIONS TABLE ---
  Widget _buildApplicationsTableTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Applications Database",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        SizedBox(height: 5),
        Text(
          "Manage status and review documents",
          style: TextStyle(color: _subTextColor),
        ),
        SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tactso_branches')
              .doc(_currentuid)
              .collection('application_requests')
              .orderBy('submissionDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CupertinoActivityIndicator();
            if (snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 50, color: _subTextColor),
                    Text(
                      "No applications received yet.",
                      style: TextStyle(color: _subTextColor),
                    ),
                  ],
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!_isDarkMode)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                ],
              ),
              padding: EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        _primaryColor.withOpacity(0.05),
                      ),
                      dataRowHeight: 70,
                      columns: [
                        DataColumn(
                          label: Text(
                            "Student",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Program",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Date",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Status",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            "Action",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                        ),
                      ],
                      rows: snapshot.data!.docs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        var details = data['applicationDetails'] ?? {};
                        String status = data['status'] ?? 'New';
                        String studentName =
                            details['fullName'] ?? 'Unknown Student';

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: _isDarkMode
                                        ? Colors.grey[700]
                                        : Colors.grey[200],
                                    child: Text(
                                      studentName[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    studentName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                details['primaryProgram'] ?? '-',
                                style: TextStyle(color: _textColor),
                              ),
                            ),
                            DataCell(
                              Text(
                                data['submissionDate'] != null
                                    ? DateFormat('MMM dd, yyyy').format(
                                        (data['submissionDate'] as Timestamp)
                                            .toDate(),
                                      )
                                    : '-',
                                style: TextStyle(color: _textColor),
                              ),
                            ),
                            DataCell(_buildStatusChip(status, doc.id, data)),
                            DataCell(
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _cardColor,
                                  foregroundColor: _primaryColor,
                                  elevation: 0,
                                  side: BorderSide(
                                    color: _primaryColor.withOpacity(0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(Icons.file_present, size: 16),
                                label: Text("View Docs"),
                                onPressed: () => _showDocsDialog(
                                  context,
                                  details['documents'],
                                  studentName: studentName,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    String currentStatus,
    String docId,
    Map<String, dynamic> data,
  ) {
    Color statusColor;
    switch (currentStatus) {
      case 'New':
        statusColor = Colors.orange;
        break;
      case 'Application Submitted':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _applicationStatuses.contains(currentStatus)
              ? currentStatus
              : null,
          isDense: true,
          dropdownColor: _cardColor,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          icon: Icon(Icons.arrow_drop_down, color: statusColor),
          items: _applicationStatuses.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(s, style: TextStyle(color: _textColor)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null)
              _updateApplicationStatus(
                applicationId: docId,
                newStatus: val,
                applicationData: data,
                globalApplicationRequestId: data['globalApplicationRequestId'],
                userId: data['userId'],
              );
          },
        ),
      ),
    );
  }

  void _showDocsDialog(
    BuildContext context,
    dynamic docs, {
    required String studentName,
  }) {
    if (docs == null || docs is! Map) {
      Api().showMessage(context, "No Docs", "None attached", Colors.grey);
      return;
    }

    final availableDocs = docs.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Documents: $studentName",
          style: TextStyle(color: _textColor),
        ),
        content: SizedBox(
          width: 400,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: availableDocs.length,
            separatorBuilder: (context, index) => Divider(color: _borderColor),
            itemBuilder: (context, index) {
              var e = availableDocs[index];
              return ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.picture_as_pdf, color: Colors.blue),
                ),
                title: Text(
                  e.key.toString().toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                trailing: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: _subTextColor,
                ),
                onTap: () async {
                  _launchUrl(e.value.toString());
                  await AuditService.logAction(
                    action: "VIEW_DOCUMENT",
                    details: "Viewed ${e.key.toString().toUpperCase()}",
                    universityName: _universityName,
                    studentName: studentName,
                    committeeName: _committeeName,
                    universityCommitteeFace: _universityCommitteeFace,
                    universityLogo: _universityLogoUrl,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text("Close")),
        ],
      ),
    );
  }

  // --- TAB 3: COMMITTEE ---
  Widget _buildCommitteeTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Committee Members",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                Text(
                  "Manage authorized access (Max 5)",
                  style: TextStyle(color: _subTextColor),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 20),

        // ADD MEMBER CARD
        Container(
          padding: EdgeInsets.all(24),
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
                  // Photo Picker
                  InkWell(
                    onTap: _pickCommitteeImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _inputFillColor,
                        border: Border.all(color: _borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _committeeFaceImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: _subTextColor),
                                SizedBox(height: 5),
                                Text(
                                  "Upload Face",
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
                          label: "Full Name",
                          icon: Icons.person_outline,
                        ),
                        SizedBox(height: 15),
                        _styledTextField(
                          controller: _committeeEmailController,
                          label: "Email Address",
                          icon: Icons.email_outlined,
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
                        labelText: "Portfolio / Role",
                        labelStyle: TextStyle(color: _subTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor),
                        ),
                        filled: true,
                        fillColor: _inputFillColor,
                      ),
                      style: TextStyle(color: _textColor),
                      items: _committeeRoles
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRole = v),
                    ),
                  ),
                  SizedBox(width: 15),
                  SizedBox(
                    height: 55,
                    width: 150,
                    child: ElevatedButton(
                      onPressed: _isUploadingCommittee
                          ? null
                          : _addCommitteeMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
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
                          : Text("Add Member"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 30),

        // MEMBER LIST
        FutureBuilder<QuerySnapshot>(
          future: _committeeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CupertinoActivityIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "No committee members found.",
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
                var data =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                String docId = snapshot.data!.docs[index].id;

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
                            onError: (e, s) =>
                                Icon(Icons.person, color: _subTextColor),
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
                                fontSize: 15,
                                color: _textColor,
                              ),
                            ),
                            Text(
                              data['role'] ?? 'Member',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              data['email'] ?? '',
                              style: TextStyle(
                                color: _subTextColor,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () =>
                            _deleteCommitteeMember(docId, data['faceUrl']),
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
        labelStyle: TextStyle(color: _subTextColor),
        prefixIcon: Icon(icon, color: _subTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor),
        ),
        filled: true,
        fillColor: _inputFillColor,
      ),
    );
  }

  Widget _buildLoginRedirect(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Session Expired. Please Log In.",
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
