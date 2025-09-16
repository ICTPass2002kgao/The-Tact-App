import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Ensure Material is imported for Material widgets
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // For opening URLs (documents)

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
  }

  Future<void> _loadUniversityData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _currentuid = currentUser.uid;
      try {
        DocumentSnapshot universityDoc = await _firestore
            .collection('tactso_branches')
            .doc(_currentuid)
            .get();

        if (universityDoc.exists) {
          setState(() {
            _universityName = universityDoc['name'];
          });
        }
      } catch (e) {
        print('Error fetching university data: $e');
        if (mounted) {
          Api().showMessage(
            context,
            'Error',
            'Could not load university data.',
            CupertinoColors.systemRed,
          );
        }
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
      }
    } catch (e) {
      print('Error updating status: $e');
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
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        Api().showMessage(
          context,
          'Error',
          'Could not open document. Invalid URL or no app to handle it.',
          CupertinoColors.systemRed,
        );
      }
      throw 'Could not launch $url';
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
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateInPopup) {
            return CupertinoActionSheet(
              title: Text(
                'Application Details for ${applicationDetails['fullName'] ?? 'Applicant'}',
                style: TextStyle(color: colorScheme.primaryColor),
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
                    // Loop through documents (assuming 'documents' is a Map in applicationDetails)
                    if (applicationDetails['documents'] is Map &&
                        (applicationDetails['documents'] as Map).isNotEmpty)
                      ...(applicationDetails['documents'] as Map).entries.map((
                        entry,
                      ) {
                        String docName = entry.key
                            .toString()
                            .replaceAll('_', ' ')
                            .toUpperCase(); // e.g., 'proof_of_id' -> 'PROOF OF ID'
                        String docUrl = entry.value.toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _launchUrl(docUrl),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.doc_fill, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Download $docName',
                                    style: TextStyle(
                                      color: colorScheme.primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow
                                        .ellipsis, // Handle long URLs
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
                    Material(
                      color: Colors.transparent,
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
                    style: TextStyle(color: colorScheme.primaryColor),
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
        );
      },
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    // Ensure value is displayed as string, or 'N/A' if null/empty
    String displayValue = (value == null || (value is String && value.isEmpty))
        ? 'N/A'
        : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140, // Slightly wider for labels
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

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: color.appBarTheme.backgroundColor,
        activeColor: color.scaffoldBackgroundColor,
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
              appBar: AppBar(
                title: Text(
                  '${_universityName ?? 'University'} Admin Dashboard',
                ),
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
              ),
              drawer: Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(color: color.primaryColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: TextStyle(
                              color: color.scaffoldBackgroundColor,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            _universityName ?? 'University Admin',
                            style: TextStyle(
                              color: color.scaffoldBackgroundColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(CupertinoIcons.square_arrow_right),
                      title: const Text('Logout'),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
              body: index == 0
                  ? _buildDashboardTab(context)
                  : _buildApplicationsTab(context),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardTab(BuildContext context) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          // Total Applications Card
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('tactso_branches')
                .doc(_currentuid)
                .collection('application_requests')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Error loading total applications: ${snapshot.error}',
                  style: const TextStyle(color: CupertinoColors.systemRed),
                );
              }
              final totalApplications = snapshot.data?.docs.length ?? 0;
              return Card(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Applications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalApplications',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // New Applications Card
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('tactso_branches')
                .doc(_currentuid)
                .collection('application_requests')
                .where('status', isEqualTo: 'New')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Error loading new applications: ${snapshot.error}',
                  style: const TextStyle(color: CupertinoColors.systemRed),
                );
              }
              final newApplications = snapshot.data?.docs.length ?? 0;
              return Card(
                color: CupertinoColors.systemOrange.withOpacity(0.1),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Applications (Pending Review)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemOrange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$newApplications',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Reviewed Applications Card
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('tactso_branches')
                .doc(_currentuid)
                .collection('application_requests')
                .where('status', isEqualTo: 'Reviewed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Error loading reviewed applications: ${snapshot.error}',
                  style: const TextStyle(color: CupertinoColors.systemRed),
                );
              }
              final reviewedApplications = snapshot.data?.docs.length ?? 0;
              return Card(
                color: CupertinoColors.systemGreen.withOpacity(0.1),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applications Reviewed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.activeGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$reviewedApplications',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.activeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Applied Applications Card
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('tactso_branches')
                .doc(_currentuid)
                .collection('application_requests')
                .where('status', isEqualTo: 'Applied')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Error loading applied applications: ${snapshot.error}',
                  style: const TextStyle(color: CupertinoColors.systemRed),
                );
              }
              final appliedApplications = snapshot.data?.docs.length ?? 0;
              return Card(
                color: CupertinoColors.systemPurple.withOpacity(0.1),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applications Sent to University (Applied)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$appliedApplications',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsTab(BuildContext context) {
    final color = Theme.of(context);
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
                'No new or reviewed applications currently pending action.',
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
            var applicationDetails =
                application['applicationDetails'] as Map<String, dynamic>?;

            if (applicationDetails == null) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  color: color.scaffoldBackgroundColor,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CupertinoListTile(
                      title: const Text('Invalid Application Data'),
                      subtitle: Text('Document ID: ${doc.id}'),
                      leading: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ),
                ),
              );
            }

            String fullName = applicationDetails['fullName'] ?? 'N/A';
            String primaryProgram =
                applicationDetails['primaryProgram'] ?? 'N/A';
            String currentStatus = application['status'] ?? 'N/A';
            Timestamp? submissionTimestamp =
                application['submissionDate'] as Timestamp?;
            String submissionDate = submissionTimestamp != null
                ? DateFormat(
                    'MMM dd, yyyy HH:mm',
                  ).format(submissionTimestamp.toDate())
                : 'N/A';

            return Card(
              color: color.scaffoldBackgroundColor.withOpacity(0.8),
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CupertinoListTile(
                  title: Text(
                    'Applicant: $fullName',
                    style: TextStyle(color: color.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Program: $primaryProgram',
                        style: TextStyle(color: color.hintColor),
                      ),
                      Text(
                        'Current Status: $currentStatus',
                        style: TextStyle(
                          color: color.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Submitted on: $submissionDate',
                        style: TextStyle(color: color.hintColor),
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
                        applicationId: doc.id,
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
                        .doc(doc.id)
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
              ),
            );
          },
        );
      },
    );
  }
}
