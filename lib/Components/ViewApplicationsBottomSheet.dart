// Place this class outside of your main State class
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewApplicationBottomSheet extends StatefulWidget {
  final String userId;
  final String universityUid;

  const ViewApplicationBottomSheet({
    Key? key,
    required this.userId,
    required this.universityUid,
  }) : super(key: key);

  @override
  State<ViewApplicationBottomSheet> createState() =>
      _ViewApplicationBottomSheetState();
}

class _ViewApplicationBottomSheetState
    extends State<ViewApplicationBottomSheet> {
  Map<String, dynamic>? _applicationData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplicationData();
  }

  Future<void> _fetchApplicationData() async {
    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('university_applications')
          .where('applicationDetails.uid', isEqualTo: widget.universityUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _applicationData =
            querySnapshot.docs.first.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching application data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _applicationData != null
          ? SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header and Status Badge
                  Center(
                    child: Text(
                      'Your Application',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildStatusBadge(_applicationData!['status']),
                  const SizedBox(height: 20),

                  // University & Campus Details
                  Card(
                    elevation: 0,
                    color: CupertinoColors.extraLightBackgroundGray,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _applicationData!['universityName'] ?? 'N/A',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _applicationData!['campus'] ?? 'N/A',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personal Information Card
                  _buildInfoCard(
                    title: 'Personal Information',
                    icon: CupertinoIcons.person_alt_circle_fill,
                    children: [
                      _buildDetailRow(
                        'Full Name',
                        _applicationData!['applicationDetails']['fullName'],
                      ),
                      _buildDetailRow(
                        'Email',
                        _applicationData!['applicationDetails']['email'],
                      ),
                      _buildDetailRow(
                        'Phone',
                        _applicationData!['applicationDetails']['phone'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Program Details Card
                  _buildInfoCard(
                    title: 'Program Selection',
                    icon: CupertinoIcons.book_solid,
                    children: [
                      _buildDetailRow(
                        'Primary Program',
                        _applicationData!['applicationDetails']['primaryProgram'],
                      ),
                      _buildDetailRow(
                        'Second Choice',
                        _applicationData!['applicationDetails']['secondChoiceProgram'],
                      ),
                      _buildDetailRow(
                        'Third Choice',
                        _applicationData!['applicationDetails']['thirdChoiceProgram'],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Documents Card
                  _buildInfoCard(
                    title: 'Supporting Documents',
                    icon: CupertinoIcons.doc_on_clipboard_fill,
                    children: [
                      _buildDocumentStatus(
                        'ID / Passport',
                        _applicationData!['applicationDetails']['documents']['idPassportUrl'],
                      ),
                      _buildDocumentStatus(
                        'School Results',
                        _applicationData!['applicationDetails']['documents']['schoolResultsUrl'],
                      ),
                      _buildDocumentStatus(
                        'Passport Photo',
                        _applicationData!['applicationDetails']['documents']['passportPhotoUrl'],
                      ),
                    ],
                  ),
                ],
              ),
            )
          : const Center(
              child: Text('No application found for this university.'),
            ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color badgeColor;
    switch (status) {
      case 'Submitted':
        badgeColor = CupertinoColors.activeGreen;
        break;
      case 'Pending':
        badgeColor = CupertinoColors.activeOrange;
        break;
      case 'Review':
        badgeColor = CupertinoColors.activeBlue;
        break;
      default:
        badgeColor = CupertinoColors.systemGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? 'Unknown',
        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: CupertinoColors.activeBlue),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(color: CupertinoColors.systemGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatus(String label, String? url) {
    final bool isUploaded = url != null && url.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isUploaded
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.exclamationmark_triangle_fill,
            color: isUploaded
                ? CupertinoColors.activeGreen
                : CupertinoColors.systemOrange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            isUploaded ? 'Uploaded' : 'Pending',
            style: TextStyle(
              color: isUploaded
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.systemOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
