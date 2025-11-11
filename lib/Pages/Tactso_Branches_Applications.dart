// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Ensure Material is imported for Material widgets
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // For opening URLs (documents)

// Import foundation for kIsWeb check
import 'package:flutter/foundation.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 1000.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 800; // Adjusted breakpoint for admin console

// Helper to check for mobile web (used for conditional navigation)
bool _isMobileWeb(BuildContext context) => kIsWeb && !isLargeScreen(context);
// --------------------------

// Placeholder for your Api utility class (if needed for messages)
class Api {
  void showMessage(
    BuildContext context,
    String title,
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (message.isNotEmpty)
              Text(message, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showLoading(BuildContext context) {
    // Placeholder for loading functionality used in previous snippets
    // In this context, the loading is often handled by state or streams.
  }
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

  String? _universityName;
  String? _adminEmail; // Store admin email for the welcome banner
  String? _currentuid;
  bool _isLoadingUniversityData = true;

  final List<String> _applicationStatuses = [
    'New',
    'Reviewed',
    'Application Submitted',
  ];

  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadUniversityData();
  
   Future.delayed(Duration.zero, _checkAuthorization);
  }
  
  bool _isAuthorized = false;
  Future<void> _checkAuthorization() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // --- 1. Authentication Check (Is the user logged in?) ---
    if (user == null) {
      if (mounted) {
        // Not logged in: Redirect to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // --- 2. Role Check (Does the user have the 'Admin' role?) ---
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('tactso_branches')
          .doc(user.uid)
          .get();

      final String uid = userDoc.data()?['uid'] ?? '';

      if (uid == user.uid) {
        // Access granted!
        setState(() {
          _isAuthorized = true;
        });
      }   else {
        // Logged in, but NOT an Admin: Redirect to login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) { 
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _loadUniversityData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _currentuid = currentUser.uid;
      _adminEmail = currentUser.email; // Get email from Auth user

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
        if (mounted) {}
      }
    }
    setState(() {
      _isLoadingUniversityData = false;
    });
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      // NOTE: Assuming '/login' is the route name for your login page
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _updateApplicationStatus({
    required String applicationId,
    required String newStatus,
    String? globalApplicationRequestId,
    String? userId,
  }) async {
    if (_currentuid == null) {
      Api().showMessage(
        context,
        'Error',
        'University UID not found.',
        CupertinoColors.systemRed,
      );
      return;
    }

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

      if (mounted) {
        Api().showMessage(
          context,
          'Status Updated!',
          'Application status changed to "$newStatus".',
          CupertinoColors.activeGreen,
        );
        // Manually trigger a rebuild to update streams immediately
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Api().showMessage(
          context,
          'Update Failed',
          'Could not update status: $e',
          CupertinoColors.systemRed,
        );
      }
    }
  }

  // Function to launch URL for document download
  Future<void> _launchUrl(String url) async {
    try {
      // Use launchUrl which is platform-safe
      if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        // Success
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
        if (mounted) {
          Api().showMessage(
            context,
            'Error',
            'Could not open document. Invalid URL or no app to handle it.',
            CupertinoColors.systemRed,
          );
        }
    }
  }

  void _showApplicationDetails(
    Map<String, dynamic> applicationData,
    String applicationId,
  ) {
    String currentStatus = applicationData['status'] ?? 'New';
    _selectedStatus = currentStatus;

    final applicationDetails =
        applicationData['applicationDetails'] as Map<String, dynamic>? ?? {};

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context);
        return Center(
          // Constrain the modal width for desktop viewing
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateInPopup) {
                return CupertinoActionSheet(
                  title: Text(
                    'Application Details for ${applicationDetails['fullName'] ?? 'Applicant'}',
                    style: TextStyle(
                      color: colorScheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  message: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display all static applicant details
                        _buildDetailRow(
                          'Full Name:',
                          applicationDetails['fullName'],
                        ),
                        _buildDetailRow('Email:', applicationDetails['email']),
                        _buildDetailRow('Phone:', applicationDetails['phone']),
                        _buildDetailRow(
                          'Physical Address:',
                          applicationDetails['physicalAddress'],
                        ),
                        _buildDetailRow(
                          'Graduation Year:',
                          applicationDetails['yearOfCompletion'],
                        ),
                        _buildDetailRow(
                          'Highest Qualification:',
                          applicationDetails['highestQualification'],
                        ),
                        _buildDetailRow(
                          'Primary Program:',
                          applicationDetails['primaryProgram'],
                        ),
                        _buildDetailRow(
                          'Secondary Program:',
                          applicationDetails['secondChoiceProgram'],
                        ),
                        _buildDetailRow(
                          'Third Program:',
                          applicationDetails['thirdChoiceProgram'],
                        ),
                        _buildDetailRow(
                          'Applying for Residence:',
                          (applicationDetails['applyingForResidence'] ?? false)
                              ? 'Yes'
                              : 'No',
                        ),
                        _buildDetailRow(
                          'Applying for Funding:',
                          (applicationDetails['applyingForFunding'] ?? false)
                              ? 'Yes'
                              : 'No',
                        ),
                        _buildDetailRow(
                          'Parent 1 Name:',
                          applicationDetails['parent1Name'],
                        ),
                        _buildDetailRow(
                          'Parent 1 Occupation:',
                          applicationDetails['parent1Occupation'],
                        ),
                        _buildDetailRow(
                          'Parent 1 Income:',
                          applicationDetails['parent1Income'],
                        ),
                        _buildDetailRow(
                          'Parent 2 Name:',
                          applicationDetails['parent2Name'],
                        ),
                        _buildDetailRow(
                          'Parent 2 Occupation:',
                          applicationDetails['parent2Occupation'],
                        ),
                        _buildDetailRow(
                          'Parent 2 Income:',
                          applicationDetails['parent2Income'],
                        ),
                        _buildDetailRow('Current Status:', currentStatus),
                        _buildDetailRow(
                          'Submitted On:',
                          DateFormat('MMM dd, yyyy HH:mm').format(
                            (applicationData['submissionDate'] as Timestamp)
                                .toDate(),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Text(
                          'Submitted Documents:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primaryColor,
                          ),
                        ),
                        // Loop through documents
                        if (applicationDetails['documents'] is Map &&
                            (applicationDetails['documents'] as Map).isNotEmpty)
                          ...(applicationDetails['documents'] as Map).entries.map((
                            entry,
                          ) {
                            String docName = entry.key
                                .toString()
                                .replaceAll('_', ' ')
                                .toUpperCase();
                            String docUrl = entry.value.toString();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _launchUrl(docUrl),
                                child: Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.doc_fill,
                                      size: 20,
                                      color: CupertinoColors.activeBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Download $docName',
                                        style: TextStyle(
                                          color: colorScheme.primaryColor,
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList()
                        else
                          Text(
                            'No documents submitted.',
                            style: TextStyle(color: colorScheme.primaryColor),
                          ),

                        const SizedBox(height: 16),
                        Text(
                          'Update Status:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primaryColor,
                          ),
                        ),
                        // Status Dropdown
                        Material(
                          color: Colors.transparent, // Important for blending with Cupertino sheet
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: CupertinoColors.systemGrey4,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedStatus,
                                hint: const Text('Select Status'),
                                items: _applicationStatuses.map((String status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setStateInPopup(() {
                                    _selectedStatus = newValue;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: <CupertinoActionSheetAction>[
                    CupertinoActionSheetAction(
                      child: Text(
                        'Update Status',
                        style: TextStyle(
                          color: colorScheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        if (_selectedStatus != null &&
                            _selectedStatus!.isNotEmpty) {
                          _updateApplicationStatus(
                            applicationId: applicationId,
                            newStatus: _selectedStatus!,
                            globalApplicationRequestId:
                                applicationData['globalApplicationRequestId'],
                            userId: applicationData['userId'],
                          );
                          Navigator.pop(context); // Close after updating
                        } else {
                          Api().showMessage(
                            context,
                            'Input Error',
                            'Please select a status.',
                            CupertinoColors.systemOrange,
                          );
                        }
                      },
                    ),
                    CupertinoActionSheetAction(
                      isDestructiveAction: true,
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: colorScheme.primaryColorDark),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    String displayValue = (value == null || (value is String && value.isEmpty))
        ? 'N/A'
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Slightly wider for labels
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(displayValue)),
        ],
      ),
    );
  }

  // --- NEW: Custom Widget for the Welcome Banner ---
  Widget _buildWelcomeBanner(BuildContext context) {
    final color = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: color.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: color.primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back, Admin!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _universityName ?? 'University Admin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(CupertinoIcons.mail_solid, size: 16, color: color.hintColor),
              const SizedBox(width: 5),
              Text(
                _adminEmail ?? 'No Email Found',
                style: TextStyle(fontSize: 14, color: color.hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- End Custom Widget ---

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: color.primaryColor,
          foregroundColor: color.scaffoldBackgroundColor,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'You must be logged in as a university administrator to view this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                CupertinoButton.filled(
                  onPressed: () {
                    // NOTE: This assumes '/login' is the Material route for login
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoadingUniversityData || _currentuid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: color.primaryColor,
          foregroundColor: color.scaffoldBackgroundColor,
        ),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    // Since this page uses CupertinoTabScaffold, we ensure its builder contents
    // are wrapped correctly for desktop/web.
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        // Use a standard BottomNavigationBar approach for small screens
        backgroundColor: color.appBarTheme.backgroundColor,
        activeColor: color.primaryColor, // Use primary color for active tab
        inactiveColor: color.hintColor,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.graph_circle_fill),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_on_clipboard_fill),
            label: 'Applications',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          builder: (BuildContext context) {
            return Scaffold(
              // NOTE: AppBar handles the title, logout, and back button (if available)
              appBar: AppBar(
                title: Text('${_universityName ?? 'University'} Admin Console'),
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                actions: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.square_arrow_right),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  ),
                ],
              ),
              // Wrap the body content in a Center/ConstrainedBox for web/desktop
              body: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
                  child: index == 0
                      ? _buildDashboardTab(context)
                      : _buildApplicationsTab(context),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardTab(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(context), // Welcome Banner

          Text(
            'Application Metrics',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
          ),
          const Divider(height: 20, thickness: 1),

          // Use Wrap for metrics on desktop to show them side-by-side
          Wrap(
            spacing: 16.0,
            runSpacing: 16.0,
            children: [
              _buildMetricCard(
                context,
                'Total Applications Received',
                CupertinoColors.systemBlue,
                CupertinoIcons.collections_solid,
                _firestore
                    .collection('tactso_branches')
                    .doc(_currentuid)
                    .collection('application_requests')
                    .snapshots(),
                (snapshot) => snapshot.data?.docs.length ?? 0,
                isDesktop: isDesktop,
              ),
              _buildMetricCard(
                context,
                'New Applications (Pending Review)',
                CupertinoColors.systemOrange,
                CupertinoIcons.envelope_badge_fill,
                _firestore
                    .collection('tactso_branches')
                    .doc(_currentuid)
                    .collection('application_requests')
                    .where('status', isEqualTo: 'New')
                    .snapshots(),
                (snapshot) => snapshot.data?.docs.length ?? 0,
                isDesktop: isDesktop,
              ),
              _buildMetricCard(
                context,
                'Applications Reviewed',
                CupertinoColors.systemGreen,
                CupertinoIcons.checkmark_shield_fill,
                _firestore
                    .collection('tactso_branches')
                    .doc(_currentuid)
                    .collection('application_requests')
                    .where('status', isEqualTo: 'Reviewed')
                    .snapshots(),
                (snapshot) => snapshot.data?.docs.length ?? 0,
                isDesktop: isDesktop,
              ),
              _buildMetricCard(
                context,
                'Applications Sent to University (Applied)',
                CupertinoColors.systemPurple,
                CupertinoIcons.rocket_fill,
                _firestore
                    .collection('tactso_branches')
                    .doc(_currentuid)
                    .collection('application_requests')
                    .where('status', isEqualTo: 'Application Submitted')
                    .snapshots(),
                (snapshot) => snapshot.data?.docs.length ?? 0,
                isDesktop: isDesktop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helper Widget for Metric Cards (Updated with responsiveness) ---
  Widget _buildMetricCard(
    BuildContext context,
    String title,
    Color color,
    IconData icon,
    Stream<QuerySnapshot> stream,
    int Function(AsyncSnapshot<QuerySnapshot> snapshot) countExtractor, {
    required bool isDesktop,
  }) {
    final double cardWidth = isDesktop
        ? (MediaQuery.of(context).size.width * 0.45) // Closer approximation for two columns within the max width
        : double.infinity;
        
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: EdgeInsets.only(bottom: 16.0),
            child: SizedBox(
              width: isDesktop ? (_desktopContentMaxWidth / 2) - 32 : double.infinity, // Use calculation for a two-column desktop layout
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
            width: isDesktop ? (_desktopContentMaxWidth / 2) - 32 : double.infinity,
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
  // --- End Helper Widget ---

  Widget _buildApplicationsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tactso_branches')
          .doc(_currentuid)
          .collection('application_requests')
          .where('status', whereIn: ['New', 'Reviewed'])
          .orderBy('submissionDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '🎉 All caught up! No new or reviewed applications pending action.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var application = doc.data() as Map<String, dynamic>;
            return _buildApplicationListTile(context, doc.id, application);
          },
        );
      },
    );
  }
  
  // Extracted List Tile Builder for readability
  Widget _buildApplicationListTile(
      BuildContext context, String docId, Map<String, dynamic> application) {
    final color = Theme.of(context);
    var applicationDetails = application['applicationDetails'] as Map<String, dynamic>?;

    if (applicationDetails == null) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Card(
          child: CupertinoListTile(
            title: Text('Invalid Application Data'),
            leading: Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.systemRed,
            ),
          ),
        ),
      );
    }

    String fullName = applicationDetails['fullName'] ?? 'N/A';
    String primaryProgram = applicationDetails['primaryProgram'] ?? 'N/A';
    String currentStatus = application['status'] ?? 'N/A';
    Timestamp? submissionTimestamp = application['submissionDate'] as Timestamp?;
    String submissionDate = submissionTimestamp != null
        ? DateFormat('MMM dd, yyyy HH:mm').format(submissionTimestamp.toDate())
        : 'N/A';

    Color statusColor =
        currentStatus == 'New' ? CupertinoColors.systemOrange : CupertinoColors.systemGreen;

    return Card(
      color: color.scaffoldBackgroundColor,
      elevation: 4,
      shadowColor: statusColor.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 4.0,
      ),
      child: CupertinoListTile(
        title: Text(
          fullName,
          style: TextStyle(
            color: color.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Program: $primaryProgram',
              style: TextStyle(color: color.hintColor),
            ),
            Row(
              children: [
                Container(
                  width: 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: $currentStatus',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              'Submitted: $submissionDate',
              style: TextStyle(color: color.hintColor, fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: CupertinoColors.systemGrey,
        ),
        onTap: () async {
          String initialStatus = application['status'] ?? 'New';
          if (initialStatus == 'New') {
            await _updateApplicationStatus(
              applicationId: docId,
              newStatus: 'Reviewed',
              globalApplicationRequestId:
                  application['globalApplicationRequestId'],
              userId: application['userId'],
            );
          }
 
          await Future.delayed(const Duration(milliseconds: 500));
          
          DocumentSnapshot updatedDoc = await _firestore
              .collection('tactso_branches')
              .doc(_currentuid)
              .collection('application_requests')
              .doc(docId)
              .get();

          if (updatedDoc.exists) {
            _showApplicationDetails(
              updatedDoc.data() as Map<String, dynamic>,
              updatedDoc.id,
            );
          } else {
            Api().showMessage(
              context,
              'Error',
              'Application not found after update.',
              CupertinoColors.systemRed,
            );
          }
        },
      ),
    );
  }
}