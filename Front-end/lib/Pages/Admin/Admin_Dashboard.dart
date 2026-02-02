// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Admin/Admin_Portal.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

class ProfessionalDashboard extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const ProfessionalDashboard({super.key, this.uid, this.portfolio, this.fullName, this.province});

  @override
  State<ProfessionalDashboard> createState() => _ProfessionalDashboardState();
}

class _ProfessionalDashboardState extends State<ProfessionalDashboard> {
  // ⭐️ PREMIUM BASE COLOR (Matches the Admin Portal Sidebar/Bg Mix)
  final Color _baseColor = const Color(0xFFEFF4F9);

  // --- State Variables ---
  bool _isLoadingOverseers = true;
  List<DocumentSnapshot> _allOverseers = [];
  List<DocumentSnapshot> _filteredOverseers = [];
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterOptions = ['All Regions'];
  String _selectedFilter = 'All Regions';
  final List<String> _provinceFilterOptions = ['All Provinces'];
  String _selectedProvinceFilter = 'All Provinces';

  int _pageSize = 20;
  int _currentPage = 0;

  late Future<Map<String, int>> _pieChartDataFuture;
  late Future<List<FlSpot>> _lineChartDataFuture;

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
    _fetchUsersAndStats();
    _searchController.addListener(_runFilters);
    _pieChartDataFuture = _fetchRealPieData();
    _lineChartDataFuture = _fetchRealActivityData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_runFilters);
    _searchController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic (Preserved) ---
  Future<void> _fetchUsersAndStats() async {
    setState(() => _isLoadingUsers = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      final docs = snapshot.docs;
      final Map<String, int> tempCounts = Map.from(
        _provinceCounts,
      ).map((key, value) => MapEntry(key, 0));

      for (var doc in docs) {
        final data = doc.data();
        final address = (data['address'] ?? '').toString().toLowerCase();
        bool found = false;
        for (String province in tempCounts.keys) {
          if (province == 'Unknown') continue;
          if (address.contains(province.toLowerCase())) {
            tempCounts[province] = (tempCounts[province] ?? 0) + 1;
            found = true;
            break;
          }
        }
        if (!found) tempCounts['Unknown'] = (tempCounts['Unknown'] ?? 0) + 1;
      }

      setState(() {
        _allUsers = docs;
        _provinceCounts = tempCounts;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
    }
  }

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
          int dayIndex = date.weekday - 1;
          if (dayIndex >= 0 && dayIndex <= 6) {
            dailyCounts[dayIndex] = (dailyCounts[dayIndex] ?? 0) + 1;
          }
        }
      }
      List<FlSpot> spots = [];
      dailyCounts.forEach(
        (key, value) => spots.add(FlSpot(key.toDouble(), value.toDouble())),
      );
      spots.sort((a, b) => a.x.compareTo(b.x));
      return spots;
    } catch (e) {
      return List.generate(7, (index) => FlSpot(index.toDouble(), 0));
    }
  }

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
        _provinceFilterOptions.clear();
        _provinceFilterOptions.addAll(provinces.toList()..sort());
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

  void _showEditDialog(DocumentSnapshot overseerDoc) {
    // Implement edit logic here if needed
  }

  // ⭐️⭐️⭐️ HELPER: THE PREMIUM CARD WITH VERTICAL ACCENT LINE ⭐️⭐️⭐️
  Widget _buildPremiumCard({
    required Widget child,
    Color? accentColor,
    double padding = 20.0,
  }) {
    return NeumorphicContainer(
      borderRadius: 16,
      padding: EdgeInsets.zero, // Padding handled internally
      color: _baseColor,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The Vertical Beauty Line
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor ?? Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (accentColor ?? Theme.of(context).primaryColor)
                        .withOpacity(0.4),
                    blurRadius: 8,
                    offset: Offset(2, 0),
                  ),
                ],
              ),
            ),
            // The Content
            Expanded(
              child: Padding(padding: EdgeInsets.all(padding), child: child),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pagination Calculation
    final int totalItems = _filteredOverseers.length;
    final int totalPages = (totalItems / _pageSize).ceil();
    final int startIndex = _currentPage * _pageSize;
    final int endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;
    final List<DocumentSnapshot> pagedOverseers = (totalItems > 0)
        ? _filteredOverseers.sublist(startIndex, endIndex)
        : [];

    return Scaffold(
      backgroundColor: _baseColor, // Set the Neumorphic Base
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Dashboard Overview",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey[800],
                  letterSpacing: -0.5,
                  fontFamily: 'Roboto',
                ),
              ),
              SizedBox(height: 25),

              // --- 1. SUMMARY CARDS ---
              LayoutBuilder(
                builder: (context, constraints) {
                  // Adaptive Grid
                  int crossAxisCount = constraints.maxWidth > 1300
                      ? 4
                      : constraints.maxWidth > 800
                      ? 2
                      : 1;
                  double aspectRatio = constraints.maxWidth > 1300 ? 2.2 : 3.0;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    children: [
                      _buildNeumorphicSummaryCard(
                        "Total Users",
                        "users",
                        Icons.people,
                        Colors.blue,
                      ),
                      _buildNeumorphicSummaryCard(
                        "Branches",
                        "tactso_branches",
                        Icons.business,
                        Colors.orange,
                      ),
                      _buildNeumorphicSummaryCard(
                        "Overseers",
                        "overseers",
                        Icons.people_alt,
                        Colors.purple,
                      ),
                      _buildNeumorphicSummaryCard(
                        "Products",
                        "products",
                        Icons.shopping_cart,
                        Colors.green,
                      ),
                      _buildNeumorphicSummaryCard(
                        "Music",
                        "tact_music",
                        Icons.music_note,
                        Colors.indigo,
                      ),
                    ],
                  );
                },
              ),

              SizedBox(height: 30),

              // --- 2. GRAPHS (Line & Pie) ---
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 1000) {
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

              // --- 3. PROVINCE CHART ---
              _buildProvinceChartSection(),

              SizedBox(height: 40),

              // Divider
              NeumorphicContainer(
                isPressed: true,
                padding: EdgeInsets.zero,
                borderRadius: 2,
                color: _baseColor,
                child: SizedBox(height: 2, width: double.infinity),
              ),
              SizedBox(height: 30),

              // --- 4. OVERSEER TABLE ---
              _buildOverseerHeader(),
              SizedBox(height: 20),

              // Search Bar (Inset/Pressed Look)
              NeumorphicContainer(
                isPressed: true,
                borderRadius: 12,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: _baseColor,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    icon: Icon(Icons.search, color: Colors.grey),
                    hintText: "Search Overseer, Region or Code...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Table Card
              _buildPremiumCard(
                accentColor: Theme.of(context).primaryColor,
                padding: 10,
                child: _isLoadingOverseers
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _filteredOverseers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text('No overseers found.'),
                        ),
                      )
                    : Column(
                        children: [
                          Table(
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: Colors.grey.withOpacity(0.1),
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
                                return TableRow(
                                  children: [
                                    _buildTableCell(
                                      data['overseerInitialsAndSurname'] ??
                                          'N/A',
                                      isBold: true,
                                    ),
                                    _buildTableCell(data['region'] ?? '-'),
                                    _buildTableCell(data['code'] ?? '-'),
                                    Center(
                                      child: Text(
                                        (data['districts'] as List?)?.length
                                                .toString() ??
                                            '0',
                                      ),
                                    ),
                                    FutureBuilder<AggregateQuerySnapshot>(
                                      future: FirebaseFirestore.instance
                                          .collection('users')
                                          .where(
                                            'overseerUid',
                                            isEqualTo: data['uid'] ?? doc.id,
                                          )
                                          .count()
                                          .get(),
                                      builder: (context, snap) => Center(
                                        child: Text(
                                          snap.hasData
                                              ? snap.data!.count.toString()
                                              : "-",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => _showEditDialog(doc),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                          SizedBox(height: 10),
                          // Pagination
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

              // --- 5. USERS TABLE ---
              _buildUsersTableSection(),
              SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🧩 COMPONENT BUILDERS
  // ===========================================================================

  Widget _buildOverseerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Overseer Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[800],
          ),
        ),
        if (MediaQuery.of(context).size.width > 700)
          Row(
            children: [
              _buildNeumorphicDropdown(_filterOptions, _selectedFilter, (v) {
                setState(() {
                  _selectedFilter = v!;
                  _runFilters();
                });
              }),
              SizedBox(width: 15),
              _buildNeumorphicDropdown(
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
    );
  }

  Widget _buildUsersTableSection() {
    final int totalUserItems = _allUsers.length;
    final int totalUserPages = (totalUserItems / _userPageSize).ceil();
    final int startUserIndex = _usersCurrentPage * _userPageSize;
    final int endUserIndex = (startUserIndex + _userPageSize > totalUserItems)
        ? totalUserItems
        : startUserIndex + _userPageSize;
    final List<DocumentSnapshot> actualPagedUsers = (totalUserItems > 0)
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
                color: Colors.blueGrey[800],
              ),
            ),
            NeumorphicContainer(
              borderRadius: 50,
              padding: EdgeInsets.all(8),
              color: _baseColor,
              child: Icon(Icons.group, color: Theme.of(context).primaryColor),
            ),
          ],
        ),
        SizedBox(height: 15),

        _buildPremiumCard(
          accentColor: Colors.teal,
          padding: 16,
          child: _isLoadingUsers
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _allUsers.isEmpty
              ? Center(child: Text("No users found."))
              : Column(
                  children: [
                    Table(
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                        ),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(1),
                      },
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            _buildHeaderCell('Name & Surname'),
                            _buildHeaderCell('Address'),
                            _buildHeaderCell('Email'),
                            _buildHeaderCell('Role'),
                          ],
                        ),
                        ...actualPagedUsers.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return TableRow(
                            children: [
                              _buildTableCell(
                                '${data['name']} ${data['surname']}',
                                isBold: true,
                              ),
                              _buildTableCell(data['address'] ?? 'N/A'),
                              _buildTableCell(data['email'] ?? 'N/A'),
                              _buildTableCell(data['role'] ?? 'User'),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                    SizedBox(height: 10),
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

  Widget _buildProvinceChartSection() {
    return _buildPremiumCard(
      accentColor: Colors.orangeAccent,
      padding: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "User Distribution",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[800],
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

  // --- Charts & Summaries ---

  Widget _buildNeumorphicSummaryCard(
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

        return _buildPremiumCard(
          accentColor: color,
          padding: 16,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              NeumorphicContainer(
                isPressed: true, // Inset Icon
                borderRadius: 12,
                padding: EdgeInsets.all(10),
                color: _baseColor,
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineChartSection() {
    return SizedBox(
      height: 350,
      child: _buildPremiumCard(
        accentColor: Theme.of(context).primaryColor,
        padding: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Activity Analytics",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
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
                      borderData: FlBorderData(show: false),
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
                      lineBarsData: [
                        LineChartBarData(
                          spots: snapshot.data!,
                          isCurved: true,
                          color: Theme.of(context).primaryColor,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
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
      ),
    );
  }

  Widget _buildPieChartSection() {
    return SizedBox(
      height: 350,
      child: _buildPremiumCard(
        accentColor: Colors.purpleAccent,
        padding: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "User Roles",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
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
                  double percent(int val) =>
                      total == 0 ? 0 : (val / total) * 100;

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
                          radius: 45,
                          titleStyle: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.orange,
                          value: data['Sellers']!.toDouble(),
                          title:
                              '${percent(data['Sellers']!).toStringAsFixed(0)}%',
                          radius: 45,
                          titleStyle: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.purple,
                          value: data['Overseers']!.toDouble(),
                          title:
                              '${percent(data['Overseers']!).toStringAsFixed(0)}%',
                          radius: 45,
                          titleStyle: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.green,
                          value: data['Admins']!.toDouble(),
                          title:
                              '${percent(data['Admins']!).toStringAsFixed(0)}%',
                          radius: 45,
                          titleStyle: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _indicator(Colors.blue, "Members"),
                _indicator(Colors.orange, "Sellers"),
                _indicator(Colors.purple, "Overseers"),
                _indicator(Colors.green, "Admins"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---

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
        radius: 80,
        titleStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildProvinceLegend() {
    final activeProvinces = _provinceCounts.entries
        .where((entry) => entry.value > 0)
        .toList();
    activeProvinces.sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: activeProvinces.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _provinceColors[entry.key] ?? Colors.grey,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.key}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[800],
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _indicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
      ],
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    Widget text;
    switch (value.toInt()) {
      case 0:
        text = const Text('Mon', style: style);
        break;
      case 3:
        text = const Text('Thu', style: style);
        break;
      case 6:
        text = const Text('Sun', style: style);
        break;
      default:
        text = const Text('', style: style);
    }
    return SideTitleWidget(meta: meta, child: text);
  }

  Widget _buildNeumorphicDropdown(
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return NeumorphicContainer(
      borderRadius: 12,
      color: _baseColor,
      isPressed: true, // Inset look for controls
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
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
}
