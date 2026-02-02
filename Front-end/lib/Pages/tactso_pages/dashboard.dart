// // ignore_for_file: prefer_const_constructors
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:ttact/Components/NeuDesign.dart';

// class DashboardTab extends StatefulWidget {
//   final String currentUid;
//   final String? universityName;
//   final String? faceUrl;
//   final String? loggedMemberName;
//   final String? loggedMemberRole;
//   final Color baseColor;

//   const DashboardTab({
//     super.key,
//     required this.currentUid,
//     required this.baseColor,
//     this.universityName,
//     this.faceUrl,
//     this.loggedMemberName,
//     this.loggedMemberRole,
//   });

//   @override
//   State<DashboardTab> createState() => _DashboardTabState();
// }

// class _DashboardTabState extends State<DashboardTab> {
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('tactso_branches')
//           .doc(widget.currentUid)
//           .collection('application_requests')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return Center(child: CupertinoActivityIndicator());
//         }

//         final docs = snapshot.data!.docs;
//         final total = docs.length;
//         final newApps = docs.where((d) => d['status'] == 'New').length;
//         final submitted = docs
//             .where((d) => d['status'] == 'Application Submitted')
//             .length;
//         final rejected = docs.where((d) => d['status'] == 'Rejected').length;
//         final reviewed = docs.where((d) => d['status'] == 'Reviewed').length;

//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // --- WELCOME CARD ---
//             NeumorphicContainer(
//               color: widget.baseColor,
//               borderRadius: 20,
//               padding: EdgeInsets.all(24),
//               child: Row(
//                 children: [
//                   NeumorphicContainer(
//                     color: widget.baseColor,
//                     borderRadius: 50,
//                     padding: EdgeInsets.all(4),
//                     child: CircleAvatar(
//                       radius: 35,
//                       backgroundImage: widget.faceUrl != null
//                           ? NetworkImage(widget.faceUrl!)
//                           : null,
//                       backgroundColor: Colors.grey[300],
//                       child: widget.faceUrl == null
//                           ? Icon(Icons.person, color: Colors.grey)
//                           : null,
//                     ),
//                   ),
//                   SizedBox(width: 20),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           "Welcome Back,",
//                           style: TextStyle(color: Colors.grey),
//                         ),
//                         SizedBox(height: 5),
//                         Text(
//                           widget.loggedMemberName ?? "Officer",
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: Theme.of(context).primaryColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 30),

//             // --- STATS GRID ---
//             LayoutBuilder(
//               builder: (context, constraints) {
//                 return Wrap(
//                   spacing: 20,
//                   runSpacing: 20,
//                   children: [
//                     _buildStatCard(
//                       context,
//                       "Total Apps",
//                       total.toString(),
//                       Icons.folder,
//                       Colors.blue,
//                       constraints.maxWidth,
//                     ),
//                     _buildStatCard(
//                       context,
//                       "Pending",
//                       newApps.toString(),
//                       Icons.hourglass_empty,
//                       Colors.orange,
//                       constraints.maxWidth,
//                     ),
//                     _buildStatCard(
//                       context,
//                       "Completed",
//                       submitted.toString(),
//                       Icons.check_circle,
//                       Colors.green,
//                       constraints.maxWidth,
//                     ),
//                   ],
//                 );
//               },
//             ),

//             SizedBox(height: 30),

//             // --- CHART SECTION ---
//             if (total > 0)
//               NeumorphicContainer(
//                 color: widget.baseColor,
//                 borderRadius: 20,
//                 padding: EdgeInsets.all(20),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "Status Distribution",
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 20),
//                     SizedBox(
//                       height: 250,
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: PieChart(
//                               PieChartData(
//                                 sectionsSpace: 4,
//                                 centerSpaceRadius: 40,
//                                 sections: [
//                                   _buildPieSection(newApps, Colors.orange),
//                                   _buildPieSection(reviewed, Colors.blue),
//                                   _buildPieSection(submitted, Colors.green),
//                                   _buildPieSection(rejected, Colors.red),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               _legend("New", Colors.orange, newApps),
//                               _legend("Reviewed", Colors.blue, reviewed),
//                               _legend("Submitted", Colors.green, submitted),
//                               _legend("Rejected", Colors.red, rejected),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildStatCard(
//     BuildContext context,
//     String title,
//     String value,
//     IconData icon,
//     Color color,
//     double screenWidth,
//   ) {
//     double cardWidth = screenWidth > 800
//         ? (screenWidth - 100) / 3
//         : screenWidth;

//     return NeumorphicContainer(
//       color: widget.baseColor,
//       borderRadius: 16,
//       child: Row(
//         children: [
//           Icon(icon, color: color, size: 34),
//           SizedBox(width: 15),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(color: Colors.grey[600], fontSize: 13),
//               ),
//               Text(
//                 value,
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w900,
//                   color: Theme.of(context).primaryColor,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   PieChartSectionData _buildPieSection(int count, Color color) {
//     return PieChartSectionData(
//       color: color,
//       value: count.toDouble(),
//       title: count > 0 ? '$count' : '',
//       radius: 45,
//       titleStyle: TextStyle(
//         fontSize: 14,
//         fontWeight: FontWeight.bold,
//         color: Colors.white,
//       ),
//     );
//   }

//   Widget _legend(String title, Color color, int count) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8.0),
//       child: Row(
//         children: [
//           CircleAvatar(radius: 4, backgroundColor: color),
//           SizedBox(width: 8),
//           Text("$title: $count", style: TextStyle(fontSize: 12)),
//         ],
//       ),
//     );
//   }
// }
