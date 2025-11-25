// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // REQUIRED for Face Upload
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb and defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // REQUIRED for Face Picking
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';
// Assuming Upcoming_events_card is used elsewhere or just imported
import 'package:ttact/Components/Upcoming_events_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' as io; // Platform safe file handling

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 900.0;

// 1. Check if we should use Apple-style widgets (Mac or iOS), even on Web.
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

  String? _universityName;
  String? _adminEmail;
  String? _currentuid;
  bool _isLoadingUniversityData = true;

  // Future for Committee Members
  Future<QuerySnapshot>? _committeeFuture;

  // Navigation
  int _selectedIndex = 0;

  // --- COMMITTEE STATE ---
  final TextEditingController _committeeNameController =
      TextEditingController();
  final TextEditingController _committeeEmailController =
      TextEditingController();
  String? _selectedRole;
  XFile? _committeeFaceImage;
  bool _isUploadingCommittee = false;

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

  // Helper to fetch committee members
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

      // Trigger the initial fetch
      _fetchCommitteeMembers();

      try {
        DocumentSnapshot universityDoc = await _firestore
            .collection('tactso_branches')
            .doc(_currentuid)
            .get();

        if (universityDoc.exists) {
          setState(() {
            _universityName =
                universityDoc['educationOfficerName'] ?? 'University Admin';
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

  // --- COMMITTEE IMAGE PICKER ---

  Future<void> _pickCommitteeImage() async {
    print("Picking image..."); // Debug print
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _committeeFaceImage = picked;
        });
        print("Image picked: ${picked.path}");
      }
    } catch (e) {
      print("Error picking image: $e");
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

  // --- ADD COMMITTEE MEMBER LOGIC ---

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

    // Limit Check
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

      // REFRESH THE LIST
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

    // REFRESH THE LIST
    _fetchCommitteeMembers();

    Api().showMessage(context, "Deleted", "Member removed.", Colors.grey);
  }

  // --- STATUS UPDATE ---
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
  // === MAIN LAYOUT SWITCHER ===
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) return _buildLoginRedirect(context);
    if (_isLoadingUniversityData || _currentuid == null) {
      return Scaffold(
        backgroundColor: ThemeData.dark().scaffoldBackgroundColor,
        body: Center(
          child: isAppleStyle
              ? CupertinoActivityIndicator()
              : CircularProgressIndicator(),
        ),
      );
    }

    // 1. Content Widget
    Widget contentBody = Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _selectedIndex == 0
            ? _buildDashboardTab(context)
            : _selectedIndex == 1
            ? _buildApplicationsTableTab(context)
            : _buildCommitteeTab(context),
      ),
    );

    final double screenWidth = MediaQuery.of(context).size.width;

    // ----------------------------------------------------------------------
    // CASE 1: DESKTOP / WIDE SCREEN (Sidebar)
    // ----------------------------------------------------------------------
    if (screenWidth >= _desktopBreakpoint) {
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permanent Sidebar
            Container(
              width: 260,
              color: Theme.of(context).primaryColor,
              child: _buildDrawerContent(context, isSidebar: true),
            ),
            Expanded(
              child: Scaffold(
                appBar: isAppleStyle
                    ? CupertinoNavigationBar(
                        middle: Text(
                          _universityName ?? "Admin",
                          style: TextStyle(
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                      )
                    : AppBar(
                        title: Text(_universityName ?? "Admin"),
                        automaticallyImplyLeading: false,
                        elevation: 0,
                      ),
                body: SingleChildScrollView(child: contentBody),
              ),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------------------
    // CASE 2: WEB - SMALL SCREEN (Drawer)
    // ----------------------------------------------------------------------
    if (kIsWeb) {
      // If we are here, screenWidth is < _desktopBreakpoint
      return Scaffold(
        appBar: AppBar(
          title: Text(_universityName ?? 'Admin'),
          automaticallyImplyLeading: true,
        ),
        drawer: Drawer(child: _buildDrawerContent(context, isSidebar: false)),
        body: SingleChildScrollView(child: contentBody),
      );
    }

    // ----------------------------------------------------------------------
    // CASE 3: NATIVE MOBILE (iOS - Bottom Tabs)
    // ----------------------------------------------------------------------
    if (isAppleStyle) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.graph_circle),
              label: 'Dash',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.doc_text),
              label: 'Apps',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.group),
              label: 'Team',
            ),
          ],
        ),
        tabBuilder: (ctx, index) {
          // We don't set state here to avoid loops, we just render
          Widget tabContent;
          if (index == 0)
            tabContent = _buildDashboardTab(context);
          else if (index == 1)
            tabContent = _buildApplicationsTableTab(context);
          else
            tabContent = _buildCommitteeTab(context);

          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text(_universityName ?? 'Admin'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.square_arrow_right),
                onPressed: _logout,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(padding: EdgeInsets.all(16), child: tabContent),
              ),
            ),
          );
        },
      );
    }

    // ----------------------------------------------------------------------
    // CASE 4: NATIVE MOBILE (Android - Bottom Nav)
    // ----------------------------------------------------------------------
    // This handles Android apps (not web)
    return Scaffold(
      appBar: AppBar(
        title: Text(_universityName ?? 'Admin'),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
      ),
      body: SingleChildScrollView(child: contentBody),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dash'),
          NavigationDestination(icon: Icon(Icons.table_chart), label: 'Apps'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Team'),
        ],
      ),
    );
  }

  // --- DRAWER / SIDEBAR CONTENT ---
  Widget _buildDrawerContent(BuildContext context, {required bool isSidebar}) {
    final color = isSidebar ? Colors.white : Colors.black87;

    return Column(
      children: [
        if (isSidebar) SizedBox(height: 50),
        if (!isSidebar)
          UserAccountsDrawerHeader(
            accountName: Text(_universityName ?? 'Admin'),
            accountEmail: Text(_adminEmail ?? ''),
            currentAccountPicture: CircleAvatar(child: Icon(Icons.school)),
          ),
        if (isSidebar) ...[
          Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
          SizedBox(height: 10),
          Text(
            "TACTSO ADMIN",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 40),
        ],

        _drawerItem(Icons.dashboard, "Dashboard", 0, color, isSidebar),
        _drawerItem(Icons.table_chart, "Applications", 1, color, isSidebar),
        _drawerItem(Icons.group, "Committee", 2, color, isSidebar),

        Spacer(),
        ListTile(
          leading: Icon(
            Icons.logout,
            color: isSidebar ? Colors.white70 : Colors.grey,
          ),
          title: Text(
            "Logout",
            style: TextStyle(color: isSidebar ? Colors.white70 : Colors.black),
          ),
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
    bool isSidebar,
  ) {
    bool isActive = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      selected: isActive,
      selectedTileColor: isSidebar
          ? Colors.white.withOpacity(0.2)
          : Colors.blue.withOpacity(0.1),
      onTap: () {
        setState(() => _selectedIndex = index);
        if (!isSidebar) Navigator.pop(context); // Close Drawer if on mobile
      },
    );
  }

  // --- WIDGET GENERATORS (Platform Aware) ---

  Widget _platformTextField({
    required TextEditingController controller,
    required String placeholder,
    bool isPassword = false,
    IconData? icon,
  }) {
    if (isAppleStyle) {
      return CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: isPassword,
        padding: EdgeInsets.all(12),
        prefix: icon != null
            ? Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(icon, color: CupertinoColors.systemGrey),
              )
            : null,
        decoration: BoxDecoration(
          color: CupertinoColors.extraLightBackgroundGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CupertinoColors.systemGrey4),
        ),
      );
    } else {
      return TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: placeholder,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );
    }
  }

  Widget _platformButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required BuildContext context,
    Color? color,
  }) {
    if (isAppleStyle) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, size: 20), SizedBox(width: 8), Text(label)],
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }
  }

  // --- TAB 1: DASHBOARD ---
  Widget _buildDashboardTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Colors.blue.shade50,
          child: ListTile(
            leading: Icon(Icons.verified_user, color: Colors.blue),
            title: Text(
              "Welcome Back",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_adminEmail ?? ''),
          ),
        ),
        SizedBox(height: 20),
        Text(
          "Metrics",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Divider(),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildMetricCard(
              context,
              "Total",
              Colors.blue,
              Icons.assignment,
              _firestore
                  .collection('tactso_branches')
                  .doc(_currentuid)
                  .collection('application_requests')
                  .get(),
              (snapshot) => snapshot.hasData ? snapshot.data!.size : 0,
              isDesktop:
                  MediaQuery.of(context).size.width >= _desktopBreakpoint,
            ),
            _buildMetricCard(
              context,
              "New",
              Colors.orange,
              Icons.fiber_new,
              _firestore
                  .collection('tactso_branches')
                  .doc(_currentuid)
                  .collection('application_requests')
                  .where('status', isEqualTo: 'New')
                  .get(),
              (snapshot) => snapshot.hasData ? snapshot.data!.size : 0,
              isDesktop:
                  MediaQuery.of(context).size.width >= _desktopBreakpoint,
            ),
            _buildMetricCard(
              context,
              "Accepted",
              Colors.green,
              Icons.check_circle,
              _firestore
                  .collection('tactso_branches')
                  .doc(_currentuid)
                  .collection('application_requests')
                  .where('status', isEqualTo: 'Application Submitted')
                  .get(),
              (snapshot) => snapshot.hasData ? snapshot.data!.size : 0,
              isDesktop:
                  MediaQuery.of(context).size.width >= _desktopBreakpoint,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    Color color,
    IconData icon,
    Future<QuerySnapshot> future,
    int Function(AsyncSnapshot<QuerySnapshot> snapshot) countExtractor, {
    required bool isDesktop,
  }) {
    final double cardWidth = isDesktop
        ? (MediaQuery.of(context).size.width * 0.45)
        : double.infinity;

    return FutureBuilder<QuerySnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: EdgeInsets.only(bottom: 16.0),
            child: SizedBox(
              width: isDesktop
                  ? (_desktopBreakpoint / 2) - 32
                  : double.infinity,
              height: 100,
              child: Center(child: CupertinoActivityIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            color: color.withOpacity(0.1),
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final count = countExtractor(snapshot);

        return Card(
          color: color.withOpacity(0.1),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            // Use the calculated width if desktop, otherwise fill
            width: isDesktop ? (_desktopBreakpoint / 2) - 32 : double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: APPLICATIONS TABLE ---
  Widget _buildApplicationsTableTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Applications",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tactso_branches')
              .doc(_currentuid)
              .collection('application_requests')
              .orderBy('submissionDate', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CupertinoActivityIndicator();
            if (snapshot.data!.docs.isEmpty) return Text("No applications.");

            // DOUBLE SCROLL VIEW FOR RESPONSIVENESS
            return Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("Student")),
                      DataColumn(label: Text("Program")),
                      DataColumn(label: Text("Date")),
                      DataColumn(label: Text("Status")),
                      DataColumn(label: Text("Docs")),
                    ],
                    rows: snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      var details = data['applicationDetails'] ?? {};
                      String status = data['status'] ?? 'New';

                      return DataRow(
                        cells: [
                          DataCell(Text(details['fullName'] ?? 'Unknown')),
                          DataCell(Text(details['primaryProgram'] ?? '-')),
                          DataCell(
                            Text(
                              data['submissionDate'] != null
                                  ? DateFormat('MM/dd').format(
                                      (data['submissionDate'] as Timestamp)
                                          .toDate(),
                                    )
                                  : '-',
                            ),
                          ),
                          DataCell(_buildStatusDropdown(status, doc.id, data)),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.description, color: Colors.blue),
                              onPressed: () => _showDocsDialog(
                                context,
                                details['documents'],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Status Dropdown helper to support iOS style in future if needed
  Widget _buildStatusDropdown(
    String currentStatus,
    String docId,
    Map<String, dynamic> data,
  ) {
    // For table cells, standard DropdownButton is usually best even on Mac/Web
    // because CupertinoPicker is too large for a table cell.
    return DropdownButton<String>(
      value: _applicationStatuses.contains(currentStatus)
          ? currentStatus
          : null,
      hint: Text(currentStatus),
      underline: SizedBox(),
      items: _applicationStatuses.map((s) {
        return DropdownMenuItem(value: s, child: Text(s));
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
    );
  }

  void _showDocsDialog(BuildContext context, dynamic docs) {
    if (docs == null || docs is! Map) {
      Api().showMessage(context, "No Docs", "None attached", Colors.grey);
      return;
    }

    final availableDocs = docs.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    if (availableDocs.isEmpty) {
      Api().showMessage(
        context,
        "Empty",
        "No valid document links",
        Colors.grey,
      );
      return;
    }

    // Platform aware dialog
    if (isAppleStyle) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text("Documents"),
          content: Column(
            children: availableDocs
                .map(
                  (e) => CupertinoButton(
                    child: Text(e.key.toString()),
                    onPressed: () => _launchUrl(e.value.toString()),
                  ),
                )
                .toList(),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text("Close"),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text("Documents"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableDocs.map((e) {
              return ListTile(
                leading: Icon(Icons.file_open),
                title: Text(e.key.toString().toUpperCase()),
                onTap: () => _launchUrl(e.value.toString()),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text("Close")),
          ],
        ),
      );
    }
  }

  // --- COMMITTEE TAB (USING FUTURE BUILDER) ---
  Widget _buildCommitteeTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Committee (Max 5)",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text("Face Image required for login."),
        SizedBox(height: 20),

        // Add Member Form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------------------------------------------------
                    // CLICKABLE IMAGE CARD
                    // -------------------------------------------------
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickCommitteeImage,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _committeeFaceImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: Colors.grey),
                                    Text(
                                      "Add Face",
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
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
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        children: [
                          _platformTextField(
                            controller: _committeeNameController,
                            placeholder: "Full Name",
                            icon: Icons.person,
                          ),
                          SizedBox(height: 10),
                          _platformTextField(
                            controller: _committeeEmailController,
                            placeholder: "Email",
                            icon: Icons.email,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Portfolio",
                    border: OutlineInputBorder(),
                  ),
                  items: _committeeRoles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRole = v),
                ),
                SizedBox(height: 10),
                _isUploadingCommittee
                    ? CircularProgressIndicator()
                    : _platformButton(
                        onPressed: _addCommitteeMember,
                        label: "Add Member",
                        icon: Icons.add,
                        context: context,
                      ),
              ],
            ),
          ),
        ),

        SizedBox(height: 20),
        Divider(),

        // LIST (USING FUTURE BUILDER)
        FutureBuilder<QuerySnapshot>(
          future: _committeeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("No committee members found."),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(data['faceUrl'] ?? ''),
                      child: data['faceUrl'] == null
                          ? Icon(Icons.person)
                          : null,
                    ),
                    title: Text(data['name'] ?? 'Unknown'),
                    subtitle: Text("${data['role']} • ${data['email']}"),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _deleteCommitteeMember(doc.id, data['faceUrl']),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoginRedirect(BuildContext context) {
    return Scaffold(body: Center(child: Text("Please Log In")));
  }
}
