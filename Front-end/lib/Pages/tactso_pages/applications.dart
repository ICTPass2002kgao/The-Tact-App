// // ignore_for_file: prefer_const_constructors, use_build_context_synchronously
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:ttact/Components/API.dart';
// import 'package:ttact/Components/Aduit_Logs/Tactso_Audit_Logs.dart'; // Ensure correct path
// import 'package:ttact/Components/NeuDesign.dart';
// import 'package:url_launcher/url_launcher.dart';
 
// class ApplicationsTab extends StatefulWidget {
//   final String currentUid;
//   final String? universityName;
//   final String? universityLogoUrl;
//   final String? loggedMemberName;
//   final String? loggedMemberRole;
//   final String? universityCommitteeFace;
//   final Color baseColor;

//   const ApplicationsTab({
//     super.key,
//     required this.currentUid,
//     required this.baseColor,
//     this.universityName,
//     this.universityLogoUrl,
//     this.loggedMemberName,
//     this.loggedMemberRole,
//     this.universityCommitteeFace,
//   });

//   @override
//   State<ApplicationsTab> createState() => _ApplicationsTabState();
// }

// class _ApplicationsTabState extends State<ApplicationsTab> {
//   final List<String> _applicationStatuses = [
//     'New',
//     'Reviewed',
//     'Application Submitted',
//     'Rejected',
//   ];

//   Future<void> _updateApplicationStatus({
//     required String applicationId,
//     required String newStatus,
//     String? globalApplicationRequestId,
//     String? userId,
//     Map<String, dynamic>? applicationData,
//   }) async {
//     try {
//       await FirebaseFirestore.instance.runTransaction((transaction) async {
//         DocumentReference universityAppRef = FirebaseFirestore.instance
//             .collection('tactso_branches')
//             .doc(widget.currentUid)
//             .collection('application_requests')
//             .doc(applicationId);
//         transaction.update(universityAppRef, {'status': newStatus});

//         if (globalApplicationRequestId != null) {
//           DocumentReference globalAppRef = FirebaseFirestore.instance
//               .collection('application_requests')
//               .doc(globalApplicationRequestId);
//           transaction.update(globalAppRef, {
//             'applicationDetails.status': newStatus,
//             'status': newStatus,
//           });
//         }
//         if (userId != null) {
//           QuerySnapshot userAppsSnapshot = await FirebaseFirestore.instance
//               .collection('users')
//               .doc(userId)
//               .collection('university_applications')
//               .where('uid', isEqualTo: widget.currentUid)
//               .where('applicationRequestId', isEqualTo: applicationId)
//               .get();
//           if (userAppsSnapshot.docs.isNotEmpty) {
//             transaction.update(userAppsSnapshot.docs.first.reference, {
//               'status': newStatus,
//             });
//           }
//         }
//       });

//       // Email Notification
//       if (applicationData != null) {
//         final details = applicationData['applicationDetails'] ?? {};
//         final studentEmail = details['email'];
//         if (studentEmail != null) {
//           await Api().sendEmail(
//             studentEmail,
//             'Status Update: $newStatus',
//             '<p>Your application status at ${widget.universityName} is now: $newStatus</p>',
//             context,
//           );
//         }
//       }

//       // Audit Log
//       String studentName =
//           applicationData?['applicationDetails']?['fullName'] ?? "Unknown";
//       await TactsoAuditLogs.logAction(
//         action: "UPDATE_STATUS",
//         details: "Changed status to $newStatus for $studentName",
//         referenceId: applicationId,
//         universityName: widget.universityName,
//         universityLogo: widget.universityLogoUrl,
//         committeeMemberName: widget.loggedMemberName,
//         committeeMemberRole: widget.loggedMemberRole,
//         universityCommitteeFace: widget.universityCommitteeFace,
//         studentName: studentName,
//       );

//       Api().showMessage(context, 'Success', 'Status updated.', Colors.green);
//     } catch (e) {
//       Api().showMessage(context, 'Error', '$e', Colors.red);
//     }
//   }

//   Future<void> _launchUrl(String url) async {
//     if (!await launchUrl(Uri.parse(url))) {
//       Api().showMessage(context, 'Error', 'Invalid URL', Colors.red);
//     }
//   }

//   void _showDocsDialog(BuildContext context, dynamic docs, String studentName) {
//     showDialog(
//       context: context,
//       builder: (c) => AlertDialog(
//         backgroundColor: widget.baseColor,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Text("Documents: $studentName"),
//         content: SizedBox(
//           width: 400,
//           child: docs == null || docs is! Map
//               ? Text("No documents found.")
//               : ListView(
//                   shrinkWrap: true,
//                   children: docs.entries.map((e) {
//                     return ListTile(
//                       leading: Icon(Icons.description, color: Colors.blue),
//                       title: Text(e.key.toString()),
//                       onTap: () => _launchUrl(e.value.toString()),
//                     );
//                   }).toList(),
//                 ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           "Manage Applications",
//           style: TextStyle(
//               fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
//         ),
//         SizedBox(height: 20),
//         StreamBuilder<QuerySnapshot>(
//           stream: FirebaseFirestore.instance
//               .collection('tactso_branches')
//               .doc(widget.currentUid)
//               .collection('application_requests')
//               .orderBy('submissionDate', descending: true)
//               .snapshots(),
//           builder: (context, snapshot) {
//             if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//               return NeumorphicContainer(
//                 color: widget.baseColor,
//                 child: Center(
//                   child: Padding(
//                     padding: const EdgeInsets.all(40.0),
//                     child: Text("No applications received yet."),
//                   ),
//                 ),
//               );
//             }

//             return NeumorphicContainer(
//               color: widget.baseColor,
//               padding: EdgeInsets.all(16),
//               borderRadius: 20,
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 child: DataTable(
//                   columnSpacing: 30,
//                   headingRowColor: MaterialStateProperty.all(
//                       Theme.of(context).primaryColor.withOpacity(0.1)),
//                   columns: const [
//                     DataColumn(
//                         label: Text("Student",
//                             style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataColumn(
//                         label: Text("Current Status",
//                             style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataColumn(
//                         label: Text("Documents",
//                             style: TextStyle(fontWeight: FontWeight.bold))),
//                   ],
//                   rows: snapshot.data!.docs.map((doc) {
//                     var data = doc.data() as Map<String, dynamic>;
//                     return DataRow(
//                       cells: [
//                         DataCell(Text(
//                           data['applicationDetails']['fullName'] ?? 'Unknown',
//                           style: TextStyle(fontWeight: FontWeight.w500),
//                         )),
//                         DataCell(
//                           Container(
//                             padding: EdgeInsets.symmetric(horizontal: 8),
//                             decoration: BoxDecoration(
//                               color: widget.baseColor,
//                               borderRadius: BorderRadius.circular(8),
//                               border: Border.all(color: Colors.grey.shade300),
//                             ),
//                             child: DropdownButtonHideUnderline(
//                               child: DropdownButton<String>(
//                                 value: _applicationStatuses
//                                         .contains(data['status'])
//                                     ? data['status']
//                                     : null,
//                                 dropdownColor: widget.baseColor,
//                                 style: TextStyle(
//                                     color: Colors.black87, fontSize: 13),
//                                 items: _applicationStatuses.map((s) {
//                                   return DropdownMenuItem(
//                                       value: s, child: Text(s));
//                                 }).toList(),
//                                 onChanged: (val) {
//                                   if (val != null) {
//                                     _updateApplicationStatus(
//                                       applicationId: doc.id,
//                                       newStatus: val,
//                                       applicationData: data,
//                                       globalApplicationRequestId:
//                                           data['globalApplicationRequestId'],
//                                       userId: data['userId'],
//                                     );
//                                   }
//                                 },
//                               ),
//                             ),
//                           ),
//                         ),
//                         DataCell(
//                           IconButton(
//                             icon: Icon(Icons.folder_open, color: Colors.blue),
//                             onPressed: () => _showDocsDialog(
//                               context,
//                               data['applicationDetails']['documents'],
//                               data['applicationDetails']['fullName'] ??
//                                   'Student',
//                             ),
//                           ),
//                         ),
//                       ],
//                     );
//                   }).toList(),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
// }