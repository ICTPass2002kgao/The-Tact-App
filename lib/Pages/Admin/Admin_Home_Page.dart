// // ignore_for_file: prefer_const_constructors, unused_local_variable, unnecessary_null_comparison, avoid_print

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:fl_chart/fl_chart.dart'; // REQUIRED: Add fl_chart to pubspec.yaml
// import 'package:flutter/material.dart';
// import 'package:ionicons/ionicons.dart';
// import 'package:shimmer/shimmer.dart';

// // --- PLATFORM UTILITIES ---
// const double _desktopContentMaxWidth = 1100.0;
// const int _desktopGridColumns = 3;
// bool isLargeScreen(BuildContext context) =>
//     MediaQuery.of(context).size.width >= 800;
// // --------------------------

// class AdminHomePage extends StatefulWidget {
//   const AdminHomePage({super.key});

//   @override
//   State<AdminHomePage> createState() => _AdminHomePageState();
// }

// class _AdminHomePageState extends State<AdminHomePage> {
//   // --- State for Overseer Management ---
//   bool _isLoadingOverseers = true;
//   List<DocumentSnapshot> _allOverseers = [];
//   List<DocumentSnapshot> _filteredOverseers = [];
//   final TextEditingController _searchController = TextEditingController();

//   // Region & Province Filters (Overseers)
//   final List<String> _filterOptions = ['All Regions'];
//   String _selectedFilter = 'All Regions';
//   final List<String> _provinceFilterOptions = ['All Provinces'];
//   String _selectedProvinceFilter = 'All Provinces';

//   // Overseer Pagination
//   int _pageSize = 20;
//   int _currentPage = 0;

//   // --- State for User Management (NEW) ---
//   bool _isLoadingUsers = true;
//   List<DocumentSnapshot> _allUsers = [];
//   int _userPageSize = 10; // Requested: 10 items per page
//   int _usersCurrentPage = 0;

//   // --- State for Province Statistics (NEW) ---
//   Map<String, int> _provinceCounts = {
//     'Eastern Cape': 0,
//     'Free State': 0,
//     'Gauteng': 0,
//     'KwaZulu-Natal': 0,
//     'Limpopo': 0,
//     'Mpumalanga': 0,
//     'Northern Cape': 0,
//     'North West': 0,
//     'Western Cape': 0,
//     'Unknown': 0,
//   };

//   // Province Colors for Chart
//   final Map<String, Color> _provinceColors = {
//     'Eastern Cape': Colors.blue,
//     'Free State': Colors.orange,
//     'Gauteng': Colors.purple,
//     'KwaZulu-Natal': Colors.green,
//     'Limpopo': Colors.red,
//     'Mpumalanga': Colors.yellow.shade700,
//     'Northern Cape': Colors.teal,
//     'North West': Colors.pink,
//     'Western Cape': Colors.indigo,
//     'Unknown': Colors.grey,
//   };

//   @override
//   void initState() {
//     super.initState();
//     _fetchAndSortOverseers();
//     _fetchUsersAndStats(); // Fetch users and calc pie chart data
//     _searchController.addListener(_runFilters);
//   }

//   @override
//   void dispose() {
//     _searchController.removeListener(_runFilters);
//     _searchController.dispose();
//     super.dispose();
//   }

//   /// 1. Fetch Overseers (Existing Logic)
//   Future<void> _fetchAndSortOverseers() async {
//     setState(() => _isLoadingOverseers = true);
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('overseers')
//           .get();
//       final docs = snapshot.docs;

//       // Sort by districts count descending
//       docs.sort((a, b) {
//         final aData = a.data() as Map<String, dynamic>;
//         final bData = b.data() as Map<String, dynamic>;
//         final aDistricts = (aData['districts'] as List? ?? []).length;
//         final bDistricts = (bData['districts'] as List? ?? []).length;
//         return bDistricts.compareTo(aDistricts);
//       });

//       // Populate Filters
//       final Set<String> regions = {'All Regions'};
//       final Set<String> provinces = {'All Provinces'};
//       for (var doc in docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         if (data['region'] != null) regions.add(data['region']);
//         if (data['province'] != null) provinces.add(data['province']);
//       }

//       setState(() {
//         _allOverseers = docs;
//         _filteredOverseers = docs;
//         _filterOptions.clear();
//         _filterOptions.addAll(regions.toList()..sort());
//         _selectedFilter = 'All Regions';
//         _provinceFilterOptions.clear();
//         _provinceFilterOptions.addAll(provinces.toList()..sort());
//         _selectedProvinceFilter = 'All Provinces';
//         _isLoadingOverseers = false;
//         _currentPage = 0;
//       });
//     } catch (e) {
//       print("Error fetching overseers: $e");
//       setState(() => _isLoadingOverseers = false);
//     }
//   }

//   /// 2. Fetch Users and Calculate Province Stats (NEW Logic)
//   Future<void> _fetchUsersAndStats() async {
//     setState(() => _isLoadingUsers = true);
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .get();
//       final docs = snapshot.docs;

//       // Reset counts
//       final Map<String, int> tempCounts = {
//         'Eastern Cape': 0,
//         'Free State': 0,
//         'Gauteng': 0,
//         'KwaZulu-Natal': 0,
//         'Limpopo': 0,
//         'Mpumalanga': 0,
//         'Northern Cape': 0,
//         'North West': 0,
//         'Western Cape': 0,
//         'Unknown': 0,
//       };

//       // Calculate Stats based on address contains
//       for (var doc in docs) {
//         final data = doc.data();
//         final address = (data['address'] ?? '').toString().toLowerCase();

//         bool found = false;
//         // Check standard 9 provinces
//         for (String province in tempCounts.keys) {
//           if (province == 'Unknown') continue;
//           if (address.contains(province.toLowerCase())) {
//             tempCounts[province] = (tempCounts[province] ?? 0) + 1;
//             found = true;
//             break; // Stop checking once a province is found
//           }
//         }
//         if (!found) {
//           tempCounts['Unknown'] = (tempCounts['Unknown'] ?? 0) + 1;
//         }
//       }

//       setState(() {
//         _allUsers = docs;
//         _provinceCounts = tempCounts;
//         _isLoadingUsers = false;
//       });
//     } catch (e) {
//       print("Error fetching users: $e");
//       setState(() => _isLoadingUsers = false);
//     }
//   }

//   /// Applies search and filter criteria to the overseer list.
//   void _runFilters() {
//     List<DocumentSnapshot> temp = _allOverseers;
//     final searchQuery = _searchController.text.toLowerCase();

//     if (searchQuery.isNotEmpty) {
//       temp = temp.where((doc) {
//         final data = doc.data() as Map<String, dynamic>;
//         final name = (data['overseerInitialsAndSurname'] ?? '').toLowerCase();
//         final region = (data['region'] ?? '').toLowerCase();
//         final code = (data['code'] ?? '').toLowerCase();
//         return name.contains(searchQuery) ||
//             region.contains(searchQuery) ||
//             code.contains(searchQuery);
//       }).toList();
//     }

//     if (_selectedFilter != 'All Regions') {
//       temp = temp.where((doc) {
//         final data = doc.data() as Map<String, dynamic>;
//         return data['region'] == _selectedFilter;
//       }).toList();
//     }

//     if (_selectedProvinceFilter != 'All Provinces') {
//       temp = temp.where((doc) {
//         final data = doc.data() as Map<String, dynamic>;
//         return data['province'] == _selectedProvinceFilter;
//       }).toList();
//     }

//     setState(() {
//       _filteredOverseers = temp;
//       _currentPage = 0;
//     });
//   }

//   void _showEditDialog(DocumentSnapshot overseerDoc) {
//     final docData = overseerDoc.data() as Map<String, dynamic>;

//     final List<Map<String, dynamic>> currentDistricts =
//         List<Map<String, dynamic>>.from(
//           (docData['districts'] as List? ?? []).map(
//             (d) => Map<String, dynamic>.from(d),
//           ),
//         );

//     final TextEditingController emailController = TextEditingController(
//       text: docData['email'] ?? '',
//     );
//     final TextEditingController regionController = TextEditingController(
//       text: docData['region'] ?? '',
//     );
//     final TextEditingController codeController = TextEditingController(
//       text: docData['code'] ?? '',
//     );
//     final TextEditingController newDistrictController = TextEditingController();
//     final TextEditingController newCommunityController =
//         TextEditingController();

//     showDialog(
//       context: context,
//       builder: (context) {
//         String? _lastAddedDistrictName;

//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return Dialog(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12.0),
//               ),
//               child: ConstrainedBox(
//                 constraints: BoxConstraints(
//                   maxWidth: 600,
//                   maxHeight: MediaQuery.of(context).size.height * 0.8,
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(20.0),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Edit ${docData['overseerInitialsAndSurname']}',
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(height: 16),
//                       TextField(
//                         controller: emailController,
//                         decoration: InputDecoration(
//                           labelText: 'Email Address',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.emailAddress,
//                       ),
//                       SizedBox(height: 16),
//                       TextField(
//                         controller: regionController,
//                         decoration: InputDecoration(
//                           labelText: 'Region',
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                       SizedBox(height: 16),
//                       TextField(
//                         controller: codeController,
//                         decoration: InputDecoration(
//                           labelText: 'Code',
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                       Divider(height: 24),
//                       Text(
//                         'Manage Districts & Communities',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       Expanded(
//                         child: SingleChildScrollView(
//                           child: Column(
//                             children: [
//                               ...currentDistricts.map((district) {
//                                 final districtName =
//                                     district['districtElderName'] as String? ??
//                                     'Unnamed';
//                                 final List<dynamic> communities =
//                                     List<dynamic>.from(
//                                       district['communities'] as List? ?? [],
//                                     );

//                                 return ExpansionTile(
//                                   initiallyExpanded:
//                                       districtName == _lastAddedDistrictName,
//                                   title: Text(districtName),
//                                   subtitle: Text(
//                                     '${communities.length} communities',
//                                   ),
//                                   trailing: IconButton(
//                                     icon: Icon(
//                                       Icons.delete_forever,
//                                       color: Colors.red[700],
//                                     ),
//                                     onPressed: () {
//                                       setDialogState(() {
//                                         currentDistricts.remove(district);
//                                       });
//                                     },
//                                   ),
//                                   children: [
//                                     ...communities.map((community) {
//                                       final commName =
//                                           community['communityName']
//                                               as String? ??
//                                           'Unnamed';
//                                       return ListTile(
//                                         title: Text(commName),
//                                         dense: true,
//                                         leading: Icon(Icons.circle, size: 8),
//                                         trailing: IconButton(
//                                           icon: Icon(Icons.close, size: 18),
//                                           onPressed: () {
//                                             setDialogState(() {
//                                               communities.remove(community);
//                                             });
//                                           },
//                                         ),
//                                       );
//                                     }).toList(),
//                                     Padding(
//                                       padding: const EdgeInsets.symmetric(
//                                         horizontal: 16.0,
//                                         vertical: 8.0,
//                                       ),
//                                       child: Row(
//                                         children: [
//                                           Expanded(
//                                             child: TextField(
//                                               controller:
//                                                   newCommunityController,
//                                               decoration: InputDecoration(
//                                                 labelText: 'Add Community',
//                                                 isDense: true,
//                                               ),
//                                             ),
//                                           ),
//                                           IconButton(
//                                             icon: Icon(Icons.add_circle),
//                                             onPressed: () {
//                                               if (newCommunityController.text
//                                                   .trim()
//                                                   .isNotEmpty) {
//                                                 setDialogState(() {
//                                                   communities.add({
//                                                     'communityName':
//                                                         newCommunityController
//                                                             .text
//                                                             .trim(),
//                                                   });
//                                                 });
//                                                 newCommunityController.clear();
//                                               }
//                                             },
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 );
//                               }).toList(),
//                             ],
//                           ),
//                         ),
//                       ),
//                       Divider(height: 24),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: TextField(
//                               controller: newDistrictController,
//                               decoration: InputDecoration(
//                                 labelText: 'Add New District Elder',
//                                 border: OutlineInputBorder(),
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           ElevatedButton(
//                             child: Text('Add'),
//                             onPressed: () {
//                               if (newDistrictController.text
//                                   .trim()
//                                   .isNotEmpty) {
//                                 setDialogState(() {
//                                   _lastAddedDistrictName = newDistrictController
//                                       .text
//                                       .trim();
//                                   currentDistricts.add({
//                                     'districtElderName': _lastAddedDistrictName,
//                                     'communities': [],
//                                   });
//                                 });
//                                 newDistrictController.clear();
//                               }
//                             },
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 16),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           TextButton(
//                             child: Text('Cancel'),
//                             onPressed: () => Navigator.of(context).pop(),
//                           ),
//                           SizedBox(width: 8),
//                           ElevatedButton(
//                             child: Text('Save Changes'),
//                             onPressed: () async {
//                               final newEmail = emailController.text.trim();
//                               final newRegion = regionController.text.trim();
//                               final newCode = codeController.text.trim();

//                               final Map<String, dynamic> updates = {};

//                               if (newEmail.isNotEmpty &&
//                                   newEmail != docData['email']) {
//                                 updates['email'] = newEmail;
//                               }
//                               if (newRegion.isNotEmpty &&
//                                   newRegion != docData['region']) {
//                                 updates['region'] = newRegion;
//                               }
//                               if (newCode.isNotEmpty &&
//                                   newCode != docData['code']) {
//                                 updates['code'] = newCode;
//                               }
//                               updates['districts'] = currentDistricts;

//                               try {
//                                 await overseerDoc.reference.update(updates);
//                                 Navigator.of(context).pop();
//                                 _fetchAndSortOverseers();
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(
//                                     content: Text(
//                                       'Overseer updated successfully!',
//                                     ),
//                                     backgroundColor: Colors.green,
//                                   ),
//                                 );
//                               } catch (e) {
//                                 print("Error updating overseer: $e");
//                               }
//                             },
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final color = Theme.of(context);
//     final isDesktop = isLargeScreen(context);

//     // --- Pagination Logic (Overseers) ---
//     final int totalItems = _filteredOverseers.length;
//     final int totalPages = (totalItems / _pageSize).ceil();
//     final int startIndex = _currentPage * _pageSize;
//     final int endIndex = (startIndex + _pageSize > totalItems)
//         ? totalItems
//         : startIndex + _pageSize;
//     final List<DocumentSnapshot> _pagedOverseers = (totalItems > 0)
//         ? _filteredOverseers.sublist(startIndex, endIndex)
//         : [];

//     // --- Pagination Logic (Users) ---
//     final int totalUserItems = _allUsers.length;
//     final int totalUserPages = (totalUserItems / _userPageSize).ceil();
//     final int startUserIndex = _usersCurrentPage * _userPageSize;
//     final int endUserIndex = (startUserIndex + _userPageSize > totalUserItems)
//         ? totalUserItems
//         : startUserIndex + _userPageSize;
//     final List<DocumentSnapshot> _pagedUsers = (totalUserItems > 0)
//         ? _allUsers.sublist(startUserIndex, endUserIndex)
//         : [];

//     // Metrics Data
//     final List<Map<String, dynamic>> metricItems = [
//       {
//         'title': "TOTAL TACTSO BRANCHES",
//         'icon': Icons.location_city_outlined,
//         'future': FirebaseFirestore.instance
//             .collection('tactso_branches')
//             .get(),
//         'backgroundColor': color.primaryColorLight,
//       },
//       {
//         'title': "TOTAL TACT Songs",
//         'icon': Ionicons.musical_notes_outline,
//         'future': FirebaseFirestore.instance.collection('tact_music').get(),
//         'backgroundColor': color.primaryColorDark,
//       },
//       {
//         'title': "TOTAL TACT SELLERS",
//         'icon': Ionicons.people_outline,
//         'future': FirebaseFirestore.instance
//             .collection('users')
//             .where('role', isEqualTo: 'Seller')
//             .get(),
//         'backgroundColor': color.splashColor,
//       },
//       {
//         'title': "TOTAL TACT OVERSEERS",
//         'icon': Ionicons.people_outline,
//         'future': FirebaseFirestore.instance
//             .collection('overseers')
//             .where('role', isEqualTo: 'overseer')
//             .get(),
//         'backgroundColor': color.primaryColor,
//       },
//     ];

//     return Center(
//       child: ConstrainedBox(
//         constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
//         child: Padding(
//           padding: const EdgeInsets.all(14.0),
//           child: ListView(
//             children: [
//               Text(
//                 'TACT DASHBOARD',
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.w900,
//                   color: color.primaryColor,
//                 ),
//               ),
//               Text(
//                 'Welcome!, Here\'s a summary of our church\'s activities and status.',
//                 style: TextStyle(color: color.hintColor),
//               ),
//               const SizedBox(height: 20),

//               // --- 1. Metric Cards ---
//               LayoutBuilder(
//                 builder: (context, constraints) {
//                   final double spacing = isDesktop ? 20.0 : 10.0;
//                   final double itemWidth = isDesktop
//                       ? (constraints.maxWidth -
//                                 (spacing * (_desktopGridColumns - 1))) /
//                             _desktopGridColumns
//                       : constraints.maxWidth;

//                   return Wrap(
//                     spacing: spacing,
//                     runSpacing: spacing,
//                     children: metricItems.map((item) {
//                       return _buildDashboardCard(
//                         context: context,
//                         title: item['title'],
//                         icon: item['icon'],
//                         future: item['future'],
//                         backgroundColor: item['backgroundColor'],
//                         itemWidth: itemWidth,
//                         isDesktop: isDesktop,
//                       );
//                     }).toList(),
//                   );
//                 },
//               ),

//               const SizedBox(height: 30),

//               // --- 2. PROVINCE DISTRIBUTION PIE CHART (NEW) ---
//               Card(
//                 elevation: 3,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(20.0),
//                   child: Column(
//                     children: [
//                       Text(
//                         'User Distribution by Province',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: color.primaryColor,
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       _isLoadingUsers
//                           ? CircularProgressIndicator()
//                           : SizedBox(
//                               height: 300,
//                               child: Row(
//                                 children: [
//                                   Expanded(
//                                     flex: 2,
//                                     child: PieChart(
//                                       PieChartData(
//                                         sectionsSpace: 2,
//                                         centerSpaceRadius: 40,
//                                         sections: _generatePieSections(),
//                                       ),
//                                     ),
//                                   ),
//                                   if (isDesktop)
//                                     Expanded(flex: 1, child: _buildLegend()),
//                                 ],
//                               ),
//                             ),
//                       if (!isDesktop) ...[
//                         SizedBox(height: 20),
//                         _buildLegend(), // Show legend below on mobile
//                       ],
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 30),
//               const Divider(),
//               const SizedBox(height: 20),

//               // --- 3. OVERSEER MANAGEMENT ---
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'OVERSEER MANAGEMENT',
//                     style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.w700,
//                       color: color.primaryColor,
//                     ),
//                   ),
//                   Icon(
//                     Ionicons.people_circle_outline,
//                     color: color.primaryColor,
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 15),

//               // Filters
//               Column(
//                 children: [
//                   TextField(
//                     controller: _searchController,
//                     decoration: InputDecoration(
//                       labelText: 'Search Overseer by Name, Region, or Code',
//                       prefixIcon: Icon(Icons.search),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: DropdownButtonFormField<String>(
//                           value: _selectedFilter,
//                           items: _filterOptions.map((region) {
//                             return DropdownMenuItem<String>(
//                               value: region,
//                               child: Text(region),
//                             );
//                           }).toList(),
//                           onChanged: (value) {
//                             if (value != null) {
//                               setState(() => _selectedFilter = value);
//                               _runFilters();
//                             }
//                           },
//                           decoration: InputDecoration(
//                             labelText: 'Region',
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),
//                       SizedBox(width: 10),
//                       Expanded(
//                         child: DropdownButtonFormField<String>(
//                           value: _selectedProvinceFilter,
//                           items: _provinceFilterOptions.map((province) {
//                             return DropdownMenuItem<String>(
//                               value: province,
//                               child: Text(province),
//                             );
//                           }).toList(),
//                           onChanged: (value) {
//                             if (value != null) {
//                               setState(() => _selectedProvinceFilter = value);
//                               _runFilters();
//                             }
//                           },
//                           decoration: InputDecoration(
//                             labelText: 'Province',
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),

//               // Overseer Table
//               _isLoadingOverseers
//                   ? Center(child: CircularProgressIndicator())
//                   : _filteredOverseers.isEmpty
//                   ? Center(child: Text('No overseers found.'))
//                   : Table(
//                       border: TableBorder.all(
//                         color: color.hintColor.withOpacity(0.4),
//                       ),
//                       columnWidths: const {
//                         0: FlexColumnWidth(2.0),
//                         1: FlexColumnWidth(1.2),
//                         2: FlexColumnWidth(0.8),
//                         3: FlexColumnWidth(0.8),
//                         4: FlexColumnWidth(0.8),
//                         5: FlexColumnWidth(0.8),
//                       },
//                       children: [
//                         TableRow(
//                           decoration: BoxDecoration(
//                             color: color.primaryColor.withOpacity(0.1),
//                           ),
//                           children: [
//                             _buildHeaderCell('Overseer Name'),
//                             _buildHeaderCell('Region'),
//                             _buildHeaderCell('Code'),
//                             _buildHeaderCell('Districts'),
//                             _buildHeaderCell('Members'),
//                             _buildHeaderCell('Edit'),
//                           ],
//                         ),
//                         ..._pagedOverseers.map((doc) {
//                           final data = doc.data() as Map<String, dynamic>;
//                           final districts = data['districts'] as List?;
//                           final districtCount =
//                               districts?.length.toString() ?? '0';
//                           final String overseerUid = data['uid'] ?? doc.id;

//                           return TableRow(
//                             children: [
//                               _buildTableCell(
//                                 data['overseerInitialsAndSurname'] ?? 'N/A',
//                               ),
//                               _buildTableCell(data['region'] ?? 'N/A'),
//                               _buildTableCell(data['code'] ?? 'N/A'),
//                               Padding(
//                                 padding: const EdgeInsets.all(12.0),
//                                 child: Text(
//                                   districtCount,
//                                   textAlign: TextAlign.center,
//                                 ),
//                               ),
//                               TableCell(
//                                 verticalAlignment:
//                                     TableCellVerticalAlignment.middle,
//                                 child: FutureBuilder<AggregateQuerySnapshot>(
//                                   future: FirebaseFirestore.instance
//                                       .collection('users')
//                                       .where(
//                                         'overseerUid',
//                                         isEqualTo: overseerUid,
//                                       )
//                                       .count()
//                                       .get(),
//                                   builder: (context, snapshot) {
//                                     if (!snapshot.hasData) return Text('-');
//                                     return Center(
//                                       child: Text(
//                                         snapshot.data!.count.toString(),
//                                         style: TextStyle(
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ),
//                               TableCell(
//                                 verticalAlignment:
//                                     TableCellVerticalAlignment.middle,
//                                 child: Center(
//                                   child: IconButton(
//                                     icon: Icon(
//                                       Icons.edit_note,
//                                       color: color.primaryColor,
//                                     ),
//                                     onPressed: () => _showEditDialog(doc),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           );
//                         }).toList(),
//                       ],
//                     ),

//               // Overseer Pagination
//               if (totalPages > 1)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 16.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.end,
//                     children: [
//                       IconButton(
//                         icon: Icon(Icons.chevron_left),
//                         onPressed: _currentPage == 0
//                             ? null
//                             : () => setState(() => _currentPage--),
//                       ),
//                       Text(
//                         'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.chevron_right),
//                         onPressed: _currentPage >= totalPages - 1
//                             ? null
//                             : () => setState(() => _currentPage++),
//                       ),
//                     ],
//                   ),
//                 ),

//               const SizedBox(height: 40),
//               const Divider(),
//               const SizedBox(height: 20),

//               // --- 4. REGISTERED USERS TABLE (NEW) ---
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'REGISTERED USERS',
//                     style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.w700,
//                       color: color.primaryColor,
//                     ),
//                   ),
//                   Icon(Ionicons.person_outline, color: color.primaryColor),
//                 ],
//               ),
//               const SizedBox(height: 15),

//               _isLoadingUsers
//                   ? Center(child: CircularProgressIndicator())
//                   : _allUsers.isEmpty
//                   ? Center(child: Text('No users registered.'))
//                   : Column(
//                       children: [
//                         Table(
//                           border: TableBorder.all(
//                             color: color.hintColor.withOpacity(0.4),
//                           ),
//                           columnWidths: const {
//                             0: FlexColumnWidth(2.0), // Name
//                             1: FlexColumnWidth(2.5), // Address
//                             2: FlexColumnWidth(2.0), // Email
//                             3: FlexColumnWidth(1.0), // Role
//                           },
//                           children: [
//                             TableRow(
//                               decoration: BoxDecoration(
//                                 color: color.primaryColor.withOpacity(0.1),
//                               ),
//                               children: [
//                                 _buildHeaderCell('Name & Surname'),
//                                 _buildHeaderCell('Address'),
//                                 _buildHeaderCell('Email'),
//                                 _buildHeaderCell('Role'),
//                               ],
//                             ),
//                             ..._pagedUsers.map((doc) {
//                               final data = doc.data() as Map<String, dynamic>;
//                               // Combine name and surname if they exist separately
//                               final name = data['name'] ?? '';
//                               final surname = data['surname'] ?? '';
//                               final fullName = '$name $surname'.trim().isEmpty
//                                   ? 'N/A'
//                                   : '$name $surname';

//                               return TableRow(
//                                 children: [
//                                   _buildTableCell(fullName),
//                                   _buildTableCell(data['address'] ?? 'N/A'),
//                                   _buildTableCell(data['email'] ?? 'N/A'),
//                                   _buildTableCell(data['role'] ?? 'User'),
//                                 ],
//                               );
//                             }).toList(),
//                           ],
//                         ),
//                         // Users Pagination Controls
//                         if (totalUserPages > 1)
//                           Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 16.0),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               children: [
//                                 IconButton(
//                                   icon: Icon(Icons.chevron_left),
//                                   onPressed: _usersCurrentPage == 0
//                                       ? null
//                                       : () =>
//                                             setState(() => _usersCurrentPage--),
//                                 ),
//                                 Text(
//                                   'Page ${_usersCurrentPage + 1} of ${totalUserPages == 0 ? 1 : totalUserPages}',
//                                 ),
//                                 IconButton(
//                                   icon: Icon(Icons.chevron_right),
//                                   onPressed:
//                                       _usersCurrentPage >= totalUserPages - 1
//                                       ? null
//                                       : () =>
//                                             setState(() => _usersCurrentPage++),
//                                 ),
//                               ],
//                             ),
//                           ),
//                       ],
//                     ),

//               const SizedBox(height: 50),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // --- CHART HELPERS ---

//   List<PieChartSectionData> _generatePieSections() {
//     // Filter out provinces with 0 users for a cleaner chart
//     final activeProvinces = _provinceCounts.entries
//         .where((entry) => entry.value > 0)
//         .toList();

//     int total = 0;
//     for (var entry in activeProvinces) {
//       total += entry.value;
//     }

//     return activeProvinces.map((entry) {
//       final isLarge = isLargeScreen(context);
//       final double fontSize = isLarge ? 14 : 10;
//       final double radius = isLarge ? 100 : 80;
//       final percentage = (entry.value / total * 100).toStringAsFixed(1);

//       return PieChartSectionData(
//         color: _provinceColors[entry.key] ?? Colors.grey,
//         value: entry.value.toDouble(),
//         title: '${entry.value}\n($percentage%)',
//         radius: radius,
//         titleStyle: TextStyle(
//           fontSize: fontSize,
//           fontWeight: FontWeight.bold,
//           color: Colors.white,
//           shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
//         ),
//       );
//     }).toList();
//   }

//   Widget _buildLegend() {
//     final activeProvinces = _provinceCounts.entries
//         .where((entry) => entry.value > 0)
//         .toList();

//     // Sort so higher counts are first
//     activeProvinces.sort((a, b) => b.value.compareTo(a.value));

//     return Wrap(
//       spacing: 10,
//       runSpacing: 10,
//       children: activeProvinces.map((entry) {
//         return Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 12,
//               height: 12,
//               color: _provinceColors[entry.key] ?? Colors.grey,
//             ),
//             SizedBox(width: 4),
//             Text('${entry.key}: ${entry.value}'),
//           ],
//         );
//       }).toList(),
//     );
//   }

//   // --- HELPER WIDGETS ---

//   Widget _buildTableCell(String text) {
//     return Padding(
//       padding: const EdgeInsets.all(12.0),
//       child: Text(text, style: TextStyle(fontSize: 14)),
//     );
//   }

//   Widget _buildHeaderCell(String text) {
//     return Padding(
//       padding: const EdgeInsets.all(12.0),
//       child: Text(
//         text,
//         style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   Widget _buildDashboardCard({
//     required BuildContext context,
//     required String title,
//     required IconData icon,
//     required Future<QuerySnapshot> future,
//     required Color backgroundColor,
//     required double itemWidth,
//     required bool isDesktop,
//   }) {
//     final color = Theme.of(context);
//     return Container(
//       width: itemWidth,
//       height: 180,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(20),
//         color: backgroundColor,
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: FutureBuilder(
//           future: future,
//           builder: (context, snapshots) {
//             if (snapshots.connectionState == ConnectionState.waiting) {
//               return Shimmer.fromColors(
//                 baseColor: color.scaffoldBackgroundColor.withOpacity(0.8),
//                 highlightColor: color.hintColor.withOpacity(0.8),
//                 child: Container(color: Colors.white),
//               );
//             }

//             if (snapshots.hasError) {
//               return Center(
//                 child: Text(
//                   'Error',
//                   style: TextStyle(color: color.scaffoldBackgroundColor),
//                 ),
//               );
//             }

//             final data = snapshots.data;
//             final count = data!.docs.length;

//             return Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Flexible(
//                       child: Text(
//                         title,
//                         maxLines: isDesktop ? 2 : 3,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.w600,
//                           color: color.scaffoldBackgroundColor,
//                         ),
//                       ),
//                     ),
//                     Icon(icon, color: color.scaffoldBackgroundColor, size: 28),
//                   ],
//                 ),
//                 Text(
//                   '$count',
//                   style: TextStyle(
//                     fontSize: 60,
//                     fontWeight: FontWeight.w900,
//                     color: color.scaffoldBackgroundColor,
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
