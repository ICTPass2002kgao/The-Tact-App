// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED: Add fl_chart to pubspec.yaml
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

// --- IMPORT YOUR EXISTING PAGES HERE ---
import 'package:ttact/Pages/Add_Tactso_Branch.dart';
import 'package:ttact/Pages/AddMusic.dart';
import 'package:ttact/Pages/Admin_Add_Overseer.dart';
import 'package:ttact/Pages/Admin_Add_Product.dart';
import 'package:ttact/Pages/Admin_Verify_Seller.dart';
import 'package:ttact/Pages/AuditPage.dart';
import 'package:ttact/Pages/Portal_Add_Feed.dart';

// --- STYLING CONSTANTS ---
const Color kPrimaryColor = Color(0xFF1E1E2C); // Dark Navy for Sidebar
const Color kSecondaryColor = Color(0xFF2D2D44); // Lighter Navy
const Color kAccentColor = Color(0xFF5E72E4); // Bright Blue
const Color kBackgroundColor = Color(0xFFF4F6F9); // Light Grey Background
const double _desktopBreakpoint = 900.0;

bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

class AdminPortal extends StatefulWidget {
  const AdminPortal({super.key});

  @override
  _AdminPortalState createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  int _currentIndex = 0;
  bool _isAuthorized = false;

  // Define navigation items
  late final List<Map<String, dynamic>> _adminNavItems = [
    {
      'label': 'Dashboard',
      'icon': Ionicons.grid_outline,
      'page': ProfessionalDashboard(),
    },
    {
      'label': 'Products',
      'icon': Icons.shopping_bag_outlined,
      'page': AdminAddProduct(),
    },
    {
      'label': 'Songs',
      'icon': Ionicons.musical_notes_outline,
      'page': AddMusic(),
    },
    {
      'label': 'Branches',
      'icon': Icons.business_outlined,
      'page': AddTactsoBranch(),
    },
    {
      'label': 'Overseers',
      'icon': Icons.people_outline,
      'page': AdminAddOverseer(),
    },
    {
      'label': 'Sellers',
      'icon': Icons.storefront_outlined,
      'page': AdminVerifySeller(),
    },
    {
      'label': 'Audit Logs',
      'icon': Icons.receipt_long_outlined,
      'page': AuditPage(),
    },
    {'label': 'Feeds', 'icon': Icons.rss_feed, 'page': PortalAddFeed()},
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _checkAuthorization);
  }

  Future<void> _checkAuthorization() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final String role = userDoc.data()?['role'] ?? '';

      if (role == 'Admin') {
        setState(() => _isAuthorized = true);
      } else {
        if (mounted) Navigator.of(context).pushReplacementNamed('/main-menu');
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _handleLogout() async {
    Api().showLoading(context);
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    final isDesktop = isLargeScreen(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(_adminNavItems[_currentIndex]['label']),
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: isDesktop
          ? _buildDesktopLayout()
          : _adminNavItems[_currentIndex]['page'],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // 1. Sidebar
        NavigationRail(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          extended: MediaQuery.of(context).size.width >= 1100,
          backgroundColor: kPrimaryColor,
          selectedIconTheme: IconThemeData(color: kAccentColor, size: 28),
          unselectedIconTheme: IconThemeData(color: Colors.white70, size: 24),
          selectedLabelTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelTextStyle: TextStyle(color: Colors.white70),
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 40, top: 20),
            child: Image.asset('assets/tact_logo.PNG', height: 50, width: 50),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: IconButton(
                  icon: Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: _handleLogout,
                ),
              ),
            ),
          ),
          destinations: _adminNavItems
              .map(
                (item) => NavigationRailDestination(
                  icon: Icon(item['icon']),
                  label: Text(item['label']),
                ),
              )
              .toList(),
        ),

        // 2. Content
        Expanded(
          child: Container(
            color: kBackgroundColor,
            padding: EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _adminNavItems[_currentIndex]['page'],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(0)),
      ),
      backgroundColor: kPrimaryColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    backgroundImage: AssetImage('assets/tact_logo.PNG'),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Admin Portal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _adminNavItems.length,
              separatorBuilder: (ctx, i) =>
                  Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final item = _adminNavItems[index];
                final isSelected = _currentIndex == index;
                return ListTile(
                  leading: Icon(
                    item['icon'],
                    color: isSelected ? kAccentColor : Colors.white70,
                  ),
                  title: Text(
                    item['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  tileColor: isSelected ? kSecondaryColor : null,
                  onTap: () {
                    setState(() => _currentIndex = index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text("Logout", style: TextStyle(color: Colors.redAccent)),
            onTap: _handleLogout,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==============================================================================
// PROFESSIONAL DASHBOARD
// ==============================================================================

class ProfessionalDashboard extends StatefulWidget {
  const ProfessionalDashboard({super.key});

  @override
  State<ProfessionalDashboard> createState() => _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  // --- State for Overseer Management ---
  bool _isLoadingOverseers = true;
  List<DocumentSnapshot> _allOverseers = [];
  List<DocumentSnapshot> _filteredOverseers = [];
  final TextEditingController _searchController = TextEditingController();

  // Filters
  final List<String> _filterOptions = ['All Regions'];
  String _selectedFilter = 'All Regions';
  final List<String> _provinceFilterOptions = ['All Provinces'];
  String _selectedProvinceFilter = 'All Provinces';

  // Overseer Pagination
  int _pageSize = 20;
  int _currentPage = 0;

  // Futures for Top Graphs
  late Future<Map<String, int>> _pieChartDataFuture;
  late Future<List<FlSpot>> _lineChartDataFuture;

  // --- NEW: User Management & Province Stats State ---
  bool _isLoadingUsers = true;
  List<DocumentSnapshot> _allUsers = [];
  int _userPageSize = 10;
  int _usersCurrentPage = 0;

  Map<String, int> _provinceCounts = {
    'Eastern Cape': 0,
    'Free State': 0,
    'Gauteng': 0,
    'KwaZulu-Natal': 0,
    'Limpopo': 0,
    'Mpumalanga': 0,
    'Northern Cape': 0,
    'North West': 0,
    'Western Cape': 0,
    'Unknown': 0,
  };

  final Map<String, Color> _provinceColors = {
    'Eastern Cape': Colors.blue,
    'Free State': Colors.orange,
    'Gauteng': Colors.purple,
    'KwaZulu-Natal': Colors.green,
    'Limpopo': Colors.red,
    'Mpumalanga': Colors.yellow.shade700,
    'Northern Cape': Colors.teal,
    'North West': Colors.pink,
    'Western Cape': Colors.indigo,
    'Unknown': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _fetchAndSortOverseers();
    _fetchUsersAndStats(); // Calculates Province Pie & Populates User Table
    _searchController.addListener(_runFilters);

    // Initialize Other Graphs
    _pieChartDataFuture = _fetchRealPieData();
    _lineChartDataFuture = _fetchRealActivityData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_runFilters);
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. FETCH USERS & PROVINCE STATS ---
  Future<void> _fetchUsersAndStats() async {
    setState(() => _isLoadingUsers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      final docs = snapshot.docs;

      // Reset counts
      final Map<String, int> tempCounts = {
        'Eastern Cape': 0,
        'Free State': 0,
        'Gauteng': 0,
        'KwaZulu-Natal': 0,
        'Limpopo': 0,
        'Mpumalanga': 0,
        'Northern Cape': 0,
        'North West': 0,
        'Western Cape': 0,
        'Unknown': 0,
      };

      for (var doc in docs) {
        final data = doc.data();
        final address = (data['address'] ?? '').toString().toLowerCase();

        bool found = false;
        // Check standard 9 provinces
        for (String province in tempCounts.keys) {
          if (province == 'Unknown') continue;
          if (address.contains(province.toLowerCase())) {
            tempCounts[province] = (tempCounts[province] ?? 0) + 1;
            found = true;
            break;
          }
        }
        if (!found) {
          tempCounts['Unknown'] = (tempCounts['Unknown'] ?? 0) + 1;
        }
      }

      setState(() {
        _allUsers = docs;
        _provinceCounts = tempCounts;
        _isLoadingUsers = false;
      });
    } catch (e) {
      print("Error fetching users: $e");
      setState(() => _isLoadingUsers = false);
    }
  }

  // --- 2. FETCH ROLE DATA (Admin/Seller/Member) ---
  Future<Map<String, int>> _fetchRealPieData() async {
    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final members = await usersRef
          .where('role', isEqualTo: 'Member')
          .count()
          .get();
      final sellers = await usersRef
          .where('role', isEqualTo: 'Seller')
          .count()
          .get();
      final admins = await usersRef
          .where('role', isEqualTo: 'Admin')
          .count()
          .get();
      final overseers = await FirebaseFirestore.instance
          .collection('overseers')
          .count()
          .get();

      return {
        'Members': members.count ?? 0,
        'Sellers': sellers.count ?? 0,
        'Admins': admins.count ?? 0,
        'Overseers': overseers.count ?? 0,
      };
    } catch (e) {
      return {'Members': 0, 'Sellers': 0, 'Admins': 0, 'Overseers': 0};
    }
  }

  // --- 3. FETCH ACTIVITY DATA ---
  Future<List<FlSpot>> _fetchRealActivityData() async {
    try {
      DateTime now = DateTime.now();
      DateTime sevenDaysAgo = now.subtract(Duration(days: 7));
      final snapshot = await FirebaseFirestore.instance
          .collection('audit_logs')
          .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();

      Map<int, int> dailyCounts = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['timestamp'] != null) {
          DateTime date = (data['timestamp'] as Timestamp).toDate();
          int dayIndex = date.weekday - 1; // 0=Mon, 6=Sun
          if (dayIndex >= 0 && dayIndex <= 6) {
            dailyCounts[dayIndex] = (dailyCounts[dayIndex] ?? 0) + 1;
          }
        }
      }

      List<FlSpot> spots = [];
      dailyCounts.forEach((key, value) {
        spots.add(FlSpot(key.toDouble(), value.toDouble()));
      });
      spots.sort((a, b) => a.x.compareTo(b.x));
      return spots;
    } catch (e) {
      return [
        FlSpot(0, 0),
        FlSpot(1, 0),
        FlSpot(2, 0),
        FlSpot(3, 0),
        FlSpot(4, 0),
        FlSpot(5, 0),
        FlSpot(6, 0),
      ];
    }
  }

  // --- OVERSEER LOGIC ---
  Future<void> _fetchAndSortOverseers() async {
    setState(() => _isLoadingOverseers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .get();
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final aLen = (a.data()['districts'] as List? ?? []).length;
        final bLen = (b.data()['districts'] as List? ?? []).length;
        return bLen.compareTo(aLen);
      });

      final Set<String> regions = {'All Regions'};
      final Set<String> provinces = {'All Provinces'};
      for (var doc in docs) {
        final data = doc.data();
        if (data['region'] != null) regions.add(data['region']);
        if (data['province'] != null) provinces.add(data['province']);
      }

      setState(() {
        _allOverseers = docs;
        _filteredOverseers = docs;
        _filterOptions.clear();
        _filterOptions.addAll(regions.toList()..sort());
        _selectedFilter = 'All Regions';
        _provinceFilterOptions.clear();
        _provinceFilterOptions.addAll(provinces.toList()..sort());
        _selectedProvinceFilter = 'All Provinces';
        _isLoadingOverseers = false;
        _currentPage = 0;
      });
    } catch (e) {
      setState(() => _isLoadingOverseers = false);
    }
  }

  void _runFilters() {
    List<DocumentSnapshot> temp = _allOverseers;
    final query = _searchController.text.toLowerCase();

    if (query.isNotEmpty) {
      temp = temp.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['overseerInitialsAndSurname'] ?? '')
                .toLowerCase()
                .contains(query) ||
            (data['region'] ?? '').toLowerCase().contains(query) ||
            (data['code'] ?? '').toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedFilter != 'All Regions') {
      temp = temp
          .where((doc) => (doc.data() as Map)['region'] == _selectedFilter)
          .toList();
    }
    if (_selectedProvinceFilter != 'All Provinces') {
      temp = temp
          .where(
            (doc) => (doc.data() as Map)['province'] == _selectedProvinceFilter,
          )
          .toList();
    }

    setState(() {
      _filteredOverseers = temp;
      _currentPage = 0;
    });
  }

  // --- EDIT OVERSEER DIALOG ---
  void _showEditDialog(DocumentSnapshot overseerDoc) {
    final docData = overseerDoc.data() as Map<String, dynamic>;
    final List<Map<String, dynamic>> currentDistricts =
        List<Map<String, dynamic>>.from(
          (docData['districts'] as List? ?? []).map(
            (d) => Map<String, dynamic>.from(d),
          ),
        );

    final emailController = TextEditingController(text: docData['email'] ?? '');
    final regionController = TextEditingController(
      text: docData['region'] ?? '',
    );
    final codeController = TextEditingController(text: docData['code'] ?? '');
    final newDistrictController = TextEditingController();
    final newCommunityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit ${docData['overseerInitialsAndSurname']}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: codeController,
                              decoration: InputDecoration(
                                labelText: 'Code',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: regionController,
                        decoration: InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      Divider(height: 24),
                      Text(
                        'Districts & Communities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: currentDistricts.map((district) {
                              final communities = List<dynamic>.from(
                                district['communities'] as List? ?? [],
                              );
                              return ExpansionTile(
                                title: Text(
                                  district['districtElderName'] ?? 'Unnamed',
                                ),
                                subtitle: Text(
                                  '${communities.length} communities',
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => setDialogState(
                                    () => currentDistricts.remove(district),
                                  ),
                                ),
                                children: [
                                  ...communities.map(
                                    (c) => ListTile(
                                      title: Text(c['communityName'] ?? ''),
                                      trailing: IconButton(
                                        icon: Icon(Icons.close, size: 16),
                                        onPressed: () => setDialogState(
                                          () => communities.remove(c),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: newCommunityController,
                                            decoration: InputDecoration(
                                              labelText: 'Add Community',
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.add_circle,
                                            color: kAccentColor,
                                          ),
                                          onPressed: () {
                                            if (newCommunityController
                                                .text
                                                .isNotEmpty) {
                                              setDialogState(
                                                () => communities.add({
                                                  'communityName':
                                                      newCommunityController
                                                          .text
                                                          .trim(),
                                                }),
                                              );
                                              newCommunityController.clear();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newDistrictController,
                              decoration: InputDecoration(
                                labelText: 'New District Elder',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (newDistrictController.text.isNotEmpty) {
                                setDialogState(
                                  () => currentDistricts.add({
                                    'districtElderName': newDistrictController
                                        .text
                                        .trim(),
                                    'communities': [],
                                  }),
                                );
                                newDistrictController.clear();
                              }
                            },
                            child: Text('Add'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentColor,
                            ),
                            onPressed: () async {
                              Map<String, dynamic> updates = {
                                'email': emailController.text,
                                'region': regionController.text,
                                'code': codeController.text,
                                'districts': currentDistricts,
                              };
                              await overseerDoc.reference.update(updates);
                              Navigator.pop(context);
                              _fetchAndSortOverseers();
                            },
                            child: Text('Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Overseer Pagination
    final int totalItems = _filteredOverseers.length;
    final int totalPages = (totalItems / _pageSize).ceil();
    final int startIndex = _currentPage * _pageSize;
    final int endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;
    final List<DocumentSnapshot> pagedOverseers = (totalItems > 0)
        ? _filteredOverseers.sublist(startIndex, endIndex)
        : [];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Dashboard Overview",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: 20),

            // --- 1. SUMMARY CARDS ---
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200
                    ? 4
                    : constraints.maxWidth > 800
                    ? 4
                    : 1;
                double childAspectRatio = crossAxisCount == 4 ? 1.8 : 2.2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  children: [
                    _buildSummaryCard(
                      "Total Users",
                      "users",
                      Icons.people,
                      Colors.blue,
                    ),
                    _buildSummaryCard(
                      "Branches",
                      "tactso_branches",
                      Icons.business,
                      Colors.orange,
                    ),
                    _buildSummaryCard(
                      "Overseers",
                      "overseers",
                      Icons.people_alt,
                      Colors.purple,
                    ),
                    _buildSummaryCard(
                      "Products",
                      "products",
                      Icons.shopping_cart,
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      "Music Tracks",
                      "tact_music",
                      Icons.music_note,
                      Colors.purple,
                    ),
                  ],
                );
              },
            ),

            SizedBox(height: 30),

            // --- 2. EXISTING GRAPHS (Activity & Roles) ---
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildLineChartSection()),
                      SizedBox(width: 20),
                      Expanded(flex: 1, child: _buildPieChartSection()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildLineChartSection(),
                      SizedBox(height: 20),
                      _buildPieChartSection(),
                    ],
                  );
                }
              },
            ),

            SizedBox(height: 30),

            // --- 3. NEW: PROVINCE DISTRIBUTION PIE CHART ---
            _buildProvinceChartSection(),

            SizedBox(height: 40),
            Divider(),
            SizedBox(height: 20),

            // --- 4. OVERSEER MANAGEMENT TABLE ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overseer Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                if (MediaQuery.of(context).size.width > 600)
                  Row(
                    children: [
                      _buildDropdown(_filterOptions, _selectedFilter, (v) {
                        setState(() {
                          _selectedFilter = v!;
                          _runFilters();
                        });
                      }),
                      SizedBox(width: 10),
                      _buildDropdown(
                        _provinceFilterOptions,
                        _selectedProvinceFilter,
                        (v) {
                          setState(() {
                            _selectedProvinceFilter = v!;
                            _runFilters();
                          });
                        },
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: 15),

            if (MediaQuery.of(context).size.width <= 600)
              Column(
                children: [
                  _buildDropdown(_filterOptions, _selectedFilter, (v) {
                    setState(() {
                      _selectedFilter = v!;
                      _runFilters();
                    });
                  }),
                  SizedBox(height: 10),
                  _buildDropdown(
                    _provinceFilterOptions,
                    _selectedProvinceFilter,
                    (v) {
                      setState(() {
                        _selectedProvinceFilter = v!;
                        _runFilters();
                      });
                    },
                  ),
                  SizedBox(height: 10),
                ],
              ),

            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: "Search Overseer, Region or Code...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // OVERSEER TABLE
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: _isLoadingOverseers
                  ? Center(child: CircularProgressIndicator())
                  : _filteredOverseers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text('No overseers found.'),
                      ),
                    )
                  : Column(
                      children: [
                        Table(
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1),
                            5: FixedColumnWidth(50),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                              ),
                              children: [
                                _buildHeaderCell('Name'),
                                _buildHeaderCell('Region'),
                                _buildHeaderCell('Code'),
                                _buildHeaderCell('Districts'),
                                _buildHeaderCell('Members'),
                                _buildHeaderCell(''),
                              ],
                            ),
                            ...pagedOverseers.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final districts = data['districts'] as List?;
                              final distCount =
                                  districts?.length.toString() ?? '0';
                              final overseerUid = data['uid'] ?? doc.id;

                              return TableRow(
                                children: [
                                  _buildTableCell(
                                    data['overseerInitialsAndSurname'] ?? 'N/A',
                                    isBold: true,
                                  ),
                                  _buildTableCell(data['region'] ?? '-'),
                                  _buildTableCell(data['code'] ?? '-'),
                                  Center(child: Text(distCount)),
                                  FutureBuilder<AggregateQuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .where(
                                          'overseerUid',
                                          isEqualTo: overseerUid,
                                        )
                                        .count()
                                        .get(),
                                    builder: (context, snap) {
                                      if (snap.hasData)
                                        return Center(
                                          child: Text(
                                            snap.data!.count.toString(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: kAccentColor,
                                            ),
                                          ),
                                        );
                                      return Center(child: Text("-"));
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.grey),
                                    onPressed: () => _showEditDialog(doc),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left),
                              onPressed: _currentPage == 0
                                  ? null
                                  : () => setState(() => _currentPage--),
                            ),
                            Text(
                              "Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}",
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right),
                              onPressed: _currentPage >= totalPages - 1
                                  ? null
                                  : () => setState(() => _currentPage++),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            SizedBox(height: 40),
            Divider(),
            SizedBox(height: 20),

            // --- 5. NEW: REGISTERED USERS TABLE ---
            _buildUsersTableSection(),

            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- NEW WIDGET: PROVINCE CHART SECTION ---
  Widget _buildProvinceChartSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
            "User Distribution by Province",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          SizedBox(height: 20),
          _isLoadingUsers
              ? Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 300,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _generateProvincePieSections(),
                          ),
                        ),
                      ),
                    ),
                    Expanded(flex: 1, child: _buildProvinceLegend()),
                  ],
                ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateProvincePieSections() {
    final activeProvinces = _provinceCounts.entries
        .where((entry) => entry.value > 0)
        .toList();

    int total = activeProvinces.fold(0, (sum, item) => sum + item.value);

    return activeProvinces.map((entry) {
      final percentage = total == 0 ? 0.0 : (entry.value / total * 100);
      return PieChartSectionData(
        color: _provinceColors[entry.key] ?? Colors.grey,
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 90,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    }).toList();
  }

  Widget _buildProvinceLegend() {
    final activeProvinces = _provinceCounts.entries
        .where((entry) => entry.value > 0)
        .toList();
    // Sort descending
    activeProvinces.sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: activeProvinces.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _provinceColors[entry.key] ?? Colors.grey,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- NEW WIDGET: USERS TABLE SECTION ---
  Widget _buildUsersTableSection() {
    // Pagination Logic for Users
    final int totalUserItems = _allUsers.length;
    final int totalUserPages = (totalUserItems / _userPageSize).ceil();
    final int startUserIndex = _usersCurrentPage * _userPageSize;
    final int endUserIndex = (startUserIndex + _userPageSize > totalUserItems)
        ? totalUserItems
        : startUserIndex + _userPageSize;
    final List<DocumentSnapshot> pagedUsers = (totalUserItems > 0)
        ? _allUsers.sublist(startUserIndex, endUserIndex)
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Users',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            Icon(Icons.group, color: kPrimaryColor),
          ],
        ),
        SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          padding: EdgeInsets.all(16),
          child: _isLoadingUsers
              ? Center(child: CircularProgressIndicator())
              : _allUsers.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No users found."),
                  ),
                )
              : Column(
                  children: [
                    Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(2), // Name
                        1: FlexColumnWidth(2.5), // Address
                        2: FlexColumnWidth(2), // Email
                        3: FlexColumnWidth(1), // Role
                      },
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade50),
                          children: [
                            _buildHeaderCell('Name & Surname'),
                            _buildHeaderCell('Address'),
                            _buildHeaderCell('Email'),
                            _buildHeaderCell('Role'),
                          ],
                        ),
                        ...pagedUsers.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name'] ?? '';
                          final surname = data['surname'] ?? '';
                          final fullName = '$name $surname'.trim().isEmpty
                              ? 'N/A'
                              : '$name $surname';

                          return TableRow(
                            children: [
                              _buildTableCell(fullName, isBold: true),
                              _buildTableCell(data['address'] ?? 'N/A'),
                              _buildTableCell(data['email'] ?? 'N/A'),
                              _buildTableCell(data['role'] ?? 'User'),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                    SizedBox(height: 10),
                    // Users Pagination
                    if (totalUserPages > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left),
                            onPressed: _usersCurrentPage == 0
                                ? null
                                : () => setState(() => _usersCurrentPage--),
                          ),
                          Text(
                            "Page ${_usersCurrentPage + 1} of $totalUserPages",
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right),
                            onPressed: _usersCurrentPage >= totalUserPages - 1
                                ? null
                                : () => setState(() => _usersCurrentPage++),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // --- GENERAL WIDGET HELPERS ---

  Widget _buildDropdown(
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        underline: SizedBox(),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String collection,
    IconData icon,
    Color color,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        String count = "...";
        if (snapshot.hasData) count = snapshot.data!.docs.length.toString();
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      count,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLineChartSection() {
    return Container(
      height: 400,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
            "Activity Analytics (Audit Logs)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          SizedBox(height: 5),
          Text(
            "Logs per day (Last 7 days)",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<FlSpot>>(
              future: _lineChartDataFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                return LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: bottomTitleWidgets,
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: snapshot.data!,
                        isCurved: true,
                        color: kAccentColor,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: kAccentColor.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    return Container(
      height: 400,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
            "User Roles",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<Map<String, int>>(
              future: _pieChartDataFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final total =
                    data['Members']! +
                    data['Sellers']! +
                    data['Admins']! +
                    data['Overseers']!;
                double percent(int val) => total == 0 ? 0 : (val / total) * 100;

                return PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        color: Colors.blue,
                        value: data['Members']!.toDouble(),
                        title:
                            '${percent(data['Members']!).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.orange,
                        value: data['Sellers']!.toDouble(),
                        title:
                            '${percent(data['Sellers']!).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.purple,
                        value: data['Overseers']!.toDouble(),
                        title:
                            '${percent(data['Overseers']!).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        color: Colors.green,
                        value: data['Admins']!.toDouble(),
                        title:
                            '${percent(data['Admins']!).toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _indicator(Colors.blue, "Members"),
              _indicator(Colors.orange, "Sellers"),
            ],
          ),
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _indicator(Colors.purple, "Overseers"),
              _indicator(Colors.green, "Admins"),
            ],
          ),
        ],
      ),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    Widget text;
    switch (value.toInt()) {
      case 0:
        text = const Text('Mon', style: style);
        break;
      case 2:
        text = const Text('Wed', style: style);
        break;
      case 4:
        text = const Text('Fri', style: style);
        break;
      case 6:
        text = const Text('Sun', style: style);
        break;
      default:
        text = const Text('', style: style);
    }
    return SideTitleWidget(meta: meta, child: text);
  }

  Widget _indicator(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
