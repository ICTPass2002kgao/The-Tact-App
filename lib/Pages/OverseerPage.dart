// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print, unnecessary_null_comparison, unused_import, unused_field, avoid_returning_null_for_void

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart';

// --- Chart Package Import ---
import 'package:fl_chart/fl_chart.dart';
// ----------------------------

// PDF Generation Imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Local Imports
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/PaystackWebView.dart';
import 'package:ttact/Components/paystack_service.dart';
import 'package:ttact/Pages/payment_opened_dialog.dart';
import 'package:ttact/Pages/subscribtion_screen.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

// --- PLATFORM AND LAYOUT UTILITIES ---
bool get _useCupertinoStyle =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
const double _tabletBreakpoint = 768.0;
const double _desktopBreakpoint = 1100.0; // Breakpoint for Sidebar vs Drawer

class OverseerPage extends StatefulWidget {
  const OverseerPage({super.key});

  @override
  State<OverseerPage> createState() => _OverseerPageState();
}

class _OverseerPageState extends State<OverseerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0; // Used for Sidebar navigation sync

  Uint8List? _logoBytes;

  // --- PAYSTACK/SUBSCRIPTION STATE ---
  bool _isSubscriptionActive = false;

  // --- TEXT CONTROLLERS & STATE ---
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberEmailController = TextEditingController();
  final TextEditingController memberAddressController = TextEditingController();
  final TextEditingController memberContactController = TextEditingController();
  final TextEditingController memberSurnameController = TextEditingController();

  // Tithe Editing Controllers
  final TextEditingController week1Controller = TextEditingController();
  final TextEditingController week2Controller = TextEditingController();
  final TextEditingController week3Controller = TextEditingController();
  final TextEditingController week4Controller = TextEditingController();

  // Officer Controllers
  final TextEditingController officerNameController = TextEditingController();
  final TextEditingController communityOfficerController =
      TextEditingController();

  // Dropdown States
  String? selectedDistrictElder;
  String? selectedCommunityName;
  String selectedProvince = '';

  // --- CHART DATA STATE ---
  List<BarChartGroupData> _monthlyOfferingsData = [];
  Map<String, double> _districtTotals = {};
  double _maxOfferingAmount = 0.0;
  Map<String, int> _districtMemberCounts = {};
  int _totalMemberCountForChart = 0;
  Map<int, double> _weeklyTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
  double _maxWeeklyTithe = 0.0;
  int _currentPage = 0;
  final int _rowsPerPage = 30;

  final List<Color> _pieColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = 0;
        });
      }
    });
    _loadLogoBytes();
    _checkSubscriptionStatusFromFirestore();
    _loadDashboardData();

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndEnforceSubscription();
    });
  }

  // --- PAYSTACK LOGIC ---
  Future<void> _checkAndEnforceSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int memberCount = await _getTotalOverseerMemberCount();
    String? requiredPlan = PaystackService.getRequiredPlan(memberCount);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('overseers')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final userDoc = querySnapshot.docs.first;
    String? currentPlan = userDoc.data()['currentPlan'];
    String status = userDoc.data()['subscriptionStatus'] ?? 'inactive';

    if (requiredPlan == null) {
      if (status != 'active' || currentPlan != 'free_tier') {
        await userDoc.reference.set({
          'subscriptionStatus': 'active',
          'currentPlan': 'free_tier',
        }, SetOptions(merge: true));
      }
      return;
    }

    if (status != 'active' || currentPlan != requiredPlan) {
      if (mounted) {
        _showSubscriptionLockedScreen(context, requiredPlan, memberCount);
      }
    }
  }

  void _showSubscriptionLockedScreen(
    BuildContext context,
    String planCode,
    int count,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SubscriptionPlansScreen(
        requiredPlanCode: planCode,
        onSubscribe: (selectedPlanCode) async {
          Navigator.pop(context);
          await _startPaystackPayment(selectedPlanCode, count);
        },
      ),
    );
  }

  Future<void> _startPaystackPayment(String planCode, int count) async {
    final user = FirebaseAuth.instance.currentUser;
    String? authUrl = await PaystackService.initializeSubscription(
      email: user!.email!,
      planCode: planCode,
      memberCount: count,
    );

    if (authUrl != null && mounted) {
      if (kIsWeb) {
        final Uri url = Uri.parse(authUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PaymentOpenedDialog(
              onPaid: () {
                Navigator.pop(ctx);
                _checkAndEnforceSubscription();
              },
            ),
          );
        }
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaystackWebView(
              authUrl: authUrl,
              onSuccess: () async {
                final querySnapshot = await FirebaseFirestore.instance
                    .collection('overseers')
                    .where('uid', isEqualTo: user.uid)
                    .limit(1)
                    .get();

                if (querySnapshot.docs.isNotEmpty) {
                  await querySnapshot.docs.first.reference.set({
                    'subscriptionStatus': 'active',
                    'currentPlan': planCode,
                    'lastPaymentDate': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
                _checkAndEnforceSubscription();
              },
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to initialize payment. Please try again."),
        ),
      );
    }
  }

  // --- DATA FETCHING LOGIC ---
  Future<int> _getTotalOverseerMemberCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('overseerUid', isEqualTo: uid)
        .get();
    return snapshot.docs.length; // UNCOMMENT FOR PRODUCTION
    // return 60; // HARDCODED FOR TESTING
  }

  Future<void> _checkSubscriptionStatusFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final qs = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: uid)
          .get();
      if (mounted && qs.docs.isNotEmpty) {
        setState(() {
          _isSubscriptionActive =
              qs.docs.first.data()['subscriptionStatus'] == 'active';
        });
      }
    } catch (e) {
      print("Firestore Subscription Check Error: $e");
    }
  }

  Future<void> _loadDashboardData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('overseerUid', isEqualTo: uid)
          .get();

      Map<String, double> districtTitheTotals = {};
      Map<String, int> districtMemberCounts = {};
      Map<int, double> weeklyTitheTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
      double maxTitheTotal = 0.0;
      int totalMembers = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMembers++;
        final districtName =
            data['districtElderName'] as String? ?? 'Unassigned';
        final w1 = (data['week1'] as num? ?? 0.0).toDouble();
        final w2 = (data['week2'] as num? ?? 0.0).toDouble();
        final w3 = (data['week3'] as num? ?? 0.0).toDouble();
        final w4 = (data['week4'] as num? ?? 0.0).toDouble();
        final monthlyTotal = w1 + w2 + w3 + w4;

        districtTitheTotals.update(
          districtName,
          (v) => v + monthlyTotal,
          ifAbsent: () => monthlyTotal,
        );
        districtMemberCounts.update(
          districtName,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
        weeklyTitheTotals[1] = (weeklyTitheTotals[1] ?? 0) + w1;
        weeklyTitheTotals[2] = (weeklyTitheTotals[2] ?? 0) + w2;
        weeklyTitheTotals[3] = (weeklyTitheTotals[3] ?? 0) + w3;
        weeklyTitheTotals[4] = (weeklyTitheTotals[4] ?? 0) + w4;
      }

      List<BarChartGroupData> chartGroups = [];
      int index = 0;
      districtTitheTotals.forEach((district, total) {
        chartGroups.add(
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total,
                color: Theme.of(context).primaryColor,
                width: 15,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            showingTooltipIndicators: [0],
          ),
        );
        if (total > maxTitheTotal) maxTitheTotal = total;
        index++;
      });

      double maxWeekly = weeklyTitheTotals.values.reduce(
        (curr, next) => curr > next ? curr : next,
      );

      if (mounted) {
        setState(() {
          _monthlyOfferingsData = chartGroups;
          _districtTotals = districtTitheTotals;
          _maxOfferingAmount = maxTitheTotal > 0 ? maxTitheTotal * 1.2 : 100.0;
          _districtMemberCounts = districtMemberCounts;
          _totalMemberCountForChart = totalMembers;
          _weeklyTotals = weeklyTitheTotals;
          _maxWeeklyTithe = maxWeekly > 0 ? maxWeekly * 1.2 : 100.0;
        });
      }
    } catch (e) {
      print("Error loading dashboard data: $e");
    }
  }

  String? _filterDistrict;
  String? _filterCommunity;

  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      setState(() {
        _logoBytes = bytes.buffer.asUint8List();
      });
    } catch (e) {
      _logoBytes = null;
    }
  }

  Future<int> _getTotalOverseerDistrictCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: uid)
          .get();
      final data = snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
      final districts = data?['districts'] as List<dynamic>?;
      return districts?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTotalOverseerBranchCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: uid)
          .get();
      final data = snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
      final districts = data?['districts'] as List<dynamic>?;
      int totalBranches = 0;
      for (var district in districts ?? []) {
        final branches = district['communities'] as List<dynamic>?;
        totalBranches += branches?.length ?? 0;
      }
      return totalBranches;
    } catch (e) {
      return 0;
    }
  }

  // --- UI HELPERS ---
  Widget _platformTextField({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    bool obscureText = false,
    IconData? prefixIcon,
  }) {
    final ThemeData color = Theme.of(context);
    if (_useCupertinoStyle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscureText,
          keyboardType: keyboardType,
          prefix: prefixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(prefixIcon, color: Colors.grey),
                )
              : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(14.0),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: placeholder,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.all(14.0),
          ),
        ),
      );
    }
  }

  // --- BUILDERS FOR MAIN LAYOUT ---

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= _desktopBreakpoint;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF5F7FA,
      ), // Light grey bg for better contrast
      // Only show AppBar on mobile/tablet
      appBar: !isLargeScreen
          ? AppBar(
              title: const Text('Overseer Dashboard'),
              centerTitle: true,
              foregroundColor: Colors.white,
              backgroundColor: color.primaryColor,
              bottom: TabBar(
                isScrollable: true,
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Add Member'),
                  Tab(text: 'All Members'),
                  Tab(text: 'Add Officer'),
                  Tab(text: 'Reports'),
                ],
              ),
            )
          : null,
      drawer: !isLargeScreen ? _buildMobileDrawer(context) : null,
      body: isLargeScreen
          ? Row(
              children: [
                // --- SIDEBAR FOR LARGE SCREENS ---
                Container(
                  width: 280,
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        height: 150,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: color.primaryColor),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_logoBytes != null)
                              Image.memory(_logoBytes!, height: 60)
                            else
                              Icon(Icons.church, size: 50, color: Colors.white),
                            SizedBox(height: 10),
                            Text(
                              "Overseer Portal",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          children: [
                            _buildSidebarItem(0, Icons.dashboard, "Dashboard"),
                            _buildSidebarItem(
                              1,
                              Icons.person_add,
                              "Add Member",
                            ),
                            _buildSidebarItem(2, Icons.people, "All Members"),
                            _buildSidebarItem(3, Icons.badge, "Add Officer"),
                            _buildSidebarItem(4, Icons.receipt_long, "Reports"),
                            Divider(),
                            ListTile(
                              leading: Icon(Icons.logout, color: Colors.red),
                              title: Text(
                                "Logout",
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () async {
                                await FirebaseAuth.instance.signOut();
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove('authToken');
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // --- MAIN CONTENT AREA ---
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(24),
                    child: _buildBodyContent(isLargeScreen),
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: _buildTabChildren(false), // Mobile Layout
            ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    final color = Theme.of(context).primaryColor;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? color : Colors.grey),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? color : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _tabController.index = index;
          });
        },
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Center(
              child: Text(
                "Overseer Menu",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Logout"),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  // Returns the content based on the selected tab index
  Widget _buildBodyContent(bool isLargeScreen) {
    final children = _buildTabChildren(isLargeScreen);
    return children[_selectedIndex];
  }

  // Returns the list of widgets for tabs (reused by both layouts)
  List<Widget> _buildTabChildren(bool isLargeScreen) {
    return [
      // 1. Dashboard
      SingleChildScrollView(child: _buildDashboardContent(isLargeScreen)),
      // 2. Add Member
      SingleChildScrollView(child: _buildAddMemberContent(isLargeScreen)),
      // 3. All Members (Responsive: List on Mobile, Table on Desktop)
      _buildAllMembersContent(isLargeScreen),
      // 4. Add Officer
      SingleChildScrollView(child: _buildAddOfficerContent(isLargeScreen)),
      // 5. Reports
      SingleChildScrollView(child: _buildReportsContent(isLargeScreen)),
    ];
  }

  // ---------------------------------------------------
  // TAB 1: DASHBOARD CONTENT
  // ---------------------------------------------------
  Widget _buildDashboardContent(bool isLargeScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Overview",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[800],
          ),
        ),
        SizedBox(height: 20),

        // Stat Cards
        LayoutBuilder(
          builder: (ctx, constraints) {
            int crossAxisCount = isLargeScreen
                ? 3
                : (constraints.maxWidth > 600 ? 2 : 1);
            final color = Theme.of(context);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard(
                  "Total Members",
                  Icons.group,
                  Colors.blue,
                  color.primaryColorLight,
                  _getTotalOverseerMemberCount,
                  width:
                      (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                      crossAxisCount,
                ),
                _buildStatCard(
                  "Total Districts",
                  Icons.map,
                  Colors.orange,
                  color.splashColor,
                  _getTotalOverseerDistrictCount,
                  width:
                      (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                      crossAxisCount,
                ),
                _buildStatCard(
                  "Total Branches",
                  Icons.location_city,
                  Colors.red,
                  color.primaryColorDark,
                  _getTotalOverseerBranchCount,
                  width:
                      (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                      crossAxisCount,
                ),
              ],
            );
          },
        ),

        SizedBox(height: 30),

        // Charts
        isLargeScreen
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTitheBarChart(context)),
                  SizedBox(width: 20),
                  Expanded(child: _buildMemberPieChart(context)),
                ],
              )
            : Column(
                children: [
                  _buildTitheBarChart(context),
                  SizedBox(height: 20),
                  _buildMemberPieChart(context),
                ],
              ),
        SizedBox(height: 20),
        _buildWeeklyTitheLineChart(context),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    IconData icon,
    Color color,
    Color cardColor,
    Future<int> Function() future, {
    double? width,
  }) {
    return Container(
      width: width,
      constraints: BoxConstraints(minWidth: 250),
      child: FutureBuilder<int>(
        future: future(),
        builder: (context, snapshot) {
          return Card(
            color: cardColor,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      snapshot.connectionState == ConnectionState.waiting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              "${snapshot.data ?? 0}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------
  // TAB 2: ADD MEMBER CONTENT
  // ---------------------------------------------------
  Widget _buildAddMemberContent(bool isLargeScreen) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 600),
        padding: EdgeInsets.all(20),
        decoration: isLargeScreen
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Register New Member",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _platformTextField(
              controller: memberNameController,
              placeholder: "First Name",
            ),
            _platformTextField(
              controller: memberSurnameController,
              placeholder: "Surname",
            ),
            _platformTextField(
              controller: memberEmailController,
              placeholder: "Email (Optional)",
              keyboardType: TextInputType.emailAddress,
            ),
            _platformTextField(
              controller: memberAddressController,
              placeholder: "Address",
            ),
            _platformTextField(
              controller: memberContactController,
              placeholder: "Phone Number",
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 10),
            // Dropdowns for Organization
            _buildOrgDropdowns(),
            SizedBox(height: 20),
            CustomOutlinedButton(
              onPressed: _registerMember,
              text: "Save Member",
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgDropdowns() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CupertinoActivityIndicator();

        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        selectedProvince = data['province'];
        List districts = data['districts'] ?? [];

        List<String> elders = districts
            .map((e) => e['districtElderName'].toString())
            .toList();

        // Logic to get communities based on selected elder
        List<String> communities = [];
        if (selectedDistrictElder != null) {
          var dist = districts.firstWhere(
            (e) => e['districtElderName'] == selectedDistrictElder,
            orElse: () => null,
          );
          if (dist != null) {
            communities = (dist['communities'] as List)
                .map((c) => c['communityName'].toString())
                .toList();
          }
        }

        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedDistrictElder,
              hint: Text("Select District Elder"),
              items: elders
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() {
                selectedDistrictElder = val;
                selectedCommunityName = null;
              }),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedCommunityName,
              hint: Text("Select Community"),
              items: communities
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() {
                selectedCommunityName = val;
              }),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _registerMember() async {
    if (memberNameController.text.isEmpty ||
        memberSurnameController.text.isEmpty ||
        selectedDistrictElder == null) {
      Api().showMessage(
        context,
        "Please fill required fields",
        "Error",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'name': memberNameController.text,
        'surname': memberSurnameController.text,
        'email': memberEmailController.text,
        'address': memberAddressController.text,
        'phone': memberContactController.text,
        'overseerUid': FirebaseAuth.instance.currentUser?.uid,
        'role': 'Member',
        'province': selectedProvince,
        'districtElderName': selectedDistrictElder,
        'communityName': selectedCommunityName,
        'week1': 0.0,
        'week2': 0.0,
        'week3': 0.0,
        'week4': 0.0,
      });
      Navigator.pop(context);
      Api().showMessage(context, "Member added", "Success", Colors.green);
      _clearMemberInputs();
      _loadDashboardData();
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  void _clearMemberInputs() {
    memberNameController.clear();
    memberSurnameController.clear();
    memberEmailController.clear();
    memberAddressController.clear();
    memberContactController.clear();
    setState(() {
      selectedDistrictElder = null;
      selectedCommunityName = null;
    });
  }

  // ---------------------------------------------------
  // TAB 3: ALL MEMBERS CONTENT (With Filtering)
  // ---------------------------------------------------
  // ---------------------------------------------------
  // TAB 3: ALL MEMBERS CONTENT (With Filtering & Pagination)
  // ---------------------------------------------------
  Widget _buildAllMembersContent(bool isLargeScreen) {
    return Column(
      children: [
        // --- SEARCH & FILTER SECTION ---
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              // 1. Search Bar
              Container(
                constraints: BoxConstraints(maxWidth: 800),
                child: _platformTextField(
                  controller: _searchController,
                  placeholder: "Search by Name, Surname or Email",
                  prefixIcon: Icons.search,
                ),
              ),
              SizedBox(height: 12),
              // 2. Filter Dropdowns
              _buildFilterSection(),
            ],
          ),
        ),

        // --- DATA LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(
                  'overseerUid',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return Center(child: Text("No members found"));

              final query = _searchController.text.toLowerCase();

              // --- 1. FILTERING LOGIC ---
              final allFilteredMembers = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final matchesSearch =
                    (data['name'] ?? '').toString().toLowerCase().contains(
                      query,
                    ) ||
                    (data['surname'] ?? '').toString().toLowerCase().contains(
                      query,
                    ) ||
                    (data['email'] ?? '').toString().toLowerCase().contains(
                      query,
                    );

                final matchesDistrict =
                    _filterDistrict == null ||
                    (data['districtElderName'] ?? '') == _filterDistrict;

                final matchesCommunity =
                    _filterCommunity == null ||
                    (data['communityName'] ?? '') == _filterCommunity;

                return matchesSearch && matchesDistrict && matchesCommunity;
              }).toList();

              if (allFilteredMembers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("No members match current filters"),
                      TextButton(
                        onPressed: () => setState(() {
                          _filterDistrict = null;
                          _filterCommunity = null;
                          _searchController.clear();
                          _currentPage = 0; // Reset page
                        }),
                        child: Text("Clear Filters"),
                      ),
                    ],
                  ),
                );
              }

              // --- 2. PAGINATION LOGIC ---
              int totalItems = allFilteredMembers.length;
              int totalPages = (totalItems / _rowsPerPage).ceil();

              // Safety check: if filters reduce count significantly, reset current page
              if (_currentPage >= totalPages) {
                _currentPage = (totalPages > 0) ? totalPages - 1 : 0;
              }

              int startIndex = _currentPage * _rowsPerPage;
              int endIndex = startIndex + _rowsPerPage;
              if (endIndex > totalItems) endIndex = totalItems;

              // Slice the list
              final paginatedMembers = allFilteredMembers.sublist(
                startIndex,
                endIndex,
              );

              return Column(
                children: [
                  // --- THE LIST/TABLE ---
                  Expanded(
                    child: isLargeScreen
                        ? SingleChildScrollView(
                            padding: EdgeInsets.all(20),
                            child: Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(
                                    Colors.grey[200],
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        "Name",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Surname",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "District",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Contact",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Week 1",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Week 2",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Week 3",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Week 4",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Actions",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: paginatedMembers.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(data['name'] ?? '')),
                                        DataCell(Text(data['surname'] ?? '')),
                                        DataCell(
                                          Text(
                                            "${data['districtElderName'] ?? ''}",
                                          ),
                                        ),
                                        DataCell(Text(data['phone'] ?? '')),
                                        DataCell(
                                          Text("R${data['week1'] ?? 0}"),
                                        ),
                                        DataCell(
                                          Text("R${data['week2'] ?? 0}"),
                                        ),
                                        DataCell(
                                          Text("R${data['week3'] ?? 0}"),
                                        ),
                                        DataCell(
                                          Text("R${data['week4'] ?? 0}"),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  color: Colors.blue,
                                                ),
                                                onPressed: () =>
                                                    _showEditTitheDialog(doc),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _deleteMember(doc),
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
                          )
                        : ListView.builder(
                            itemCount: paginatedMembers.length,
                            itemBuilder: (context, index) {
                              final doc = paginatedMembers[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      (data['name'] ?? 'U').substring(0, 1),
                                    ),
                                  ),
                                  title: Text(
                                    "${data['name']} ${data['surname']}",
                                  ),
                                  subtitle: Text(
                                    "${data['districtElderName']} | ${data['communityName']}",
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () =>
                                            _showEditTitheDialog(doc),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _deleteMember(doc),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // --- PAGINATION CONTROLS ---
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "Showing ${startIndex + 1}-${endIndex} of $totalItems",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 20),
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          icon: Icon(Icons.chevron_left),
                          tooltip: "Previous Page",
                        ),
                        Text(
                          "Page ${_currentPage + 1} of $totalPages",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          icon: Icon(Icons.chevron_right),
                          tooltip: "Next Page",
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- HELPER FOR DROPDOWNS (With Page Reset) ---
  Widget _buildFilterSection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();

        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        List districts = data['districts'] ?? [];
        List<String> elderNames = districts
            .map((e) => e['districtElderName'].toString())
            .toList();

        List<String> communityNames = [];
        if (_filterDistrict != null) {
          var dist = districts.firstWhere(
            (e) => e['districtElderName'] == _filterDistrict,
            orElse: () => null,
          );
          if (dist != null) {
            communityNames = (dist['communities'] as List)
                .map((c) => c['communityName'].toString())
                .toList();
          }
        }

        return Container(
          constraints: BoxConstraints(maxWidth: 800),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterDistrict,
                  decoration: InputDecoration(
                    labelText: "Filter by District",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    isDense: true,
                  ),
                  items: elderNames
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _filterDistrict = val;
                      _filterCommunity = null;
                      _currentPage = 0; // RESET PAGE
                    });
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterCommunity,
                  decoration: InputDecoration(
                    labelText: "Filter by Community",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    isDense: true,
                  ),
                  items: communityNames
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _filterCommunity = val;
                      _currentPage = 0; // RESET PAGE
                    });
                  },
                ),
              ),
              SizedBox(width: 10),
              IconButton(
                icon: Icon(Icons.clear, color: Colors.red),
                tooltip: "Clear Filters",
                onPressed: () {
                  setState(() {
                    _filterDistrict = null;
                    _filterCommunity = null;
                    _searchController.clear();
                    _currentPage = 0; // RESET PAGE
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HELPER FOR DROPDOWNS ---
  void _showEditTitheDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    week1Controller.text = data['week1']?.toString() ?? '0';
    week2Controller.text = data['week2']?.toString() ?? '0';
    week3Controller.text = data['week3']?.toString() ?? '0';
    week4Controller.text = data['week4']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Offering for ${data['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _platformTextField(
              controller: week1Controller,
              placeholder: "Week 1",
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            _platformTextField(
              controller: week2Controller,
              placeholder: "Week 2",
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            _platformTextField(
              controller: week3Controller,
              placeholder: "Week 3",
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            _platformTextField(
              controller: week4Controller,
              placeholder: "Week 4",
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Api().showLoading(context);
              await doc.reference.update({
                'week1': double.tryParse(week1Controller.text) ?? 0,
                'week2': double.tryParse(week2Controller.text) ?? 0,
                'week3': double.tryParse(week3Controller.text) ?? 0,
                'week4': double.tryParse(week4Controller.text) ?? 0,
              });
              Navigator.pop(context); // Loading
              Navigator.pop(ctx); // Dialog
              _loadDashboardData();
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteMember(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Confirm Delete"),
        content: Text("Are you sure you want to delete this member?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              _loadDashboardData();
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // TAB 4: ADD OFFICER CONTENT
  // ---------------------------------------------------
  Widget _buildAddOfficerContent(bool isLargeScreen) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(24),
        decoration: isLargeScreen
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              )
            : null,
        child: Column(
          children: [
            Text(
              "Add District Officer",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _platformTextField(
              controller: officerNameController,
              placeholder: "District Elder Name",
            ),
            _platformTextField(
              controller: communityOfficerController,
              placeholder: "Community Name",
            ),
            SizedBox(height: 20),
            CustomOutlinedButton(
              onPressed: () async {
                if (officerNameController.text.isEmpty ||
                    communityOfficerController.text.isEmpty)
                  return;
                Api().showLoading(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('overseers')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .update({
                        'districts': FieldValue.arrayUnion([
                          {
                            'districtElderName': officerNameController.text,
                            'communities': [
                              {
                                'communityName':
                                    communityOfficerController.text,
                              },
                            ],
                          },
                        ]),
                      });
                  Navigator.pop(context);
                  Api().showMessage(
                    context,
                    "Officer Added",
                    "Success",
                    Colors.green,
                  );
                  officerNameController.clear();
                  communityOfficerController.clear();
                } catch (e) {
                  Navigator.pop(context);
                  Api().showMessage(context, "Error: $e", "Error", Colors.red);
                }
              },
              text: "Save Officer",
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // TAB 5: REPORTS CONTENT
  // ---------------------------------------------------
  Widget _buildReportsContent(bool isLargeScreen) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 600),
        padding: EdgeInsets.all(24),
        decoration: isLargeScreen
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Generate Monthly Report",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            _buildOrgDropdowns(), // Reusing the dropdowns from Add Member
            SizedBox(height: 30),
            CustomOutlinedButton(
              onPressed: () async {
                if (selectedDistrictElder == null ||
                    selectedCommunityName == null) {
                  Api().showMessage(
                    context,
                    "Select district & community",
                    "Error",
                    Colors.red,
                  );
                  return;
                }

                // Check Subscription Gate
                Api().showLoading(context);
                int members = await _getTotalOverseerMemberCount();
                await _checkSubscriptionStatusFromFirestore();
                Navigator.pop(context);

                String? plan = PaystackService.getRequiredPlan(members);
                if (plan != null && !_isSubscriptionActive) {
                  _showSubscriptionLockedScreen(context, plan, members);
                  return;
                }

                // Generate PDF
                // Note: Passing dummy data for fields not fetched in this simplified version
                await _generatePdfAndDownload(
                  selectedDistrictElder!,
                  selectedCommunityName!,
                  selectedProvince,
                  "Overseer", // Fetch actual name in prod
                  {},
                  99999, // Passing a high number to fetch all
                  "CODE",
                  "Region",
                );
              },
              text: "Download Report (PDF)",
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // PDF & UTILS
  // ---------------------------------------------------

  // Your existing PDF generation logic, kept intact but condensed for brevity.
  // Ensure to include the helper methods _buildPdfBalanceSheetTable, etc.

  Future<void> _generatePdfAndDownload(
    String selectedDistrictElder,
    String selectedCommunityName,
    String selectedProvince,
    String overseerInitialsAndSurname,
    Map<String, dynamic> overseerData,
    int memberLimit,
    String code,
    String region,
  ) async {
    Api().showLoading(context);
    final _cloisterFont = pw.Font.ttf(
      await rootBundle.load(
        'assets/CloisterBlack.ttf',
      ), // Make sure this path is correct in pubspec.yaml
    );
    try {
      final balanceSheetTable = await _buildPdfBalanceSheetTable(
        context,
        selectedDistrictElder,
        selectedCommunityName,
        memberLimit,
      );

      if (balanceSheetTable == null) {
        Navigator.pop(context);
        return;
      }

      final pdf = pw.Document();
      final month = DateTime.now().month;
      String monthName;
      switch (month) {
        case 1:
          monthName = 'January';
          break;
        case 2:
          monthName = 'February';
          break;
        case 3:
          monthName = 'March';
          break;

        case 4:
          monthName = 'April';
          break;
        case 5:
          monthName = 'May';
          break;
        case 6:
          monthName = 'June';
          break;
        case 7:
          monthName = 'July';
          break;
        case 8:
          monthName = 'August';
          break;
        case 9:
          monthName = 'September';
          break;
        case 10:
          monthName = 'October';
          break;
        case 11:
          monthName = 'November';
          break;
        case 12:
          monthName = 'December';
          break;
        default:
          monthName = 'Unknown';
          break;
      }
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              if (_logoBytes != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(
                      pw.MemoryImage(_logoBytes!),
                      width: 100,
                      height: 100,
                    ),
                    pw.Column(
                      children: [
                        pw.Center(
                          child: pw.Text(
                            'The Twelve Apostles Church in Trinity',
                            style: pw.TextStyle(
                              fontSize: 25,
                              fontWeight: pw.FontWeight.bold,
                              font: _cloisterFont,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Center(
                          child: pw.Text('P. O. Box 40376, Red Hill, 4071'),
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Center(
                              child: pw.Text(
                                'Tel./Fax No\'s:',
                                style: pw.TextStyle(font: _cloisterFont),
                              ),
                            ),
                            pw.Center(child: pw.Text('(031) 569 6164')),
                          ],
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Center(
                              child: pw.Text(
                                'Email:',
                                style: pw.TextStyle(font: _cloisterFont),
                              ),
                            ),
                            pw.Center(child: pw.Text('thetacc@telkomsa.net')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              pw.SizedBox(height: 30),
              pw.Table(
                columnWidths: {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(3),
                  3: pw.FlexColumnWidth(1),
                },
                children: [],
              ),
              pw.Text(
                'Income and Expenditure Statement',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              _buildPdfTextRow(
                'For the Month:',
                '$monthName',
                'Year:',
                '${DateTime.now().year}',
              ),
              _buildPdfTextRow(
                'Overseer:',
                '$overseerInitialsAndSurname',
                'Code No:',
                '$code',
              ),
              _buildPdfTextRow('District Elder:', '$selectedDistrictElder'),
              _buildPdfTextRow('Community Elder:', '_____________'),
              _buildPdfTextRow('Community Name:', '$selectedCommunityName'),
              _buildPdfTextRow(
                'Province: ${overseerData['province']}',
                '',
                'Region:',
                '$region',
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text(
                'Income / Receipts',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Tithe Offerings - Week 1', 'R', 'c'),
              _buildPdfReportRow('Tithe Offerings - Week 2', 'R', 'c'),
              _buildPdfReportRow('Tithe Offerings - Week 3', 'R', 'c'),
              _buildPdfReportRow('Tithe Offerings - Week 4', 'R', 'c'),
              _buildPdfReportRow('Others', 'R', 'c'),
              _buildPdfReportRow('Month End', 'R', 'c'),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Total Income', 'R', 'c', isTotal: true),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text(
                'Expenditure',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Rent Period', 'R', 'c'),
              _buildPdfReportRow('Wine and Priest Wafers', 'R', 'c'),
              _buildPdfReportRow('Power and Lights', 'R', 'c'),
              _buildPdfReportRow('Sundries/Repairs', 'R', 'c'),
              _buildPdfReportRow('Central Council', 'R', 'c'),
              _buildPdfReportRow('Equipment / General', 'R', 'c'),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Total Expenditure', 'R', 'c', isTotal: true),
              pw.SizedBox(height: 20),
              pw.Divider(),
              _buildPdfReportRow(
                'Credit Balance (Amount Banked)',
                'R',
                'c',
                isTotal: true,
                isCreditBalance: true,
              ),
              pw.SizedBox(height: 20),
              pw.Text('Bank Name: Standard Bank'),
              pw.Text('Account Name: The TACT'),
              pw.Text('Account No: 051074958'),
              pw.Text('Branch Name: Kingsmead'),
              pw.Text('Branch Code: 040026'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Please write your name and the name of your Community in the Deposit Slip Senders Details Column.',
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Balance Sheet',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfTextRow(
                'For the Month of:',
                '${DateTime.now().month}',
                'Year:',
                '${DateTime.now().year}',
              ),
              _buildPdfTextRow('Overseer:', '$overseerInitialsAndSurname'),
              _buildPdfTextRow('District Elder:', '$selectedDistrictElder'),
              _buildPdfTextRow('Community Elder:', '________________'),
              _buildPdfTextRow('Community Name:', '$selectedCommunityName'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Members Tithe Offerings',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              balanceSheetTable,
              pw.SizedBox(height: 10),
              pw.SizedBox(height: 30),
              pw.Text(
                'NB: Attach all receipts and Bank Deposit Slips with Neat and Clear Details',
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Signatures:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfSignatureRow('Overseer', overseerInitialsAndSurname),
              _buildPdfSignatureRow('Community Elder', '_____________'),
              _buildPdfSignatureRow('Secretary', '_____________'),
              _buildPdfSignatureRow('District Elder', selectedDistrictElder),
              _buildPdfSignatureRow('Treasurer', '_____________'),
              _buildPdfSignatureRow('Contact Person', '_____________'),
              pw.SizedBox(height: 20),
              pw.Text('Telephone No: __________'),
              pw.Text('Email Address: __________'),
            ];
          },
        ),
      );

      // --- PLATFORM AWARE SAVE/SHARE LOGIC (FIX FOR WEB ERROR) ---
      final pdfData = await pdf.save();
      final filename =
          '$overseerInitialsAndSurname\'s balance sheet (${DateTime.now().toIso8601String()}).pdf';

      if (kIsWeb) {
        // Web/Desktop: Use Printing.sharePdf (or print/download layout) directly
        await Printing.sharePdf(bytes: pdfData, filename: filename);
      } else {
        // Mobile/Desktop (non-web): Use path_provider and dart:io
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/$filename',
        ); // Correct File constructor usage
        await file.writeAsBytes(pdfData);

        await Printing.sharePdf(
          bytes: await file.readAsBytes(),
          filename: filename,
        );
      }
      // -----------------------------------------------------------

      Navigator.pop(context);
      Api().showMessage(
        context,
        'Report generated and ready to share!',
        'Success',
        Theme.of(context).splashColor,
      );
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Failed to generate PDF: $e',
        'Error',
        Theme.of(context).primaryColorDark,
      );
      print('PDF Generation Error: $e');
    }
  }

  Future<pw.Widget?> _buildPdfBalanceSheetTable(
    BuildContext context,
    String selectedDistrictElder,
    String selectedCommunityName,
    int memberLimit,
  ) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    Query<Map<String, dynamic>> query = firestore
        .collection('users')
        .where('districtElderName', isEqualTo: selectedDistrictElder)
        .where('communityName', isEqualTo: selectedCommunityName)
        .where(
          'overseerUid',
          isEqualTo: FirebaseAuth.instance.currentUser?.uid,
        );

    // FIX: Only apply limit if it is within valid Firestore bounds (<= 10000).
    // If memberLimit is higher (e.g. 99999), we skip the limit call to fetch all.
    if (memberLimit > 0 && memberLimit <= 10000) {
      query = query.limit(memberLimit);
    }

    var memberLatestData = await query.get();

    if (memberLatestData.docs.isEmpty) {
      Api().showMessage(
        context,
        'No members found for the selected community, however, a report has still been generated.',
        'Error',
        Theme.of(context).primaryColorDark,
      );
    }

    List<Map<String, dynamic>> allMembersData = [];
    for (var d in memberLatestData.docs) {
      allMembersData.add(d.data());
    }

    List<List<String>> tableData = [
      <String>[
        'Members Name and Surname',
        'WEEK 1',
        'WEEK 2',
        'WEEK 3',
        'WEEK 4',
        'MONTHLY',
      ],
    ];

    double grandTotal = 0.00;

    for (var memberData in allMembersData) {
      String memberName = memberData['name'] ?? 'N/A';
      String memberSurname = memberData['surname'] ?? 'N/A';
      // Safely convert num/string to string
      String memberWeek1 =
          (memberData['week1'] as num?)?.toStringAsFixed(2) ?? '0.00';
      String memberWeek2 =
          (memberData['week2'] as num?)?.toStringAsFixed(2) ?? '0.00';
      String memberWeek3 =
          (memberData['week3'] as num?)?.toStringAsFixed(2) ?? '0.00';
      String memberWeek4 =
          (memberData['week4'] as num?)?.toStringAsFixed(2) ?? '0.00';

      var total =
          (double.parse(memberWeek1) +
                  double.parse(memberWeek2) +
                  double.parse(memberWeek3) +
                  double.parse(memberWeek4))
              .toStringAsFixed(2);

      tableData.add(<String>[
        '${memberName} ${memberSurname}',
        'R${memberWeek1}',
        'R${memberWeek2}',
        'R${memberWeek3}',
        'R${memberWeek4}',
        'R${total}',
      ]);

      grandTotal += double.parse(total);
    }

    return pw.Column(
      children: [
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
          ),
          cellPadding: const pw.EdgeInsets.all(2),
          data: tableData,
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'GRAND TOTAL: R ${grandTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfTextRow(
    String label1,
    String value1, [
    String? label2,
    String? value2,
  ]) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$label1 $value1'),
        if (label2 != null && value2 != null) pw.Text('$label2 $value2'),
      ],
    );
  }

  pw.Widget _buildPdfReportRow(
    String label,
    String rText,
    String cText, {
    bool isTotal = false,
    bool isCreditBalance = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: isTotal || isCreditBalance
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$rText _______',
                style: pw.TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$cText _______',
                style: pw.TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSignatureRow(String role, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 2, child: pw.Text('$role:')),
          pw.Expanded(flex: 3, child: pw.Text('$value')),
          pw.SizedBox(width: 10),
          pw.Expanded(flex: 1, child: pw.Text('Signature:')),
          pw.Expanded(flex: 3, child: pw.Text('___________________')),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  // --- CHARTS HELPERS (Reused from previous) ---
  Widget _buildTitheBarChart(BuildContext context) {
    final color = Theme.of(context);
    final isWeb = kIsWeb;

    // Get list of district names in the order they appear in the data
    final districtNames = _districtTotals.keys.toList();

    if (_monthlyOfferingsData.isEmpty) {
      return _buildChartPlaceholder(context, 'Tithe Offerings by District');
    }

    return Card(
      elevation: 4,
      color: color.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: isWeb ? 350 : 300,
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.primaryColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Monthly Tithe Offerings by District Elder (R)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _maxOfferingAmount,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String districtName = districtNames[group.x.toInt()];
                          return BarTooltipItem(
                            '$districtName\n',
                            TextStyle(
                              color: color.scaffoldBackgroundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: 'R${rod.toY.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: color.scaffoldBackgroundColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30, // Increased size for initials
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < districtNames.length) {
                              // Display initials
                              String name = districtNames[index];
                              return SideTitleWidget(
                                meta: meta,
                                space: 4.0,
                                child: Text(
                                  name
                                      .split(' ')
                                      .map(
                                        (e) => e.isNotEmpty
                                            ? e.substring(0, 1)
                                            : '',
                                      )
                                      .join(), // Initials
                                  style: TextStyle(
                                    color: color.primaryColorDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _maxOfferingAmount / 5,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'R${value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: color.hintColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    barGroups: _monthlyOfferingsData,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: color.hintColor.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (districtNames.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'District Elder Initials: ${districtNames.asMap().entries.map((e) => '${e.value.split(' ').map((s) => s.isNotEmpty ? s.substring(0, 1) : '').join()}=${e.value}').join(', ')}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: color.hintColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberPieChart(BuildContext context) {
    final color = Theme.of(context);
    final isWeb = kIsWeb;

    if (_districtMemberCounts.isEmpty) {
      return _buildChartPlaceholder(context, 'Member Distribution by District');
    }

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;
    _districtMemberCounts.forEach((district, count) {
      final isTouched = false; // You can add touch logic here later if needed
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 110.0 : 100.0;
      final double percentage = _totalMemberCountForChart > 0
          ? (count / _totalMemberCountForChart) * 100
          : 0;

      sections.add(
        PieChartSectionData(
          color: _pieColors[colorIndex % _pieColors.length],
          value: count.toDouble(),
          title: '${percentage.toStringAsFixed(1)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color.scaffoldBackgroundColor,
            shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
          ),
        ),
      );
      colorIndex++;
    });
    return Card(
      elevation: 4,
      color: color.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: isWeb ? 350 : 300,
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.primaryColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member Distribution by District',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                // Add touch logic if needed
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 1,
                        centerSpaceRadius: 20,
                        sections: sections,
                      ),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    flex: 1,
                    child: ListView(
                      children: _districtMemberCounts.keys
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                            int index = entry.key;
                            String district = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    color:
                                        _pieColors[index % _pieColors.length],
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$district (${_districtMemberCounts[district]})',
                                      style: TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTitheLineChart(BuildContext context) {
    final color = Theme.of(context);
    final isWeb = kIsWeb;

    if (_weeklyTotals.values.every((v) => v == 0.0)) {
      return _buildChartPlaceholder(context, 'Weekly Tithe Trend');
    }

    final List<FlSpot> spots = [
      FlSpot(1, _weeklyTotals[1] ?? 0.0),
      FlSpot(2, _weeklyTotals[2] ?? 0.0),
      FlSpot(3, _weeklyTotals[3] ?? 0.0),
      FlSpot(4, _weeklyTotals[4] ?? 0.0),
    ];

    return Card(
      elevation: 4,
      color: color.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: isWeb ? 350 : 300,
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.primaryColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Weekly Tithe Trend (All Districts)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 18.0, top: 10.0),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: _maxWeeklyTithe / 4,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: color.hintColor.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: color.hintColor.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            String text = '';
                            switch (value.toInt()) {
                              case 1:
                                text = 'Week 1';
                                break;
                              case 2:
                                text = 'Week 2';
                                break;
                              case 3:
                                text = 'Week 3';
                                break;
                              case 4:
                                text = 'Week 4';
                                break;
                              default:
                                return const SizedBox();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 8.0,
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: _maxWeeklyTithe / 4,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'R${value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.left,
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: color.hintColor.withOpacity(0.3),
                      ),
                    ),
                    minX: 1,
                    maxX: 4,
                    minY: 0,
                    maxY: _maxWeeklyTithe,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [color.primaryColor, color.splashColor],
                        ),
                        barWidth: 5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              color.primaryColor.withOpacity(0.3),
                              color.splashColor.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder(BuildContext context, String title) {
    final color = Theme.of(context);
    final isWeb = kIsWeb;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: isWeb ? 350 : 250,
        width: double.infinity,
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.primaryColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: Center(
                child: Container(
                  color: color.primaryColor.withOpacity(0.1),
                  child: Center(
                    child: Text(
                      'Loading Data Visualization or No Data Available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color.hintColor),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    memberNameController.dispose();
    memberSurnameController.dispose();
    memberEmailController.dispose();
    memberAddressController.dispose();
    memberContactController.dispose();
    week1Controller.dispose();
    week2Controller.dispose();
    week3Controller.dispose();
    week4Controller.dispose();
    super.dispose();
  }
}
