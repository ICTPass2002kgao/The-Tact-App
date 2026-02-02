// // ignore_for_file: prefer_const_constructors, use_build_context_synchronously

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:ttact/Components/API.dart';
// import 'package:ttact/Pages/Overseer/dashboard_tab.dart';
// import 'package:ttact/Pages/tactso_pages/applications.dart';
// import 'package:ttact/Pages/tactso_pages/commitees.dart';

// class TactsoBranchesApplications extends StatefulWidget {
//   final String? loggedMemberName;
//   final String? loggedMemberRole;
//   final String? faceUrl;

//   const TactsoBranchesApplications({
//     super.key,
//     this.loggedMemberName,
//     this.loggedMemberRole,
//     this.faceUrl,
//   });

//   @override
//   State<TactsoBranchesApplications> createState() =>
//       _TactsoBranchesApplicationsState();
// }

// class _TactsoBranchesApplicationsState
//     extends State<TactsoBranchesApplications> {
//   int _selectedIndex = 0;
//   String? _currentUid;
//   String? _universityName;
//   String? _universityLogoUrl;
//   String? _educationOfficerFace; // For audit logs
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     User? user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       Navigator.pushReplacementNamed(context, '/login');
//       return;
//     }
//     _currentUid = user.uid;

//     try {
//       final docSnap = await FirebaseFirestore.instance
//           .collection('tactso_branches')
//           .doc(_currentUid)
//           .get();

//       if (docSnap.exists) {
//         final data = docSnap.data()!;
//         setState(() {
//           _universityName = data['universityName'];
//           _educationOfficerFace = data['educationOfficerFaceUrl'];
//           var img = data['imageUrl'];
//           if (img is List && img.isNotEmpty) {
//             _universityLogoUrl = img[0];
//           } else if (img is String) {
//             _universityLogoUrl = img;
//           }
//         });
//       }
//     } catch (e) {
//       print("Error loading data: $e");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     final theme = Theme.of(context);
//     // ⭐️ CALCULATE NEUMORPHIC BASE COLOR EXACTLY LIKE LOGIN PAGE
//     final Color neumoBaseColor = Color.alphaBlend(
//       theme.primaryColor.withOpacity(0.08),
//       theme.scaffoldBackgroundColor,
//     );

//     return Scaffold(
//       backgroundColor: neumoBaseColor,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: neumoBaseColor,
//         iconTheme: IconThemeData(color: Colors.black87),
//         title: Text(
//           _universityName ?? "Admin Portal",
//           style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.logout),
//             onPressed: () async {
//               await FirebaseAuth.instance.signOut();
//               Navigator.pushNamedAndRemoveUntil(
//                 context,
//                 '/login',
//                 (route) => false,
//               );
//             },
//           ),
//         ],
//       ),
//       drawer: Drawer(
//         backgroundColor: neumoBaseColor,
//         child: Column(
//           children: [
//             UserAccountsDrawerHeader(
//               decoration: BoxDecoration(color: theme.primaryColor),
//               accountName: Text(_universityName ?? "Tactso Branch"),
//               accountEmail: Text(
//                 "${widget.loggedMemberName ?? 'Admin'} (${widget.loggedMemberRole ?? 'Officer'})",
//               ),
//               currentAccountPicture: CircleAvatar(
//                 backgroundColor: Colors.white,
//                 backgroundImage: _universityLogoUrl != null
//                     ? NetworkImage(_universityLogoUrl!)
//                     : null,
//                 child: _universityLogoUrl == null
//                     ? Icon(Icons.school, color: theme.primaryColor)
//                     : null,
//               ),
//             ),
//             _drawerItem(0, "Dashboard", Icons.dashboard),
//             _drawerItem(1, "Applications", Icons.table_chart),
//             _drawerItem(2, "Committee", Icons.groups),
//           ],
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(20),
//         child: Center(
//           child: ConstrainedBox(
//             constraints: BoxConstraints(
//               maxWidth: 1000,
//             ), // Responsive constraint
//             child: _buildCurrentTab(neumoBaseColor),
//           ),
//         ),
//       ),
//       bottomNavigationBar: MediaQuery.of(context).size.width < 800
//           ? NavigationBar(
//               backgroundColor: neumoBaseColor,
//               elevation: 0,
//               selectedIndex: _selectedIndex,
//               onDestinationSelected: (i) => setState(() => _selectedIndex = i),
//               destinations: const [
//                 NavigationDestination(
//                   icon: Icon(Icons.dashboard_outlined),
//                   label: 'Home',
//                 ),
//                 NavigationDestination(
//                   icon: Icon(Icons.table_chart_outlined),
//                   label: 'Apps',
//                 ),
//                 NavigationDestination(
//                   icon: Icon(Icons.people_outlined),
//                   label: 'Team',
//                 ),
//               ],
//             )
//           : null, // Hide bottom nav on desktop, assume drawer is used
//     );
//   }

//   Widget _buildCurrentTab(Color baseColor) {
//     switch (_selectedIndex) {
//       case 0:
//         return DashboardTab(
//           isLargeScreen: MediaQuery.of(context).size.width > 800,
//           faceUrl: widget.faceUrl,
//           committeeMemberName: widget.loggedMemberName,
//           committeeMemberRole: widget.loggedMemberRole,
//         );
//       case 1:
//         return ApplicationsTab(
//           currentUid: _currentUid!,
//           baseColor: baseColor,
//           universityName: _universityName,
//           universityLogoUrl: _universityLogoUrl,
//           loggedMemberName: widget.loggedMemberName,
//           loggedMemberRole: widget.loggedMemberRole,
//           universityCommitteeFace: _educationOfficerFace,
//         );
//       case 2:
//         return CommitteeTab(
//           currentUid: _currentUid!,
//           baseColor: baseColor,
//           universityName: _universityName,
//           universityLogoUrl: _universityLogoUrl,
//           loggedMemberName: widget.loggedMemberName,
//           loggedMemberRole: widget.loggedMemberRole,
//           universityCommitteeFace: _educationOfficerFace,
//         );
//       default:
//         return Center(child: Text("Tab not found"));
//     }
//   }

//   Widget _drawerItem(int index, String title, IconData icon) {
//     bool isSelected = _selectedIndex == index;
//     return ListTile(
//       leading: Icon(
//         icon,
//         color: isSelected ? Colors.blue : Colors.grey.shade600,
//       ),
//       title: Text(
//         title,
//         style: TextStyle(
//           color: isSelected ? Colors.blue : Colors.grey.shade800,
//           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//         ),
//       ),
//       tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
//       onTap: () {
//         setState(() => _selectedIndex = index);
//         Navigator.pop(context);
//       },
//     );
//   }
// }
